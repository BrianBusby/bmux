import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

@Suite
struct SemanticInferenceFrameworkTests {
    @Test
    func persistsSemanticInferenceRecordAndPreservesProducerEvidenceAndCalibration() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let record = Self.semanticRecord(
            id: "semantic-1",
            producerType: .model,
            confidence: .medium,
            specificity: .granular
        )

        let response = try await repository.publishSemanticInference(
            ProvenanceSemanticInferencePublishRequest(record: record)
        )
        let query = try await repository.semanticInferences(
            ProvenanceSemanticInferenceQueryRequest(
                scope: .session,
                scopeID: "session-1",
                kind: Self.fixtureKind
            )
        )

        #expect(response.accepted)
        #expect(response.inferenceID == record.id)
        #expect(response.supersededInferenceIDs.isEmpty)
        #expect(query.schemaVersion == 1)
        #expect(query.records == [record])
        #expect(query.records.first?.producerType == .model)
        #expect(query.records.first?.producerID == "semantic-fixture-worker")
        #expect(query.records.first?.producerVersion == "model-fixture-v1")
        #expect(query.records.first?.confidence == .medium)
        #expect(query.records.first?.specificity == .granular)
        #expect(query.records.first?.supportingFactualRevision == 7)
        #expect(query.records.first?.supportingEvidenceRefs == Self.supportingEvidenceRefs)
    }

    @Test
    func supersessionPreservesHistoryAndOnlyReturnsActiveRecordsByDefault() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let prior = Self.semanticRecord(id: "semantic-1")
        let replacement = Self.semanticRecord(
            id: "semantic-2",
            producerType: .rule,
            producerVersion: "rule-fixture-v2",
            confidence: .high,
            specificity: .atomic,
            supersedes: [prior.id]
        )

        _ = try await repository.publishSemanticInference(ProvenanceSemanticInferencePublishRequest(record: prior))
        _ = try await repository.publishSemanticInference(ProvenanceSemanticInferencePublishRequest(record: replacement))

        let active = try await repository.semanticInferences(
            ProvenanceSemanticInferenceQueryRequest(scope: .session, scopeID: "session-1", kind: Self.fixtureKind)
        )
        let history = try await repository.semanticInferences(
            ProvenanceSemanticInferenceQueryRequest(
                scope: .session,
                scopeID: "session-1",
                kind: Self.fixtureKind,
                includeInactive: true
            )
        )

        #expect(active.records.count == 1)
        #expect(active.records.first?.id == replacement.id)
        #expect(active.records.first?.status == .active)
        #expect(active.records.first?.producerType == .rule)
        #expect(active.records.first?.producerVersion == "rule-fixture-v2")
        #expect(history.records.map(\.id) == [replacement.id, prior.id])
        #expect(history.records.first?.supersedes == [prior.id])
        #expect(history.records.last?.status == .superseded)
        #expect(history.records.last?.supersededBy == replacement.id)
    }

    @Test
    func duplicatePublishFailureKeepsPriorActiveInferenceAndPublishesNoPartialState() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let active = Self.semanticRecord(id: "semantic-1")
        let duplicate = Self.semanticRecord(
            id: active.id,
            producerVersion: "duplicate-should-fail",
            supersedes: [active.id]
        )

        _ = try await repository.publishSemanticInference(ProvenanceSemanticInferencePublishRequest(record: active))
        do {
            _ = try await repository.publishSemanticInference(ProvenanceSemanticInferencePublishRequest(record: duplicate))
            Issue.record("Expected duplicate semantic inference ID failure")
        } catch let error as ProvenanceSQLiteError {
            if case let .sqlite(message) = error {
                #expect(message.contains("UNIQUE") || message.contains("unique"))
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let activeAfterFailure = try await repository.semanticInferences(
            ProvenanceSemanticInferenceQueryRequest(
                scope: .session,
                scopeID: "session-1",
                kind: Self.fixtureKind,
                includeInactive: true
            )
        )
        #expect(activeAfterFailure.records == [active])
    }

    @Test
    func missingSupersededInferenceFailureRollsBackReplacement() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let active = Self.semanticRecord(id: "semantic-1")
        let replacement = Self.semanticRecord(
            id: "semantic-2",
            producerVersion: "replacement-should-rollback",
            supersedes: ["semantic-missing"]
        )

        _ = try await repository.publishSemanticInference(ProvenanceSemanticInferencePublishRequest(record: active))
        do {
            _ = try await repository.publishSemanticInference(ProvenanceSemanticInferencePublishRequest(record: replacement))
            Issue.record("Expected missing superseded inference failure")
        } catch let error as ProvenanceSQLiteError {
            if case let .sqlite(message) = error {
                #expect(message.contains("cannot be superseded"))
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let history = try await repository.semanticInferences(
            ProvenanceSemanticInferenceQueryRequest(
                scope: .session,
                scopeID: "session-1",
                kind: Self.fixtureKind,
                includeInactive: true
            )
        )
        #expect(history.records == [active])
    }

    @Test
    func invalidationAndCoalescingMapRelevantEvidenceToOnePass() throws {
        let promptRef = ProvenanceSemanticEvidenceReference(kind: "coding_agent_prompt", id: "prompt-1")
        let commandRef = ProvenanceSemanticEvidenceReference(kind: "coding_agent_command", id: "command-1")
        let ignoredRef = ProvenanceSemanticEvidenceReference(kind: "workspace_display", id: "workspace-1")
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let rules = [
            ProvenanceSemanticInferenceInvalidationRule(
                inferenceKind: Self.fixtureKind,
                dirtyOn: [
                    .promptSubmitted,
                    .planUpdated,
                    .visibleReasoningSummaryCompleted,
                    .meaningfulCommandCompleted,
                    .fileChangeActivity,
                    .validationResultRecorded,
                    .lifecycleChanged,
                ]
            ),
            ProvenanceSemanticInferenceInvalidationRule(
                inferenceKind: "fixture.semantic.validation_state",
                dirtyOn: [.validationResultRecorded]
            ),
        ]
        let changes = [
            ProvenanceSemanticInferenceEvidenceChange(
                kind: .irrelevant,
                scope: .session,
                scopeID: "session-1",
                evidenceRef: ignoredRef,
                observedAt: timestamp
            ),
            ProvenanceSemanticInferenceEvidenceChange(
                kind: .promptSubmitted,
                scope: .session,
                scopeID: "session-1",
                evidenceRef: promptRef,
                observedAt: timestamp.addingTimeInterval(1)
            ),
            ProvenanceSemanticInferenceEvidenceChange(
                kind: .meaningfulCommandCompleted,
                scope: .session,
                scopeID: "session-1",
                evidenceRef: commandRef,
                observedAt: timestamp.addingTimeInterval(2)
            ),
        ]

        let irrelevantOnly = ProvenanceSemanticInferenceInvalidationPolicy.coalescedPass(
            scope: .session,
            scopeID: "session-1",
            changes: [changes[0]],
            rules: rules
        )
        let pass = try #require(ProvenanceSemanticInferenceInvalidationPolicy.coalescedPass(
            scope: .session,
            scopeID: "session-1",
            changes: changes,
            rules: rules
        ))

        #expect(irrelevantOnly == nil)
        #expect(pass.dirtyInferenceKinds == [Self.fixtureKind])
        #expect(pass.triggeringChangeKinds == [.promptSubmitted, .meaningfulCommandCompleted])
        #expect(pass.triggeringEvidenceRefs == [promptRef, commandRef])
    }

    @Test
    func semanticInferenceStorageStaysSeparateFromDeterministicCurrentState() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let session = ProvenanceSessionRecord(
            id: "session-1",
            agentKind: "codex",
            status: "active",
            startedAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
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
        let record = Self.semanticRecord(id: "semantic-1")

        try await repository.appendEvent(event)
        let factualBeforeSemantic = try await repository.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: session.id)
        )
        _ = try await repository.publishSemanticInference(ProvenanceSemanticInferencePublishRequest(record: record))
        let factualAfterSemantic = try await repository.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: session.id)
        )

        #expect(factualAfterSemantic == factualBeforeSemantic)
        #expect(try await repository.rebuildProjectionsFromEventLedger(batchSize: 1) == 1)
        #expect(try await repository.factualSessionProjection(
            ProvenanceFactualSessionProjectionRequest(sessionID: session.id)
        ) == factualBeforeSemantic)
        #expect(try await repository.semanticInferences(
            ProvenanceSemanticInferenceQueryRequest(scope: .session, scopeID: session.id, kind: Self.fixtureKind)
        ).records == [record])
        #expect(try await repository.validateProjectionKeys(limit: 10).mismatches.isEmpty)
    }

    private static let fixtureKind = "fixture.semantic.framework_claim"

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
        producerType: ProvenanceSemanticInferenceProducerType = .model,
        producerVersion: String = "model-fixture-v1",
        confidence: ProvenanceConfidence = .medium,
        specificity: ProvenanceSemanticSpecificity = .granular,
        supersedes: [String] = []
    ) -> ProvenanceSemanticInferenceRecord {
        ProvenanceSemanticInferenceRecord(
            id: id,
            kind: fixtureKind,
            scope: .session,
            scopeID: "session-1",
            payload: .object([
                "claim": .string("bounded fixture claim"),
                "attributes": .object([
                    "source": .string("test fixture"),
                    "granularity": .string("single claim"),
                ]),
            ]),
            supportingEvidenceRefs: supportingEvidenceRefs,
            supportingFactualRevision: 7,
            confidence: confidence,
            specificity: specificity,
            producerType: producerType,
            producerID: "semantic-fixture-worker",
            producerVersion: producerVersion,
            createdAt: Date(timeIntervalSince1970: id == "semantic-1" ? 1_800_000_100 : 1_800_000_200),
            supersedes: supersedes
        )
    }

    private static func temporaryDatabaseURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-semantic-inference-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return directory.appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

