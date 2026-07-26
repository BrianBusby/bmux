import Foundation
import ProvenanceEngineContracts
import XCTest

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

final class SessionProvenanceTests: XCTestCase {
    func testSessionLifecycleRecorderUsesPublicEngineLifecycleAPI() async throws {
        let client = CapturingProvenanceEngineClient()
        let recorder = WorkProvenanceSessionLifecycleRecorder(client: client)
        let timestamp = Date(timeIntervalSince1970: 1_725_000_000)

        await recorder.record(
            AgentSessionLifecycleChange(
                phase: .started,
                parentSessionID: "parent-session",
                agentKind: .codex,
                workspaceID: "workspace-1",
                surfaceID: "surface-1",
                workingDirectory: "/repo",
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
        XCTAssertEqual(request?.worktreeID, nil)
        XCTAssertEqual(request?.workingDirectory, "/repo")
        XCTAssertEqual(request?.externalIdentityKind, "subagent")
        XCTAssertEqual(request?.externalIdentityValue, "external-session-1")
        XCTAssertEqual(request?.displayName, "Build agent")
        XCTAssertEqual(request?.timestamp, timestamp)
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
