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

    @Test
    func newerHookOnlySessionOutranksStaleTranscriptPrompt() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let baseTime = Date(timeIntervalSince1970: 1_812_000_150)

        try await Self.appendAssociation(
            eventID: "event-old-transcript-prompt",
            timestamp: baseTime,
            association: Self.association(
                sessionID: "codex-old-transcript",
                sourcePath: "transcript",
                stage: "workspace_session_association_persisted",
                reasonCode: "transcript_prompt_observed",
                observedAt: baseTime,
                promptObservedAt: baseTime
            ),
            into: repository
        )
        try await Self.appendAssociation(
            eventID: "event-current-hook-detected",
            timestamp: baseTime.addingTimeInterval(30),
            association: Self.association(
                sessionID: "codex-current-hook-only",
                rawSessionID: "codex-current-hook-only",
                sourcePath: "hook",
                stage: "agent_detected_awaiting_first_prompt",
                reasonCode: "hook_session_detected",
                observedAt: baseTime.addingTimeInterval(30)
            ),
            into: repository
        )

        let response = try await repository.workspaceCodingAgentSessionAssociation(
            ProvenanceWorkspaceCodingAgentSessionAssociationRequest(workspaceID: Self.workspaceID)
        )
        let association = try #require(response.association)
        #expect(response.found)
        #expect(response.readiness.status == .agentDetectedAwaitingFirstPrompt)
        #expect(association.sessionID == "codex-current-hook-only")
        #expect(association.sourcePath == "hook")
        #expect(association.promptObservedAt == nil)
    }

    @Test
    func callerAssociationRequiresSurfaceAndProviderIdentityAndRejectsAmbiguity() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let now = Date(timeIntervalSince1970: 1_812_000_200)
        for (session, raw, surface) in [
            ("pe-a", "provider-a", "surface-a"),
            ("pe-b", "provider-b", "surface-b"),
        ] {
            try await Self.appendAssociation(
                eventID: "event-\(session)", timestamp: now,
                association: Self.association(sessionID: session, rawSessionID: raw,
                    surfaceID: surface, sourcePath: "transcript", stage: "linked",
                    reasonCode: "observed", observedAt: now), into: repository
            )
        }
        func request(_ surface: String?, _ provider: String?) -> ProvenanceWorkspaceCodingAgentSessionAssociationRequest {
            .init(workspaceID: Self.workspaceID, surfaceID: surface, providerSessionID: provider)
        }
        #expect(try await repository.workspaceCodingAgentSessionAssociation(request("surface-a", "provider-a")).association?.sessionID == "pe-a")
        #expect(try await repository.workspaceCodingAgentSessionAssociation(request("surface-b", "provider-b")).association?.sessionID == "pe-b")
        #expect(try await repository.workspaceCodingAgentSessionAssociation(request("surface-a", "provider-b")).reason == "no_canonical_association")
        #expect(try await repository.workspaceCodingAgentSessionAssociation(request("surface-a", nil)).reason == "incomplete_caller_identity")
        try await Self.appendAssociation(
            eventID: "event-conflict", timestamp: now,
            association: Self.association(sessionID: "pe-conflict", rawSessionID: "provider-a",
                surfaceID: "surface-a", sourcePath: "transcript", stage: "linked",
                reasonCode: "observed", observedAt: now), into: repository
        )
        #expect(try await repository.workspaceCodingAgentSessionAssociation(request("surface-a", "provider-a")).reason == "ambiguous_caller_identity")
    }

    @Test
    func resumedAssociationMovesToNewSurfaceWithoutSelectingAnOldPane() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let now = Date(timeIntervalSince1970: 1_812_000_300)
        for (event, surface, provider, time) in [
            ("first-launch", "old-surface", "provider-old", now),
            ("resume", "new-surface", "provider-new", now.addingTimeInterval(1)),
        ] {
            try await Self.appendAssociation(
                eventID: event, timestamp: time,
                association: Self.association(sessionID: "pe-session", rawSessionID: provider,
                    surfaceID: surface, sourcePath: "transcript", stage: "linked",
                    reasonCode: "observed", observedAt: time), into: repository
            )
        }
        // A delayed replay from the previous surface must not undo the resume.
        try await Self.appendAssociation(
            eventID: "late-old-event", timestamp: now,
            association: Self.association(sessionID: "pe-session", rawSessionID: "provider-old",
                surfaceID: "old-surface", sourcePath: "replay", stage: "linked",
                reasonCode: "observed", observedAt: now), into: repository
        )
        let old = try await repository.workspaceCodingAgentSessionAssociation(
            .init(workspaceID: Self.workspaceID, surfaceID: "old-surface", providerSessionID: "provider-old")
        )
        let resumed = try await repository.workspaceCodingAgentSessionAssociation(
            .init(workspaceID: Self.workspaceID, surfaceID: "new-surface", providerSessionID: "provider-new")
        )
        #expect(old.reason == "no_canonical_association")
        #expect(resumed.association?.sessionID == "pe-session")
        #expect(resumed.association?.latestEventID == "late-old-event")
    }

    @Test
    func newerObservationWithoutIdentityDoesNotHideEarlierResume() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let now = Date(timeIntervalSince1970: 1_812_000_400)
        for (event, surface, provider, offset) in [
            ("first", "old-surface", "provider-old", 0.0),
            ("resume", "new-surface", "provider-new", 2.0),
            ("late-old", "old-surface", "provider-old", 1.0),
        ] {
            let time = now.addingTimeInterval(offset)
            if event == "resume" {
                try await Self.appendAssociation(
                    eventID: "newer-without-identity", timestamp: now.addingTimeInterval(3),
                    association: Self.association(sessionID: "pe-session", surfaceID: nil,
                        sourcePath: "sidecar", stage: "linked", reasonCode: "observed",
                        observedAt: now.addingTimeInterval(3)), into: repository
                )
            }
            try await Self.appendAssociation(
                eventID: event, timestamp: time,
                association: Self.association(sessionID: "pe-session", rawSessionID: provider,
                    surfaceID: surface, sourcePath: "transcript", stage: "linked",
                    reasonCode: "observed", observedAt: time), into: repository
            )
        }
        let result = try await repository.workspaceCodingAgentSessionAssociation(
            .init(workspaceID: Self.workspaceID, surfaceID: "new-surface", providerSessionID: "provider-new")
        )
        #expect(result.association?.sessionID == "pe-session")
        _ = try await repository.rebuildProjectionsFromEventLedger(batchSize: 1)
        let rebuilt = try await repository.workspaceCodingAgentSessionAssociation(
            .init(workspaceID: Self.workspaceID, surfaceID: "new-surface", providerSessionID: "provider-new")
        )
        #expect(rebuilt.association?.sessionID == "pe-session")
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
        surfaceID: String? = "surface-session-association-tests",
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
            surfaceID: surfaceID,
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
