import Foundation
import BmuxAgentChat
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import XCTest

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

final class SessionProvenanceTests: XCTestCase {
    @MainActor
    func testLiveRuntimeUsesCanonicalEngineOwnedDefaultStore() throws {
        let homeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-provenance-runtime-home-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: homeDirectory) }
        let location = WorkProvenanceStorageLocation(homeDirectory: homeDirectory)

        let runtime = WorkProvenanceRuntime.live(homeDirectory: homeDirectory)

        XCTAssertTrue(runtime.isEnabled)
        XCTAssertNil(runtime.startupErrorDescription)
        XCTAssertEqual(runtime.effectiveDatabaseURL, location.databaseURL)
        XCTAssertEqual(
            location.databaseURL.path,
            homeDirectory
                .appendingPathComponent(".local", isDirectory: true)
                .appendingPathComponent("state", isDirectory: true)
                .appendingPathComponent("provenance-engine", isDirectory: true)
                .appendingPathComponent("provenance.sqlite", isDirectory: false)
                .path
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: location.databaseURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: location.legacyDatabaseURL.path))
    }

    func testSessionLifecycleRecorderUsesPublicEngineLifecycleAPI() async throws {
        let client = CapturingProvenanceEngineClient()
        let recorder = WorkProvenanceSessionLifecycleRecorder(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [
                "/repo/subdir": WorkProvenanceGitSnapshot(
                    repositoryRoot: "/repo",
                    commonDirectory: "/repo/.git",
                    remoteSlug: "example/repo",
                    branch: "main",
                    headCommit: "abc123",
                    isDirty: false,
                    statusEntries: []
                )
            ])
        )
        let timestamp = Date(timeIntervalSince1970: 1_725_000_000)

        await recorder.record(
            AgentSessionLifecycleChange(
                phase: .started,
                parentSessionID: "parent-session",
                agentKind: .codex,
                workspaceID: "workspace-1",
                surfaceID: "surface-1",
                workingDirectory: "/repo/subdir",
                externalSessionID: "external-session-1",
                displayName: "Build agent"
            ),
            timestamp: timestamp
        )

        let request = await client.recordedLifecycleRequests.first
        XCTAssertEqual(request?.phase, .started)
        XCTAssertEqual(request?.sessionID, nil)
        XCTAssertEqual(request?.parentSessionID, "parent-session")
        XCTAssertEqual(request?.agentKind, "codex")
        XCTAssertEqual(request?.workspaceID, "workspace-1")
        XCTAssertEqual(request?.surfaceID, "surface-1")
        XCTAssertEqual(request?.worktreeID, WorkProvenanceStableIDFactory().worktreeID(repositoryRoot: "/repo"))
        XCTAssertEqual(request?.workingDirectory, "/repo/subdir")
        XCTAssertEqual(request?.externalIdentityKind, "subagent")
        XCTAssertEqual(request?.externalIdentityValue, "external-session-1")
        XCTAssertEqual(request?.displayName, "Build agent")
        XCTAssertEqual(request?.timestamp, timestamp)

        await recorder.recordExecutionTelemetrySessionStarted(
            sessionID: "session-sidecar",
            provider: "codex",
            providerSessionID: "thread-sidecar",
            workingDirectory: "/repo/subdir",
            timestamp: timestamp.addingTimeInterval(1)
        )

        let sidecarRequest = await client.recordedLifecycleRequests.dropFirst().first
        XCTAssertEqual(sidecarRequest?.phase, .started)
        XCTAssertEqual(sidecarRequest?.sessionID, "session-sidecar")
        XCTAssertEqual(sidecarRequest?.parentSessionID, nil)
        XCTAssertEqual(sidecarRequest?.agentKind, "codex")
        XCTAssertEqual(sidecarRequest?.workspaceID, nil)
        XCTAssertEqual(sidecarRequest?.surfaceID, nil)
        XCTAssertEqual(sidecarRequest?.worktreeID, WorkProvenanceStableIDFactory().worktreeID(repositoryRoot: "/repo"))
        XCTAssertEqual(sidecarRequest?.workingDirectory, nil)
        XCTAssertEqual(sidecarRequest?.externalIdentityKind, "provider_session")
        XCTAssertEqual(sidecarRequest?.externalIdentityValue, "thread-sidecar")
        XCTAssertEqual(sidecarRequest?.displayName, nil)
        XCTAssertEqual(sidecarRequest?.timestamp, timestamp.addingTimeInterval(1))
        let lastErrorDescription = await recorder.lastErrorDescription
        XCTAssertNil(lastErrorDescription)
    }

    func testSessionLifecycleRecorderRetainsBoundedEngineError() async throws {
        let client = CapturingProvenanceEngineClient(
            lifecycleResponse: ProvenanceEngineContracts.ProvenanceSessionLifecycleResponse(
                accepted: false,
                eventID: nil,
                sessionID: nil,
                relationshipSessionID: nil,
                externalIdentityID: nil,
                errorDescription: "database unavailable"
            )
        )
        let recorder = WorkProvenanceSessionLifecycleRecorder(client: client)

        await recorder.record(
            AgentSessionLifecycleChange(
                phase: .stopped,
                parentSessionID: "parent-session",
                agentKind: .claude,
                workspaceID: nil,
                surfaceID: nil,
                workingDirectory: nil,
                externalSessionID: nil,
                displayName: nil
            ),
            timestamp: Date(timeIntervalSince1970: 1_725_000_001)
        )

        let lastErrorDescription = await recorder.lastErrorDescription
        XCTAssertEqual(lastErrorDescription, "database unavailable")
    }

    @MainActor
    func testExecutionTelemetryProjectionReportsUnavailableSidecar() async throws {
        let agentChatURL = URL(string: "http://127.0.0.1:7739")!
        let sessionListClient = AgentChatSessionListClient(
            baseURL: agentChatURL,
            loader: FixtureAgentChatHTTPLoader(result: .failure(URLError(.cannotConnectToHost)))
        )
        let lifecycleRecorder = WorkProvenanceSessionLifecycleRecorder(
            client: CapturingProvenanceEngineClient()
        )
        var statuses: [ExecutionTelemetryProjectionSidecarStatus] = []
        let service = ExecutionTelemetryProvenanceProjectionService(
            agentChatURL: agentChatURL,
            lifecycleRecorder: lifecycleRecorder,
            sessionListClient: sessionListClient,
            sidecarStatusHandler: { statuses.append($0) }
        )

        await service.projectKnownSessions()

        XCTAssertEqual(statuses.count, 1)
        guard case .unavailable(let reportedURL, let errorDescription) = statuses[0] else {
            return XCTFail("Expected unavailable status")
        }
        XCTAssertEqual(reportedURL, agentChatURL)
        XCTAssertTrue(errorDescription.contains("cannot connect") || errorDescription.contains("URLError"))
    }

    @MainActor
    func testExecutionTelemetryProjectionReportsAvailableSidecarAfterSessionListSucceeds() async throws {
        let agentChatURL = URL(string: "http://127.0.0.1:7739")!
        let sessionsData = Data("""
        [
          {
            "id": "session-sidecar",
            "provider": "codex",
            "cwd": "/repo",
            "status": "idle",
            "createdAt": 1725000000000
          }
        ]
        """.utf8)
        let liveProjectionData = Data("""
        {
          "sessionId": "session-sidecar",
          "snapshot": null
        }
        """.utf8)
        let sessionListClient = AgentChatSessionListClient(
            baseURL: agentChatURL,
            loader: FixtureAgentChatHTTPLoader(
                result: .success(AgentChatHTTPResponse(data: sessionsData, statusCode: 200))
            )
        )
        let liveProjectionClient = ExecutionTelemetryLiveProjectionClient(
            baseURL: agentChatURL,
            loader: FixtureAgentChatHTTPLoader(
                result: .success(AgentChatHTTPResponse(data: liveProjectionData, statusCode: 200))
            )
        )
        let lifecycleRecorder = WorkProvenanceSessionLifecycleRecorder(
            client: CapturingProvenanceEngineClient()
        )
        var statuses: [ExecutionTelemetryProjectionSidecarStatus] = []
        let service = ExecutionTelemetryProvenanceProjectionService(
            agentChatURL: agentChatURL,
            lifecycleRecorder: lifecycleRecorder,
            sessionListClient: sessionListClient,
            liveProjectionClient: liveProjectionClient,
            sidecarStatusHandler: { statuses.append($0) }
        )

        await service.projectKnownSessions()

        XCTAssertEqual(statuses, [.available(agentChatURL: agentChatURL)])
    }

    private struct FakeGitInspector: WorkProvenanceGitInspecting {
        let snapshotsByDirectory: [String: WorkProvenanceGitSnapshot]

        func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot? {
            snapshotsByDirectory[directory]
        }
    }
}

