import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct WorkspaceSessionAssociationProjectionTests {
    @Test
    func associationConvergesFromHookToTranscriptAndRebuildsFromLedger() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let baseTime = Date(timeIntervalSince1970: 1_812_000_000)

        try await Self.appendAssociation(
            eventID: "event-workspace-session-hook",
            timestamp: baseTime,
            association: Self.association(
                sessionID: "codex-session-a",
                rawSessionID: "raw-codex-session-a",
                sourcePath: "hook",
                stage: "agent_detected",
                reasonCode: "hook_session_detected",
                observedAt: baseTime
            ),
            into: repository
        )

        let awaitingPrompt = try #require(try await repository.workspaceCodingAgentSessionAssociation(
            ProvenanceWorkspaceCodingAgentSessionAssociationRequest(workspaceID: Self.workspaceID)
        ).association)
        #expect(awaitingPrompt.sessionID == "codex-session-a")
        #expect(awaitingPrompt.sourcePath == "hook")
        #expect(awaitingPrompt.promptObservedAt == nil)

        let promptObservedAt = baseTime.addingTimeInterval(2)
        try await Self.appendAssociation(
            eventID: "event-workspace-session-transcript",
            timestamp: promptObservedAt,
            association: Self.association(
                sessionID: "codex-session-a",
                rawSessionID: "raw-codex-session-a",
                sourcePath: "transcript",
                stage: "association_persisted",
                reasonCode: "prompt_observed",
                observedAt: promptObservedAt,
                promptObservedAt: promptObservedAt
            ),
            into: repository
        )

        try await Self.expectCurrentAssociation(
            in: repository,
            sessionID: "codex-session-a",
            sourcePath: "transcript",
            latestEventID: "event-workspace-session-transcript"
        )
        #expect(try await repository.storageSummary().workspaceCodingAgentSessionAssociationCount == 1)

        try Self.deleteWorkspaceSessionAssociationProjectionRows(databaseURL: url)
        #expect(try await repository.workspaceCodingAgentSessionAssociation(
            ProvenanceWorkspaceCodingAgentSessionAssociationRequest(workspaceID: Self.workspaceID)
        ).found == false)
        #expect(try await repository.rebuildProjectionsFromEventLedger(batchSize: 1) == 2)
        try await Self.expectCurrentAssociation(
            in: repository,
            sessionID: "codex-session-a",
            sourcePath: "transcript",
            latestEventID: "event-workspace-session-transcript"
        )
    }

    @Test
    func canonicalEvidenceOutranksDisplayFallbackDuringReconciliation() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let baseTime = Date(timeIntervalSince1970: 1_812_000_050)
        let displaySessionID = "codex-session-display"
        let canonicalSessionID = "session-display"

        try await Self.appendAssociation(
            eventID: "event-display-fallback-prompt",
            timestamp: baseTime,
            association: Self.association(
                sessionID: displaySessionID,
                sourcePath: "display",
                stage: "workspace_session_association_persisted",
                reasonCode: "workspace_display_prompt_session_observed",
                observedAt: baseTime,
                promptObservedAt: baseTime
            ),
            into: repository
        )
        try await Self.appendAssociation(
            eventID: "event-transcript-thread-canonical",
            timestamp: baseTime.addingTimeInterval(1),
            association: Self.association(
                sessionID: canonicalSessionID,
                rawSessionID: displaySessionID,
                sourcePath: "transcript",
                stage: "agent_detected_awaiting_first_prompt",
                reasonCode: "transcript_thread_observed",
                observedAt: baseTime.addingTimeInterval(1)
            ),
            into: repository
        )

        let threadResponse = try await repository.workspaceCodingAgentSessionAssociation(
            ProvenanceWorkspaceCodingAgentSessionAssociationRequest(workspaceID: Self.workspaceID)
        )
        let threadAssociation = try #require(threadResponse.association)
        #expect(threadResponse.found)
        #expect(threadResponse.readiness.status == .agentDetectedAwaitingFirstPrompt)
        #expect(threadAssociation.sessionID == canonicalSessionID)
        #expect(threadAssociation.rawSessionID == displaySessionID)
        #expect(threadAssociation.sourcePath == "transcript")
        #expect(threadAssociation.promptObservedAt == nil)

        let hookPromptObservedAt = baseTime.addingTimeInterval(2)
        try await Self.appendAssociation(
            eventID: "event-hook-prompt-canonical",
            timestamp: hookPromptObservedAt,
            association: Self.association(
                sessionID: canonicalSessionID,
                rawSessionID: displaySessionID,
                sourcePath: "hook",
                stage: "workspace_session_association_persisted",
                reasonCode: "hook_prompt_observed",
                observedAt: hookPromptObservedAt,
                promptObservedAt: hookPromptObservedAt
            ),
            into: repository
        )

        try await Self.expectCurrentAssociation(
            in: repository,
            sessionID: canonicalSessionID,
            sourcePath: "hook",
            latestEventID: "event-hook-prompt-canonical"
        )

        let transcriptPromptObservedAt = baseTime.addingTimeInterval(3)
        try await Self.appendAssociation(
            eventID: "event-transcript-prompt-canonical",
            timestamp: transcriptPromptObservedAt,
            association: Self.association(
                sessionID: canonicalSessionID,
                rawSessionID: displaySessionID,
                sourcePath: "transcript",
                stage: "workspace_session_association_persisted",
                reasonCode: "transcript_prompt_observed",
                observedAt: transcriptPromptObservedAt,
                promptObservedAt: transcriptPromptObservedAt
            ),
            into: repository
        )

        try await Self.expectCurrentAssociation(
            in: repository,
            sessionID: canonicalSessionID,
            sourcePath: "transcript",
            latestEventID: "event-transcript-prompt-canonical"
        )

        try Self.deleteWorkspaceSessionAssociationProjectionRows(databaseURL: url)
        #expect(try await repository.rebuildProjectionsFromEventLedger(batchSize: 2) == 4)
        try await Self.expectCurrentAssociation(
            in: repository,
            sessionID: canonicalSessionID,
            sourcePath: "transcript",
            latestEventID: "event-transcript-prompt-canonical"
        )
        #expect(try await repository.storageSummary().workspaceCodingAgentSessionAssociationCount == 2)
    }

    @Test
    func replayedEvidenceIsIdempotentAndConcurrentWorkspacesStayIsolated() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let baseTime = Date(timeIntervalSince1970: 1_812_000_100)
        let otherWorkspaceID = "00000000-0000-0000-0000-00000000CAFE"

        try await Self.appendAssociation(
            eventID: "event-stale-session",
            timestamp: baseTime,
            association: Self.association(
                sessionID: "codex-stale-session",
                sourcePath: "replay",
                stage: "association_persisted",
                reasonCode: "historical_prompt_observed",
                observedAt: baseTime,
                promptObservedAt: baseTime
            ),
            into: repository
        )
        try await Self.appendAssociation(
            eventID: "event-other-workspace-session",
            timestamp: baseTime.addingTimeInterval(1),
            association: Self.association(
                workspaceID: otherWorkspaceID,
                sessionID: "codex-other-session",
                sourcePath: "transcript",
                stage: "association_persisted",
                reasonCode: "prompt_observed",
                observedAt: baseTime.addingTimeInterval(1),
                promptObservedAt: baseTime.addingTimeInterval(1)
            ),
            into: repository
        )
        try await Self.appendAssociation(
            eventID: "event-current-session",
            timestamp: baseTime.addingTimeInterval(5),
            association: Self.association(
                sessionID: "codex-current-session",
                sourcePath: "hook",
                stage: "association_persisted",
                reasonCode: "prompt_observed",
                observedAt: baseTime.addingTimeInterval(5),
                promptObservedAt: baseTime.addingTimeInterval(5)
            ),
            into: repository
        )
        try await Self.appendAssociation(
            eventID: "event-current-session-replay",
            timestamp: baseTime.addingTimeInterval(6),
            association: Self.association(
                sessionID: "codex-current-session",
                sourcePath: "replay",
                stage: "association_persisted",
                reasonCode: "prompt_observed",
                observedAt: baseTime.addingTimeInterval(6),
                promptObservedAt: baseTime.addingTimeInterval(5)
            ),
            into: repository
        )

        try await Self.expectCurrentAssociation(
            in: repository,
            sessionID: "codex-current-session",
            sourcePath: "replay",
            latestEventID: "event-current-session-replay"
        )
        let otherResponse = try await repository.workspaceCodingAgentSessionAssociation(
            ProvenanceWorkspaceCodingAgentSessionAssociationRequest(workspaceID: otherWorkspaceID)
        )
        #expect(otherResponse.association?.sessionID == "codex-other-session")
        #expect(try await repository.storageSummary().workspaceCodingAgentSessionAssociationCount == 3)
    }

    private static let workspaceID = "00000000-0000-0000-0000-000000001842"

    private static func expectCurrentAssociation(
        in repository: ProvenanceSQLiteRepository,
        sessionID: String,
        sourcePath: String,
        latestEventID: String
    ) async throws {
        let response = try await repository.workspaceCodingAgentSessionAssociation(
            ProvenanceWorkspaceCodingAgentSessionAssociationRequest(workspaceID: Self.workspaceID)
        )
        let association = try #require(response.association)

        #expect(response.found)
        #expect(response.readiness.status == .associationEstablishedProjectionPending)
        #expect(association.sessionID == sessionID)
        #expect(association.canonicalSessionID == sessionID)
        #expect(association.sourcePath == sourcePath)
        #expect(association.promptObservedAt != nil)
        #expect(association.latestEventID == latestEventID)
    }

    private static func appendAssociation(
        eventID: String,
        timestamp: Date,
        association: ProvenanceWorkspaceCodingAgentSessionAssociationRecord,
        into repository: ProvenanceSQLiteRepository
    ) async throws {
        try await repository.appendEvent(
            ProvenanceEvent(
                id: eventID,
                eventType: association.promptObservedAt == nil
                    ? .codingAgentThreadObserved
                    : .codingAgentPromptSubmitted,
                timestamp: timestamp,
                repositoryID: association.repositoryID,
                worktreeID: association.worktreeID,
                sessionID: association.sessionID,
                source: .observed,
                evidenceOrigin: ProvenanceEvidenceOrigin(rawValue: "workspace-session-association-tests"),
                evidenceScope: ProvenanceEvidenceScope(level: .personal, id: "local-test"),
                confidence: .high,
                payload: ProvenanceEventPayload(workspaceCodingAgentSessionAssociation: association)
            )
        )
    }

    private static func association(
        workspaceID: String = Self.workspaceID,
        sessionID: String,
        rawSessionID: String? = nil,
        sourcePath: String,
        stage: String,
        reasonCode: String,
        observedAt: Date,
        promptObservedAt: Date? = nil
    ) -> ProvenanceWorkspaceCodingAgentSessionAssociationRecord {
        ProvenanceWorkspaceCodingAgentSessionAssociationRecord(
            id: "workspace-session-\(workspaceID)-codex-\(sessionID)",
            workspaceID: workspaceID,
            sessionID: sessionID,
            agentKind: "codex",
            rawSessionID: rawSessionID,
            canonicalSessionID: sessionID,
            surfaceID: "surface-session-association-tests",
            repositoryID: "repository-session-association-tests",
            worktreeID: "worktree-session-association-tests",
            currentDirectory: "/repos/example",
            sourcePath: sourcePath,
            stage: stage,
            reasonCode: reasonCode,
            retryable: true,
            firstObservedAt: observedAt,
            promptObservedAt: promptObservedAt,
            lastObservedAt: observedAt,
            lastTransitionAt: observedAt
        )
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-workspace-session-association-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private static func deleteWorkspaceSessionAssociationProjectionRows(databaseURL: URL) throws {
        let database = try ProvenanceSQLiteDatabase(url: databaseURL)
        try database.execute("DELETE FROM provenance_workspace_coding_agent_session_associations")
    }
}
