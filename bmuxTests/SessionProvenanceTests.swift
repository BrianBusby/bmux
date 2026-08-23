import Foundation
import BMUXAgentLaunch
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

    func testHookPromptSubmitRecordsFactualSessionAndWorkspaceDisplayLink() async throws {
        let client = CapturingProvenanceEngineClient()
        let recorder = WorkProvenanceCodingAgentEvidenceRecorder(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [
                "/repo": WorkProvenanceGitSnapshot(
                    repositoryRoot: "/repo",
                    commonDirectory: "/repo/.git",
                    remoteSlug: "manaflow-ai/bmux",
                    branch: "fix-session-view-terminal-overlay",
                    headCommit: "abc123",
                    isDirty: false
                )
            ])
        )
        let stableWorkspaceID = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_725_000_123)
        let record = AgentChatSessionRecord(
            sessionID: "raw-codex-session",
            agentKind: .codex,
            workspaceID: "runtime-workspace",
            surfaceID: "surface-1",
            workingDirectory: "/repo",
            transcriptPath: nil,
            state: .working(since: timestamp),
            lastActivityAt: timestamp,
            title: nil,
            pid: 123
        )
        let event = WorkstreamEvent(
            sessionId: "codex-raw-codex-session",
            hookEventName: .userPromptSubmit,
            source: "codex",
            workspaceId: "runtime-workspace",
            surfaceId: "surface-1",
            cwd: "/repo",
            context: WorkstreamContext(lastUserMessage: "Fix the PE session tab"),
            requestId: "hook-request-1",
            ppid: 123,
            receivedAt: timestamp
        )

        try await recorder.recordHookUserPromptSubmit(
            record: record,
            event: event,
            stableWorkspaceID: stableWorkspaceID
        )

        let requests = await client.appendedEventRequests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(request.event.eventType, .codingAgentPromptSubmitted)
        XCTAssertEqual(request.event.sessionID, "raw-codex-session")
        XCTAssertEqual(request.event.evidenceOrigin, .codexSession)
        XCTAssertEqual(request.event.confidence, .medium)

        let session = try XCTUnwrap(request.event.payload.session)
        XCTAssertEqual(session.id, "raw-codex-session")
        XCTAssertEqual(session.agentKind, "codex")
        XCTAssertEqual(session.workspaceID, "runtime-workspace")
        XCTAssertEqual(session.surfaceID, "surface-1")
        XCTAssertEqual(session.cwd, "/repo")
        XCTAssertEqual(session.status, "active")

        let turn = try XCTUnwrap(request.event.payload.codingAgentTurn)
        let prompt = try XCTUnwrap(request.event.payload.codingAgentPrompt)
        XCTAssertEqual(turn.sessionID, "raw-codex-session")
        XCTAssertEqual(turn.provider, "codex")
        XCTAssertEqual(turn.status, "started")
        XCTAssertEqual(turn.confidence, .medium)
        let legacyHookTurnSeed = [
            "raw-codex-session",
            "hook-request-1",
            "codex-raw-codex-session",
            String(timestamp.timeIntervalSince1970),
            "Fix the PE session tab"
        ].joined(separator: "\n")
        let expectedSyntheticProviderTurnID = WorkProvenanceStableIDFactory().id(
            prefix: "hook-codex-turn",
            value: legacyHookTurnSeed
        )
        XCTAssertEqual(turn.providerTurnID, expectedSyntheticProviderTurnID)
        XCTAssertEqual(prompt.sessionID, "raw-codex-session")
        XCTAssertEqual(prompt.turnID, turn.id)
        XCTAssertEqual(
            prompt.id,
            WorkProvenanceStableIDFactory().id(
                prefix: "coding-agent-prompt",
                value: "hook\nraw-codex-session\n\(expectedSyntheticProviderTurnID)\nFix the PE session tab"
            )
        )
        XCTAssertEqual(prompt.text, "Fix the PE session tab")
        XCTAssertEqual(prompt.confidence, .medium)
        XCTAssertEqual(
            request.event.id,
            WorkProvenanceStableIDFactory().id(prefix: "hook-codex-prompt", value: legacyHookTurnSeed)
        )

        let display = try XCTUnwrap(request.event.payload.workspaceDisplay)
        XCTAssertEqual(display.workspaceID, stableWorkspaceID.uuidString)
        XCTAssertEqual(display.currentDirectory, "/repo")
        XCTAssertEqual(display.lastSubmittedPrompt, "Fix the PE session tab")
        XCTAssertEqual(display.lastSubmittedPromptSessionID, "raw-codex-session")
        XCTAssertEqual(display.worktreeID, WorkProvenanceStableIDFactory().worktreeID(repositoryRoot: "/repo"))

        try await recorder.recordTranscriptUserPrompts(
            record: record,
            messages: [
                ChatMessage(id: "line-12", seq: 12, role: .user, timestamp: timestamp.addingTimeInterval(10), kind: .prose(ChatProse(text: "Backfilled transcript prompt"))),
                ChatMessage(id: "line-13", seq: 13, role: .agent, timestamp: timestamp.addingTimeInterval(11), kind: .prose(ChatProse(text: "Agent response"))),
            ],
            stableWorkspaceID: stableWorkspaceID
        )
        let backfillRequests = await client.appendedEventRequests
        let backfillRequest = try XCTUnwrap(backfillRequests.last)
        XCTAssertEqual(backfillRequests.count, 2)
        XCTAssertNil(backfillRequest.event.payload.codingAgentTurn)
        XCTAssertEqual(backfillRequest.event.payload.codingAgentPrompt?.text, "Backfilled transcript prompt")
        XCTAssertNil(backfillRequest.event.payload.codingAgentPrompt?.turnID)
        XCTAssertEqual(backfillRequest.event.payload.workspaceDisplay?.lastSubmittedPromptSessionID, "raw-codex-session")
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

    @MainActor
    func testExecutionTelemetryProjectionRecordsStructuredCodexEvidence() async throws {
        let agentChatURL = URL(string: "http://127.0.0.1:7739")!
        let sessionsData = Data("""
        [
          {"id":"session-sidecar","provider":"codex","cwd":"/repo","status":"idle","createdAt":1725000000000}
        ]
        """.utf8)
        let liveProjectionData = Data("""
        {"sessionId":"session-sidecar","snapshot":null}
        """.utf8)
        let eventsData = Data("""
        {
          "sessionId": "session-sidecar",
          "latestSequence": 9,
          "events": [
            {"schema":"execution.telemetry.v1","eventId":"evt-thread","sessionId":"session-sidecar","sequence":1,"capturedAtMs":1725000000000,"source":"provider","provider":"codex","providerSessionId":"thread-1","providerEvent":{"method":"thread/start"},"event":{"type":"session.provider-linked","providerSessionId":"thread-1"}},
            {"schema":"execution.telemetry.v1","eventId":"evt-prompt","sessionId":"session-sidecar","sequence":2,"capturedAtMs":1725000001000,"source":"sidecar","provider":"codex","providerSessionId":"thread-1","event":{"type":"prompt.submitted","text":"Implement durable evidence"}},
            {"schema":"execution.telemetry.v1","eventId":"evt-turn","sessionId":"session-sidecar","sequence":3,"capturedAtMs":1725000002000,"source":"provider","provider":"codex","providerSessionId":"thread-1","providerTurnId":"turn-1","providerEvent":{"method":"turn/started","turnId":"turn-1"},"event":{"type":"turn.started","turnId":"turn-1","model":"gpt-5","effort":"medium"}},
            {"schema":"execution.telemetry.v1","eventId":"evt-plan","sessionId":"session-sidecar","sequence":4,"capturedAtMs":1725000003000,"source":"provider","provider":"codex","providerSessionId":"thread-1","providerTurnId":"turn-1","event":{"type":"plan.updated","explanation":"Working plan","steps":[{"text":"Audit","status":"completed"},{"text":"Implement","status":"in_progress"}]}},
            {"schema":"execution.telemetry.v1","eventId":"evt-reason","sessionId":"session-sidecar","sequence":5,"capturedAtMs":1725000004000,"source":"provider","provider":"codex","providerSessionId":"thread-1","providerTurnId":"turn-1","event":{"type":"message.completed","stream":"reasoning","itemId":"reason-1","text":"Visible summary only"}},
            {"schema":"execution.telemetry.v1","eventId":"evt-tool-start","sessionId":"session-sidecar","sequence":6,"capturedAtMs":1725000005000,"source":"provider","provider":"codex","providerSessionId":"thread-1","providerTurnId":"turn-1","event":{"type":"tool.started","operationId":"tool-1","toolKind":"command","name":"shell","inputSummary":"swift test","cwd":"/repo","startedAtMs":1725000005000}},
            {"schema":"execution.telemetry.v1","eventId":"evt-tool-end","sessionId":"session-sidecar","sequence":7,"capturedAtMs":1725000006000,"source":"provider","provider":"codex","providerSessionId":"thread-1","providerTurnId":"turn-1","event":{"type":"tool.completed","operationId":"tool-1","toolKind":"command","name":"shell","status":"succeeded","outputSummary":"not persisted","exitCode":0,"completedAtMs":1725000006000}},
            {"schema":"execution.telemetry.v1","eventId":"evt-files","sessionId":"session-sidecar","sequence":8,"capturedAtMs":1725000007000,"source":"git-observer","provider":"codex","providerSessionId":"thread-1","providerTurnId":"turn-1","event":{"type":"files.changed","source":"git-observer","files":[{"path":"Sources/App.swift","status":"modified","summary":"modified Sources/App.swift"}]}},
            {"schema":"execution.telemetry.v1","eventId":"evt-turn-done","sessionId":"session-sidecar","sequence":9,"capturedAtMs":1725000008000,"source":"provider","provider":"codex","providerSessionId":"thread-1","providerTurnId":"turn-1","event":{"type":"turn.completed","turnId":"turn-1","durationMs":8000}}
          ]
        }
        """.utf8)
        let client = CapturingProvenanceEngineClient()
        let recorder = WorkProvenanceCodingAgentEvidenceRecorder(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [
                "/repo": WorkProvenanceGitSnapshot(
                    repositoryRoot: "/repo",
                    commonDirectory: "/repo/.git",
                    remoteSlug: "manaflow-ai/bmux",
                    branch: "richer-session-evidence-foundation",
                    headCommit: "abc123",
                    isDirty: true
                )
            ])
        )
        let service = ExecutionTelemetryProvenanceProjectionService(
            agentChatURL: agentChatURL,
            lifecycleRecorder: WorkProvenanceSessionLifecycleRecorder(client: client),
            codingAgentEvidenceRecorder: recorder,
            sessionListClient: AgentChatSessionListClient(
                baseURL: agentChatURL,
                loader: FixtureAgentChatHTTPLoader(result: .success(AgentChatHTTPResponse(data: sessionsData, statusCode: 200)))
            ),
            liveProjectionClient: ExecutionTelemetryLiveProjectionClient(
                baseURL: agentChatURL,
                loader: FixtureAgentChatHTTPLoader(result: .success(AgentChatHTTPResponse(data: liveProjectionData, statusCode: 200)))
            ),
            eventClient: ExecutionTelemetryEventClient(
                baseURL: agentChatURL,
                loader: FixtureAgentChatHTTPLoader(result: .success(AgentChatHTTPResponse(data: eventsData, statusCode: 200)))
            )
        )

        await service.projectKnownSessions()

        let requests = await client.appendedEventRequests
        XCTAssertEqual(requests.map(\.event.eventType), [
            .codingAgentThreadObserved,
            .codingAgentTurnObserved,
            .codingAgentPromptSubmitted,
            .codingAgentPlanUpdated,
            .codingAgentReasoningSummaryCompleted,
            .codingAgentCommandCompleted,
            .codingAgentFileChangeAttributed,
            .codingAgentTurnObserved,
        ])
        let prompt = try XCTUnwrap(requests.first { $0.event.eventType == .codingAgentPromptSubmitted }?.event.payload.codingAgentPrompt)
        let plan = try XCTUnwrap(requests.first { $0.event.eventType == .codingAgentPlanUpdated }?.event.payload.codingAgentPlanUpdate)
        let command = try XCTUnwrap(requests.first { $0.event.eventType == .codingAgentCommandCompleted }?.event.payload.codingAgentCommand)
        let fileAttribution = try XCTUnwrap(requests.first { $0.event.eventType == .codingAgentFileChangeAttributed }?.event.payload.codingAgentFileChangeAttribution)
        XCTAssertEqual(prompt.provider, "codex")
        XCTAssertEqual(prompt.text, "Implement durable evidence")
        XCTAssertEqual(prompt.turnID, command.turnID)
        XCTAssertEqual(plan.steps.map(\.status), ["completed", "in_progress"])
        XCTAssertEqual(command.cwd, "/repo")
        XCTAssertEqual(command.exitCode, 0)
        XCTAssertNil(command.outputSummary)
        XCTAssertEqual(fileAttribution.paths, ["Sources/App.swift"])
        XCTAssertEqual(fileAttribution.turnID, command.turnID)
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
    private(set) var appendedEventRequests: [ProvenanceEngineContracts.ProvenanceAppendEventRequest] = []
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
        appendedEventRequests.append(request)
        return ProvenanceEngineContracts.ProvenanceAppendEventResponse(eventID: request.event.id, eventType: request.event.eventType.rawValue)
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

    func workspaceDisplay(_ request: ProvenanceEngineContracts.ProvenanceWorkspaceDisplayRequest) async throws
        -> ProvenanceEngineContracts.ProvenanceWorkspaceDisplayResponse {
        throw TestError.unimplemented
    }

    func factualSessionProjection(
        _ request: ProvenanceEngineContracts.ProvenanceFactualSessionProjectionRequest
    ) async throws -> ProvenanceEngineContracts.ProvenanceFactualSessionProjectionResponse {
        throw TestError.unimplemented
    }

    private enum TestError: Error {
        case unimplemented
    }
}