@Suite
struct RelatedSessionWorkStateSemanticTests {
    @Test
    func semanticReplacementRevisesBriefWithoutChangingFactualWatermark() async throws {
        typealias Support = RelatedSessionWorkStateSemanticTestSupport
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let seeded = try await Support.seedWorkStateSessions(into: repository)
        let request = ProvenanceRelatedSessionRequest(targetSessionID: seeded.target.session.id, limit: 10)
        let before = try Support.require(try await repository.relatedSessions(request).projection)
        let beforeBrief = try Support.require(before.relatedSessions.first { $0.sessionID == seeded.open.session.id })
        let beforeRecord = try Support.require(Support.semanticField(.blockers, in: beforeBrief).record)
        let replacement = Support.partialBlockerRecord(
            id: "semantic-partial-blocker-session-open",
            sessionID: seeded.open.session.id,
            evidenceID: seeded.openEvidenceID,
            factualRevision: beforeRecord.supportingFactualRevision,
            createdAt: seeded.fixture.time(90),
            supersedes: [beforeRecord.inferenceID]
        )

        _ = try await repository.publishSemanticInference(ProvenanceSemanticInferencePublishRequest(record: replacement))
        let after = try Support.require(try await repository.relatedSessions(request).projection)
        let afterBrief = try Support.require(after.relatedSessions.first { $0.sessionID == seeded.open.session.id })
        let afterField = try Support.semanticField(.blockers, in: afterBrief)
        let historical = try Support.require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(
                targetSessionID: seeded.target.session.id,
                limit: 10,
                revisionID: before.projection.revisionID
            )
        ).projection)
        let historicalBrief = try Support.require(historical.relatedSessions.first {
            $0.sessionID == seeded.open.session.id
        })

        #expect(after.projection.revisionID != before.projection.revisionID)
        #expect(after.projection.sourceEvidenceWatermark == before.projection.sourceEvidenceWatermark)
        #expect(afterField.record?.inferenceID == replacement.id)
        #expect(afterField.record?.supersedes == [beforeRecord.inferenceID])
        #expect(afterField.record?.supportingFactualRevision == beforeRecord.supportingFactualRevision)
        #expect(Support.availability(.blockers, in: afterBrief)?.status == "partial")
        #expect(Support.availability(.blockers, in: afterBrief)?.reason == "partial_source_history")
        #expect(try Support.semanticField(.blockers, in: historicalBrief).record?.inferenceID == beforeRecord.inferenceID)

        let reopened = try ProvenanceSQLiteRepository(url: url)
        #expect(try Support.require(try await reopened.relatedSessions(request).projection) == after)
        _ = try await reopened.rebuildProjectionsFromEventLedger(batchSize: 2)
        #expect(try Support.require(try await reopened.relatedSessions(request).projection) == after)
    }

    @Test
    func unknownAndBoundedSemanticFieldsRemainExplicit() async throws {
        typealias Support = RelatedSessionWorkStateSemanticTestSupport
        let url = RelatedSessionProjectionTestSupport.temporaryDatabaseURL()
        defer { RelatedSessionProjectionTestSupport.removeTemporaryDatabaseDirectory(for: url) }
        let repository = try ProvenanceSQLiteRepository(url: url)
        let fixture = RelatedSessionFixture()
        let repo = fixture.repository()
        let worktree = fixture.worktree(
            id: "worktree-bounds",
            repository: repo,
            path: "/repos/bounds",
            branch: "bounds",
            head: "bounds-head",
            offset: 1
        )
        let target = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-target",
            status: "active",
            worktree: worktree,
            repository: repo,
            fixture: fixture,
            into: repository
        )
        let related = try await RelatedSessionProjectionTestSupport.seedSession(
            id: "session-related",
            status: "completed",
            worktree: worktree,
            repository: repo,
            fixture: fixture,
            into: repository
        )

        let unknownBrief = try Support.require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id)
        ).projection?.relatedSessions.first)
        #expect(try Support.semanticField(.blockers, in: unknownBrief).state == .unknown)
        #expect(try Support.semanticField(.approachChanges, in: unknownBrief).state == .unknown)
        #expect(Support.availability(.blockers, in: unknownBrief)?.status == "unknown")

        _ = try await Support.publishSemantics(sessionID: related.session.id, offset: 30, fixture: fixture, into: repository)
        let knownUnknownBrief = try Support.require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id)
        ).projection?.relatedSessions.first)
        let knownUnknownBlockerField = try Support.semanticField(.blockers, in: knownUnknownBrief)
        let knownUnknownApproachField = try Support.semanticField(.approachChanges, in: knownUnknownBrief)
        #expect(knownUnknownBlockerField.state == .known)
        #expect(knownUnknownApproachField.state == .known)
        #expect(try Support.blockerPayload(from: knownUnknownBrief).unknownReason != nil)
        #expect(try Support.approachPayload(from: knownUnknownBrief).unknownReason != nil)
        #expect(Support.availability(.blockers, in: knownUnknownBrief)?.status == "unknown")
        #expect(Support.availability(.blockers, in: knownUnknownBrief)?.reason == "source_semantic_unknown")
        #expect(Support.availability(.approachChanges, in: knownUnknownBrief)?.status == "unknown")

        try await fixture.appendPlan(
            Support.largePlan(
                sessionID: related.session.id,
                threadID: related.thread.id,
                turnID: related.turn.id,
                observedAt: fixture.time(40)
            ),
            into: repository
        )
        _ = try await Support.appendAssistantMessage(
            Support.semanticStatementBatch(0..<12),
            id: "assistant-bounded-semantics",
            sessionID: related.session.id,
            threadID: related.thread.id,
            turnID: related.turn.id,
            offset: 41,
            fixture: fixture,
            into: repository
        )
        _ = try await Support.publishSemantics(sessionID: related.session.id, offset: 60, fixture: fixture, into: repository)
        let boundedBrief = try Support.require(try await repository.relatedSessions(
            ProvenanceRelatedSessionRequest(targetSessionID: target.session.id)
        ).projection?.relatedSessions.first)
        let milestones = try Support.milestonePayload(from: boundedBrief)
        let blockers = try Support.blockerPayload(from: boundedBrief)
        let approaches = try Support.approachPayload(from: boundedBrief)

        #expect(milestones.milestones.count == 10)
        #expect(blockers.blockers.count == 10)
        #expect(approaches.approachChanges.count == 10)
        #expect(milestones.currentMilestoneID == milestones.milestones.last?.id)
        #expect(blockers.omissionReasons.contains("related_session_semantic_payload_omitted:blockers:2"))
        #expect(approaches.omissionReasons.contains("related_session_semantic_payload_omitted:approach_changes:2"))
        #expect(Support.availability(.blockers, in: boundedBrief)?.status == "partial")
        #expect(Support.availability(.approachChanges, in: boundedBrief)?.reason == "bounded_semantic_payload")
    }
}