private struct FixtureAgentChatHTTPLoader: AgentChatHTTPLoading {
    let result: Result<AgentChatHTTPResponse, Error>

    func load(_ request: URLRequest) async throws -> AgentChatHTTPResponse {
        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}

private actor CapturingProvenanceEngineClient: ProvenanceEngineContracts.ProvenanceEngineClient {
    private(set) var recordedLifecycleRequests: [ProvenanceEngineContracts.ProvenanceSessionLifecycleRequest] = []
    private let lifecycleResponse: ProvenanceEngineContracts.ProvenanceSessionLifecycleResponse

    init(
        lifecycleResponse: ProvenanceEngineContracts.ProvenanceSessionLifecycleResponse = ProvenanceEngineContracts.ProvenanceSessionLifecycleResponse(
            accepted: true,
            eventID: "event-1",
            sessionID: "session-1",
            relationshipSessionID: "session-1",
            externalIdentityID: "identity-1"
        )
    ) {
        self.lifecycleResponse = lifecycleResponse
    }

    func health() async throws -> ProvenanceEngineContracts.ProvenanceEngineHealth {
        throw TestError.unimplemented
    }

    func appendEvent(_ request: ProvenanceEngineContracts.ProvenanceAppendEventRequest) async throws -> ProvenanceEngineContracts.ProvenanceAppendEventResponse {
        throw TestError.unimplemented
    }

    func recordSessionLifecycle(
        _ request: ProvenanceEngineContracts.ProvenanceSessionLifecycleRequest
    ) async -> ProvenanceEngineContracts.ProvenanceSessionLifecycleResponse {
        recordedLifecycleRequests.append(request)
        return lifecycleResponse
    }

    func sessionTree(_ request: ProvenanceEngineContracts.ProvenanceSessionTreeRequest) async throws -> ProvenanceEngineContracts.ProvenanceSessionTreeResponse {
        throw TestError.unimplemented
    }

    func fileExplanation(_ request: ProvenanceEngineContracts.ProvenanceFileExplanationRequest) async throws
        -> ProvenanceEngineContracts.ProvenanceFileExplanationResponse {
        throw TestError.unimplemented
    }

    func worktrees(_ request: ProvenanceEngineContracts.ProvenanceWorktreeListRequest) async throws -> ProvenanceEngineContracts.ProvenanceWorktreeListResponse {
        throw TestError.unimplemented
    }

    func currentContext(_ request: ProvenanceEngineContracts.ProvenanceCurrentContextRequest) async throws
        -> ProvenanceEngineContracts.ProvenanceCurrentContextResponse {
        throw TestError.unimplemented
    }

    private enum TestError: Error {
        case unimplemented
    }
}
