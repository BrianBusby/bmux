import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct SemanticMessageFoundationTests {
    @Test
    func rendererBuildsDirectionalImplementationMessageWithoutLeakingNoisyFilenames() throws {
        let payload = ProvenanceCodingAgentCurrentActivityPayload(
            activityKind: .implementation,
            summary: "Changing App Menu workspace selection to use TabManager",
            action: "changing",
            subject: "App Menu workspace selection",
            target: "TabManager",
            components: ["Sources/AppMenu.swift", "Tests/AppMenuTests.swift", "docs/workspace-selection.md"],
            basis: "file_change_attribution"
        )
        let inference = Self.semanticRecord(
            id: "semantic-current-activity-1",
            kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
            scope: .turn,
            scopeID: "turn-1",
            payload: payload.semanticPayloadValue,
            confidence: .high,
            specificity: .granular
        )

        let message = try #require(ProvenanceSemanticMessageRenderer.record(
            for: inference,
            createdAt: Self.timestamp
        ))

        #expect(message.concisePhrase == "Changing App Menu workspace selection to use TabManager")
        #expect(message.expandedMeaning == "The App Menu workspace selection is being changed so it uses TabManager.")
        #expect(message.concisePhrase.contains("AppMenu.swift") == false)
        #expect(message.concisePhrase.contains("AppMenuTests") == false)
        #expect(message.structuredSemanticPayload == inference.payload)
        #expect(message.supportingEvidenceRefs == Self.supportingEvidenceRefs)
        #expect(message.supportingFactualRevision == 7)
        #expect(message.confidence == .high)
        #expect(message.specificity == .granular)
        #expect(message.presentationProducerType == .rule)
        #expect(message.presentationProducerID == ProvenanceSemanticMessageRenderer.producerID)
        #expect(message.presentationProducerVersion == ProvenanceSemanticMessageRenderer.producerVersion)
        #expect(message.presentationPolicyID == ProvenanceSemanticMessagePresentationPolicy().id)
        #expect(message.status == .active)
    }

    @Test
    func rendererUsesComponentNamesOnlyWhenNoBetterSubjectExists() throws {
        let payload = ProvenanceCodingAgentCurrentActivityPayload(
            activityKind: .implementation,
            summary: "Updating workspace selection",
            action: "changing",
            subject: nil,
            target: "TabManager",
            components: ["Tests/AppMenuTests.swift", "Sources/AppMenu.swift"],
            basis: "file_change_attribution"
        )
        let inference = Self.semanticRecord(
            id: "semantic-current-activity-component",
            kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
            scope: .turn,
            scopeID: "turn-1",
            payload: payload.semanticPayloadValue
        )

        let message = try #require(ProvenanceSemanticMessageRenderer.record(
            for: inference,
            createdAt: Self.timestamp
        ))

        #expect(message.concisePhrase == "Changing AppMenu to use TabManager")
        #expect(message.expandedMeaning == "The AppMenu is being changed so it uses TabManager.")
    }

    @Test
    func rendererKeepsAmbiguousDestinationBroadInsteadOfInventingTarget() throws {
        let payload = ProvenanceCodingAgentCurrentActivityPayload(
            activityKind: .implementation,
            summary: "Changing workspace selection",
            action: "changing",
            subject: "workspace selection",
            target: nil,
            components: ["Sources/AppMenu.swift"],
            basis: "plan_update"
        )
        let inference = Self.semanticRecord(
            id: "semantic-current-activity-ambiguous",
            kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
            scope: .turn,
            scopeID: "turn-1",
            payload: payload.semanticPayloadValue
        )

        let message = try #require(ProvenanceSemanticMessageRenderer.record(
            for: inference,
            createdAt: Self.timestamp
        ))

        #expect(message.concisePhrase == "Changing workspace selection")
        #expect(message.concisePhrase.contains("TabManager") == false)
    }

    @Test
    func rendererCoversInvestigationValidationDebuggingAndUnknownActivityMessages() throws {
        let cases: [(ProvenanceCodingAgentCurrentActivityPayload, String, String)] = [
            (
                ProvenanceCodingAgentCurrentActivityPayload(
                    activityKind: .investigation,
                    summary: "Inspecting workspace-selection callers",
                    action: "inspecting",
                    subject: "workspace-selection callers",
                    basis: "visible_reasoning_summary"
                ),
                "Inspecting workspace-selection callers",
                "The agent is investigating workspace-selection callers."
            ),
            (
                ProvenanceCodingAgentCurrentActivityPayload(
                    activityKind: .validation,
                    summary: "Validating with swift test --filter WorkspaceSelectionTests",
                    action: "validating",
                    subject: "WorkspaceSelectionTests",
                    basis: "completed_command"
                ),
                "Validating with swift test --filter WorkspaceSelectionTests",
                "The agent is validating the current changes using swift test --filter WorkspaceSelectionTests."
            ),
            (
                ProvenanceCodingAgentCurrentActivityPayload(
                    activityKind: .debugging,
                    summary: "Investigating failed command: swift test",
                    action: "debugging",
                    subject: "swift test",
                    basis: "completed_command"
                ),
                "Investigating failed command: swift test",
                "The agent is investigating the failed command swift test."
            ),
            (
                ProvenanceCodingAgentCurrentActivityPayload(
                    activityKind: .unknown,
                    summary: "No current turn activity is deterministically known",
                    basis: "factual_projection",
                    unknownReason: "No active turn has prompt, plan, command, reasoning, or file-change evidence."
                ),
                "Current activity unknown",
                "No active turn has prompt, plan, command, reasoning, or file-change evidence."
            ),
        ]

        for (index, fixture) in cases.enumerated() {
            let inference = Self.semanticRecord(
                id: "semantic-current-activity-case-\(index)",
                kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
                scope: .turn,
                scopeID: "turn-\(index)",
                payload: fixture.0.semanticPayloadValue,
                confidence: index == 3 ? .unknown : .medium,
                specificity: index == 3 ? .broad : .granular
            )
            let message = try #require(ProvenanceSemanticMessageRenderer.record(
                for: inference,
                createdAt: Self.timestamp
            ))

            #expect(message.concisePhrase == fixture.1)
            #expect(message.expandedMeaning == fixture.2)
            #expect(message.confidence == inference.confidence)
            #expect(message.specificity == inference.specificity)
        }
    }

    @Test
    func rendererSeparatesSessionPhaseAndIntentWordingFromStructuredMeaning() throws {
        let phaseInference = Self.semanticRecord(
            id: "semantic-phase-1",
            kind: ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue,
            scope: .session,
            scopeID: "session-1",
            payload: ProvenanceCodingAgentSessionPhasePayload(
                phase: .validation,
                reason: "a completed command is a test command",
                signals: ["completed_command"]
            ).semanticPayloadValue,
            specificity: .scoped
        )
        let intentPayload = ProvenanceCodingAgentIntentPayload(
            summary: "Move workspace-selection callers onto the shared path",
            action: "changing",
            subject: "workspace-selection callers",
            target: "the shared path",
            purpose: nil,
            components: ["Sources/AppMenu.swift"],
            sourceText: "Move workspace-selection callers onto the shared path"
        )
        let intentInference = Self.semanticRecord(
            id: "semantic-turn-intent-1",
            kind: ProvenanceCodingAgentSemanticInferenceKind.turnIntent.rawValue,
            scope: .turn,
            scopeID: "turn-1",
            payload: intentPayload.semanticPayloadValue,
            specificity: .scoped
        )

        let phaseMessage = try #require(ProvenanceSemanticMessageRenderer.record(
            for: phaseInference,
            createdAt: Self.timestamp
        ))
        let intentMessage = try #require(ProvenanceSemanticMessageRenderer.record(
            for: intentInference,
            createdAt: Self.timestamp
        ))

        #expect(phaseMessage.concisePhrase == "Validation")
        #expect(phaseMessage.expandedMeaning == "The session is in the validation phase because a completed command is a test command.")
        #expect(phaseMessage.structuredSemanticPayload == phaseInference.payload)
        #expect(intentMessage.concisePhrase == "Changing workspace-selection callers to use the shared path")
        #expect(intentMessage.expandedMeaning == "This turn is trying to move workspace-selection callers onto the shared path.")
        #expect(intentMessage.structuredSemanticPayload == intentInference.payload)
    }

    @Test
    func materializationPublishesCachesAndSupersedesMessagesWhenInferenceChanges() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let prior = Self.semanticRecord(
            id: "semantic-current-activity-1",
            kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
            scope: .turn,
            scopeID: "turn-1",
            payload: ProvenanceCodingAgentCurrentActivityPayload(
                activityKind: .investigation,
                summary: "Inspecting workspace-selection callers",
                action: "inspecting",
                subject: "workspace-selection callers",
                basis: "visible_reasoning_summary"
            ).semanticPayloadValue,
            createdAt: Self.timestamp
        )
        let replacement = Self.semanticRecord(
            id: "semantic-current-activity-2",
            kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
            scope: .turn,
            scopeID: "turn-1",
            payload: ProvenanceCodingAgentCurrentActivityPayload(
                activityKind: .implementation,
                summary: "Changing App Menu workspace selection to use TabManager",
                action: "changing",
                subject: "App Menu workspace selection",
                target: "TabManager",
                components: ["Sources/AppMenu.swift"],
                basis: "file_change_attribution"
            ).semanticPayloadValue,
            confidence: .high,
            specificity: .granular,
            createdAt: Self.timestamp.addingTimeInterval(10)
        )

        let first = try await repository.materializeSemanticMessages(
            ProvenanceSemanticMessageMaterializationRequest(
                semanticInferenceRecords: [prior],
                createdAt: Self.timestamp.addingTimeInterval(1)
            )
        )
        let unchanged = try await repository.materializeSemanticMessages(
            ProvenanceSemanticMessageMaterializationRequest(
                semanticInferenceRecords: [prior],
                createdAt: Self.timestamp.addingTimeInterval(2)
            )
        )
        let second = try await repository.materializeSemanticMessages(
            ProvenanceSemanticMessageMaterializationRequest(
                semanticInferenceRecords: [replacement],
                createdAt: Self.timestamp.addingTimeInterval(20)
            )
        )
        let active = try await repository.semanticMessages(
            ProvenanceSemanticMessageQueryRequest(
                scope: .turn,
                scopeID: "turn-1",
                semanticInferenceKind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue
            )
        )
        let history = try await repository.semanticMessages(
            ProvenanceSemanticMessageQueryRequest(
                scope: .turn,
                scopeID: "turn-1",
                semanticInferenceKind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
                includeInactive: true
            )
        )

        #expect(first.publishedMessageIDs.count == 1)
        #expect(first.unchangedMessageIDs.isEmpty)
        #expect(unchanged.publishedMessageIDs.isEmpty)
        #expect(unchanged.unchangedMessageIDs == first.publishedMessageIDs)
        #expect(second.publishedMessageIDs.count == 1)
        #expect(second.records.first?.supersedes == first.publishedMessageIDs)
        #expect(active.records.map(\.id) == second.publishedMessageIDs)
        #expect(active.records.first?.concisePhrase == "Changing App Menu workspace selection to use TabManager")
        #expect(history.records.map(\.id) == [second.publishedMessageIDs[0], first.publishedMessageIDs[0]])
        #expect(history.records.first?.status == .active)
        #expect(history.records.last?.status == .superseded)
        #expect(history.records.last?.supersededBy == second.publishedMessageIDs[0])
    }

    @Test
    func presentationPoliciesMaintainIndependentActiveMessages() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let inference = Self.semanticRecord(
            id: "semantic-policy-1",
            kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
            scope: .turn,
            scopeID: "turn-1",
            payload: ProvenanceCodingAgentCurrentActivityPayload(
                activityKind: .validation,
                summary: "Validating with swift test",
                action: "validating",
                subject: "swift test",
                basis: "completed_command"
            ).semanticPayloadValue
        )
        let defaultPolicy = ProvenanceSemanticMessagePresentationPolicy()
        let compactPolicy = ProvenanceSemanticMessagePresentationPolicy(
            id: "provenance-engine.semantic-message.compact",
            version: "v1",
            localeIdentifier: "en-US"
        )

        let defaultResponse = try await repository.materializeSemanticMessages(
            ProvenanceSemanticMessageMaterializationRequest(
                semanticInferenceRecords: [inference],
                presentationPolicy: defaultPolicy,
                createdAt: Self.timestamp
            )
        )
        let compactResponse = try await repository.materializeSemanticMessages(
            ProvenanceSemanticMessageMaterializationRequest(
                semanticInferenceRecords: [inference],
                presentationPolicy: compactPolicy,
                createdAt: Self.timestamp.addingTimeInterval(1)
            )
        )
        let defaultQuery = try await repository.semanticMessages(
            ProvenanceSemanticMessageQueryRequest(
                scope: .turn,
                scopeID: "turn-1",
                presentationPolicyID: defaultPolicy.id
            )
        )
        let compactQuery = try await repository.semanticMessages(
            ProvenanceSemanticMessageQueryRequest(
                scope: .turn,
                scopeID: "turn-1",
                presentationPolicyID: compactPolicy.id
            )
        )

        #expect(defaultResponse.publishedMessageIDs.count == 1)
        #expect(compactResponse.publishedMessageIDs.count == 1)
        #expect(defaultResponse.publishedMessageIDs != compactResponse.publishedMessageIDs)
        #expect(defaultQuery.records.map(\.id) == defaultResponse.publishedMessageIDs)
        #expect(compactQuery.records.map(\.id) == compactResponse.publishedMessageIDs)
        #expect(defaultQuery.records.first?.presentationPolicyID == defaultPolicy.id)
        #expect(compactQuery.records.first?.presentationPolicyID == compactPolicy.id)
    }

    @Test
    func independentMessageRetrievalCanFilterByInferenceAndUnknownTurnReturnsEmpty() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let inference = Self.semanticRecord(
            id: "semantic-query-1",
            kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
            scope: .turn,
            scopeID: "turn-1",
            payload: ProvenanceCodingAgentCurrentActivityPayload(
                activityKind: .investigation,
                summary: "Inspecting workspace selection",
                action: "inspecting",
                subject: "workspace selection",
                basis: "visible_reasoning_summary"
            ).semanticPayloadValue
        )

        let materialized = try await repository.materializeSemanticMessages(
            ProvenanceSemanticMessageMaterializationRequest(
                semanticInferenceRecords: [inference],
                createdAt: Self.timestamp
            )
        )
        let byInference = try await repository.semanticMessages(
            ProvenanceSemanticMessageQueryRequest(
                scope: .turn,
                scopeID: "turn-1",
                semanticInferenceID: inference.id
            )
        )
        let unknownTurn = try await repository.semanticMessages(
            ProvenanceSemanticMessageQueryRequest(
                scope: .turn,
                scopeID: "turn-missing",
                semanticInferenceKind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue
            )
        )

        #expect(byInference.records.map(\.id) == materialized.publishedMessageIDs)
        #expect(unknownTurn.records.isEmpty)
    }

    @Test
    func missingSupersededMessageFailureRollsBackReplacement() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let active = Self.semanticMessage(
            id: "semantic-message-1",
            semanticInferenceID: "semantic-current-activity-1"
        )
        let replacement = Self.semanticMessage(
            id: "semantic-message-2",
            semanticInferenceID: "semantic-current-activity-2",
            supersedes: ["semantic-message-missing"]
        )

        _ = try await repository.publishSemanticMessage(ProvenanceSemanticMessagePublishRequest(record: active))
        do {
            _ = try await repository.publishSemanticMessage(ProvenanceSemanticMessagePublishRequest(record: replacement))
            Issue.record("Expected missing superseded message failure")
        } catch let error as ProvenanceSQLiteError {
            if case let .sqlite(message) = error {
                #expect(message.contains("cannot be superseded"))
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let history = try await repository.semanticMessages(
            ProvenanceSemanticMessageQueryRequest(
                scope: .turn,
                scopeID: "turn-1",
                semanticInferenceKind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
                includeInactive: true
            )
        )
        #expect(history.records == [active])
    }

    @Test
    func semanticMessageStorageStaysSeparateFromDeterministicCurrentState() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let session = ProvenanceSessionRecord(
            id: "session-1",
            agentKind: "codex",
            status: "active",
            startedAt: Self.timestamp,
            updatedAt: Self.timestamp
        )
        let event = ProvenanceEvent(
            id: "event-session-1",
            eventType: .sessionObserved,
            timestamp: session.updatedAt,
            sessionID: session.id,
            source: .observed,
            confidence: .high,
            payload: ProvenanceEventPayload(session: session)
        )
        let inference = Self.semanticRecord(
            id: "semantic-current-activity-state",
            kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
            scope: .turn,
            scopeID: "turn-1",
            payload: ProvenanceCodingAgentCurrentActivityPayload(
                activityKind: .investigation,
                summary: "Inspecting workspace selection",
                action: "inspecting",
                subject: "workspace selection",
                basis: "visible_reasoning_summary"
            ).semanticPayloadValue
        )

        try await repository.appendEvent(event)
        let factualBeforeMessage = try await repository.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: session.id)
        )
        let materialized = try await repository.materializeSemanticMessages(
            ProvenanceSemanticMessageMaterializationRequest(
                semanticInferenceRecords: [inference],
                createdAt: Self.timestamp
            )
        )
        let factualAfterMessage = try await repository.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: session.id)
        )

        #expect(factualAfterMessage == factualBeforeMessage)
        #expect(try await repository.rebuildProjectionsFromEventLedger(batchSize: 1) == 1)
        #expect(try await repository.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: session.id)
        ) == factualBeforeMessage)
        #expect(try await repository.semanticMessages(
            ProvenanceSemanticMessageQueryRequest(scope: .turn, scopeID: "turn-1", semanticInferenceID: inference.id)
        ).records.map(\.id) == materialized.publishedMessageIDs)
        #expect(try await repository.validateProjectionKeys(limit: 10).mismatches.isEmpty)
    }

    private static let timestamp = Date(timeIntervalSince1970: 1_800_000_000)

    private static let supportingEvidenceRefs = [
        ProvenanceSemanticEvidenceReference(
            kind: "ledger_event",
            id: "event-prompt-1",
            ledgerSequence: 3
        ),
        ProvenanceSemanticEvidenceReference(
            kind: "factual_session_projection",
            id: "session-1",
            factualRevision: 7
        ),
    ]

    private static func semanticRecord(
        id: String,
        kind: String,
        scope: ProvenanceSemanticInferenceScope,
        scopeID: String,
        payload: ProvenanceSemanticPayloadValue,
        confidence: ProvenanceConfidence = .medium,
        specificity: ProvenanceSemanticSpecificity = .granular,
        createdAt: Date = timestamp
    ) -> ProvenanceSemanticInferenceRecord {
        ProvenanceSemanticInferenceRecord(
            id: id,
            kind: kind,
            scope: scope,
            scopeID: scopeID,
            payload: payload,
            supportingEvidenceRefs: supportingEvidenceRefs,
            supportingFactualRevision: 7,
            confidence: confidence,
            specificity: specificity,
            producerType: .rule,
            producerID: "semantic-fixture-worker",
            producerVersion: "semantic-fixture-v1",
            createdAt: createdAt
        )
    }

    private static func semanticMessage(
        id: String,
        semanticInferenceID: String,
        supersedes: [String] = []
    ) -> ProvenanceSemanticMessageRecord {
        let payload = ProvenanceCodingAgentCurrentActivityPayload(
            activityKind: .investigation,
            summary: "Inspecting workspace selection",
            action: "inspecting",
            subject: "workspace selection",
            basis: "visible_reasoning_summary"
        )
        return ProvenanceSemanticMessageRecord(
            id: id,
            semanticInferenceID: semanticInferenceID,
            semanticInferenceKind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
            scope: .turn,
            scopeID: "turn-1",
            concisePhrase: "Inspecting workspace selection",
            expandedMeaning: "The agent is investigating workspace selection.",
            structuredSemanticPayload: payload.semanticPayloadValue,
            supportingEvidenceRefs: supportingEvidenceRefs,
            supportingFactualRevision: 7,
            confidence: .medium,
            specificity: .granular,
            presentationProducerType: .rule,
            presentationProducerID: ProvenanceSemanticMessageRenderer.producerID,
            presentationProducerVersion: ProvenanceSemanticMessageRenderer.producerVersion,
            presentationPolicyID: ProvenanceSemanticMessagePresentationPolicy().id,
            presentationPolicyVersion: ProvenanceSemanticMessagePresentationPolicy().version,
            localeIdentifier: ProvenanceSemanticMessagePresentationPolicy().localeIdentifier,
            createdAt: id == "semantic-message-1" ? timestamp : timestamp.addingTimeInterval(10),
            supersedes: supersedes
        )
    }

    private static func temporaryDatabaseURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-semantic-message-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return directory.appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
