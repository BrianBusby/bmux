import Foundation
import ProvenanceEngineContracts
@testable import ProvenanceEngineSQLite
import Testing

/// Test-only exploration over supplied synthetic events. It neither reads nor
/// writes PE state and does not establish source continuity or ownership.
@Suite struct ChildClaimExperimentTests {
    private struct Experiment {
        enum Outcome: Equatable { case unresolved, conflicting, incomplete }
        struct Claim: Equatable {
            let eventID: String
            let kind: String
            let recordID: String
            let envelopeSessionID: String?
            let sessionID: String
            let threadID: String?
            let turnID: String?
            let provider: String
        }
        struct Result {
            let outcome: Outcome
            let claims: [Claim]
            let sourceEventIDs: [String]
            let evidenceTruncated: Bool
            let conflictingTurnIDs: [String]
            let conflictingEnvelopeEventIDs: [String]
        }

        /// Even an internally consistent sample remains unresolved: the caller
        /// has not proven upstream identity, retained-history completeness, or
        /// that an older writer cannot bypass the sample.
        func examine(_ events: [ProvenanceEvent], maxEvents: Int = 64, maxIdentifierBytes: Int = 256) -> Result {
            guard maxEvents > 0, maxIdentifierBytes > 0, events.count <= maxEvents else {
                return Result(outcome: .incomplete, claims: [], sourceEventIDs: [], evidenceTruncated: true, conflictingTurnIDs: [], conflictingEnvelopeEventIDs: [])
            }
            var claims: [Claim] = []
            var seen: Set<String> = []
            var sourceEventIDs: [String] = []
            var incomplete = false
            for event in events {
                guard !event.id.isEmpty, event.id.utf8.count <= maxIdentifierBytes else {
                    return Result(outcome: .incomplete, claims: [], sourceEventIDs: [], evidenceTruncated: true, conflictingTurnIDs: [], conflictingEnvelopeEventIDs: [])
                }
                sourceEventIDs.append(event.id)
                if !seen.insert(event.id).inserted { incomplete = true }
                guard event.schemaVersion == 1 else { incomplete = true; continue }
                let payload = event.payload
                var eventClaims: [Claim] = []
                func add(_ kind: String, _ type: ProvenanceEventType, _ id: String, _ session: String, _ thread: String?, _ turn: String?, _ provider: String) {
                    if event.eventType != type { incomplete = true }
                    eventClaims.append(Claim(eventID: event.id, kind: kind, recordID: id,
                        envelopeSessionID: event.sessionID, sessionID: session, threadID: thread,
                        turnID: turn, provider: provider))
                }
                if let value = payload.codingAgentTurn { add("turn", .codingAgentTurnObserved, value.id, value.sessionID, value.threadID, value.id, value.provider) }
                if let value = payload.codingAgentPrompt { add("prompt", .codingAgentPromptSubmitted, value.id, value.sessionID, value.threadID, value.turnID, value.provider) }
                if let value = payload.codingAgentPlanUpdate { add("plan", .codingAgentPlanUpdated, value.id, value.sessionID, value.threadID, value.turnID, value.provider) }
                if let value = payload.codingAgentCommand { add("command", .codingAgentCommandCompleted, value.id, value.sessionID, value.threadID, value.turnID, value.provider) }
                if let value = payload.codingAgentReasoningSummary { add("summary", .codingAgentReasoningSummaryCompleted, value.id, value.sessionID, value.threadID, value.turnID, value.provider) }
                if let value = payload.codingAgentAssistantMessage { add("message", .codingAgentAssistantMessageCompleted, value.id, value.sessionID, value.threadID, value.turnID, value.provider) }
                if let value = payload.codingAgentFileChangeAttribution { add("file", .codingAgentFileChangeAttributed, value.id, value.sessionID, value.threadID, value.turnID, value.provider) }
                if eventClaims.isEmpty { incomplete = true }
                guard eventClaims.allSatisfy({ claim in
                    [claim.eventID, claim.kind, claim.recordID, claim.envelopeSessionID, claim.sessionID,
                     claim.threadID, claim.turnID, claim.provider].compactMap { $0 }
                        .allSatisfy { $0.utf8.count <= maxIdentifierBytes }
                }) else { return Result(outcome: .incomplete, claims: [], sourceEventIDs: [], evidenceTruncated: true, conflictingTurnIDs: [], conflictingEnvelopeEventIDs: []) }
                claims.append(contentsOf: eventClaims)
            }
            let mismatch = claims.filter { claim in
                guard let envelope = claim.envelopeSessionID, !envelope.isEmpty, !claim.sessionID.isEmpty else { return false }
                return envelope != claim.sessionID
            }.map(\.eventID)
            var conflictingTurns: Set<String> = []
            for left in claims {
                guard let turn = left.turnID, !turn.isEmpty, !left.sessionID.isEmpty else { continue }
                for right in claims where right.turnID == turn && !right.sessionID.isEmpty {
                    if left.sessionID != right.sessionID ||
                        (!left.provider.isEmpty && !right.provider.isEmpty && left.provider != right.provider) ||
                        (left.threadID.flatMap { $0.isEmpty ? nil : $0 } != nil &&
                         right.threadID.flatMap { $0.isEmpty ? nil : $0 } != nil && left.threadID != right.threadID) {
                        conflictingTurns.insert(turn)
                    }
                }
            }
            return Result(outcome: incomplete ? .incomplete : !mismatch.isEmpty || !conflictingTurns.isEmpty ? .conflicting : .unresolved,
                          claims: claims.sorted { ($0.eventID, $0.kind, $0.recordID) < ($1.eventID, $1.kind, $1.recordID) },
                          sourceEventIDs: sourceEventIDs.sorted(), evidenceTruncated: false,
                          conflictingTurnIDs: conflictingTurns.sorted(), conflictingEnvelopeEventIDs: Array(Set(mismatch)).sorted())
        }
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func event(_ id: String, session: String?, schema: Int = 1, type: ProvenanceEventType = .codingAgentPromptSubmitted, payload: ProvenanceEventPayload) -> ProvenanceEvent {
        ProvenanceEvent(id: id, schemaVersion: schema, eventType: type,
                        timestamp: now, sessionID: session, source: .observed, confidence: .high, payload: payload)
    }
    private func prompt(_ id: String, session: String, turn: String?, thread: String? = nil, provider: String = "codex") -> ProvenanceCodingAgentPromptRecord {
        ProvenanceCodingAgentPromptRecord(id: id, sessionID: session, threadID: thread, turnID: turn,
            provider: provider, text: "Synthetic prompt", submittedAt: now, source: .declared, confidence: .high)
    }
    private func turn(_ id: String, session: String, thread: String? = nil) -> ProvenanceCodingAgentTurnRecord {
        ProvenanceCodingAgentTurnRecord(id: id, sessionID: session, threadID: thread, provider: "codex",
            providerTurnID: "provider-\(id)", status: "started", updatedAt: now, source: .observed, confidence: .high)
    }

    @Test func childOnlyConflictKeepsBothReferencesAndNeverClaimsOwnership() {
        let a = event("turn-a", session: "A", type: .codingAgentTurnObserved, payload: .init(codingAgentTurn: turn("shared", session: "A")))
        let b = event("child-b", session: "B", payload: .init(codingAgentPrompt: prompt("b", session: "B", turn: "shared")))
        let c = event("child-c", session: "C", payload: .init(codingAgentPrompt: prompt("c", session: "C", turn: "other")))
        let result = Experiment().examine([a, b, c])
        #expect(result.outcome == .conflicting)
        #expect(result.claims.map(\.eventID) == ["child-b", "child-c", "turn-a"])
        #expect(result.claims.first?.sessionID == "B")
        #expect(result.claims.first?.turnID == "shared")
        #expect(result.conflictingTurnIDs == ["shared"])
        #expect(!result.conflictingTurnIDs.contains("other"))
        #expect(Experiment().examine([c]).outcome == .unresolved)
        #expect(Experiment().examine([c, b, a]).claims == result.claims)
    }

    @Test func allSupportedChildKindsRetainTheirOwnEvidenceReferences() {
        let events = [
            event("prompt-event", session: "B", payload: .init(codingAgentPrompt: prompt("p", session: "B", turn: "shared"))),
            event("plan-event", session: "B", type: .codingAgentPlanUpdated, payload: .init(codingAgentPlanUpdate: .init(id: "plan", sessionID: "B", turnID: "shared", provider: "codex", steps: [], observedAt: now, source: .declared, confidence: .high))),
            event("command-event", session: "B", type: .codingAgentCommandCompleted, payload: .init(codingAgentCommand: .init(id: "command", sessionID: "B", turnID: "shared", provider: "codex", command: "echo synthetic", status: "completed", completedAt: now, source: .observed, confidence: .high))),
            event("summary-event", session: "B", type: .codingAgentReasoningSummaryCompleted, payload: .init(codingAgentReasoningSummary: .init(id: "summary", sessionID: "B", turnID: "shared", provider: "codex", text: "Synthetic update", completedAt: now, source: .observed, confidence: .high))),
            event("message-event", session: "B", type: .codingAgentAssistantMessageCompleted, payload: .init(codingAgentAssistantMessage: .init(id: "message", sessionID: "B", turnID: "shared", provider: "codex", text: "Synthetic message", completedAt: now, source: .observed, confidence: .high))),
            event("file-event", session: "B", type: .codingAgentFileChangeAttributed, payload: .init(codingAgentFileChangeAttribution: .init(id: "file", sessionID: "B", turnID: "shared", provider: "codex", observedAt: now, source: .observed, confidence: .high)))
        ]
        let result = Experiment().examine(events)
        #expect(result.outcome == .unresolved)
        #expect(Set(result.claims.map(\.kind)) == Set(["prompt", "plan", "command", "summary", "message", "file"]))
        #expect(Set(result.claims.map(\.eventID)) == Set(events.map(\.id)))
        #expect(result.claims.allSatisfy { $0.turnID == "shared" })
        let owner = event("turn-a", session: "A", type: .codingAgentTurnObserved,
                          payload: .init(codingAgentTurn: turn("shared", session: "A")))
        for child in events {
            let conflict = Experiment().examine([owner, child])
            #expect(conflict.outcome == .conflicting)
            #expect(conflict.conflictingTurnIDs == ["shared"])
            #expect(Set(conflict.sourceEventIDs) == Set([owner.id, child.id]))
        }
    }

    @Test func ambiguousAndContradictoryInputsStayVisibleAsClaims() {
        let absent = event("missing-turn", session: nil, payload: .init(codingAgentPrompt: prompt("p", session: "B", turn: nil)))
        let mismatch = event("mismatch", session: "A", payload: .init(codingAgentPrompt: prompt("p2", session: "B", turn: nil)))
        let missing = Experiment().examine([absent])
        #expect(missing.outcome == .unresolved)
        #expect(missing.claims.first?.turnID == nil)
        #expect(missing.claims.first?.envelopeSessionID == nil)
        let missingOwner = event("missing-owner", session: nil, payload: .init(codingAgentPrompt: prompt("p", session: "", turn: "T")))
        let missingOwnerResult = Experiment().examine([missingOwner])
        #expect(missingOwnerResult.outcome == .unresolved)
        #expect(missingOwnerResult.claims.first?.sessionID == "")
        #expect(missingOwnerResult.sourceEventIDs == ["missing-owner"])
        #expect(Experiment().examine([mismatch]).outcome == .conflicting)
        #expect(Experiment().examine([mismatch]).conflictingEnvelopeEventIDs == ["mismatch"])
        let a = event("a", session: "A", type: .codingAgentTurnObserved, payload: .init(codingAgentTurn: turn("T", session: "A", thread: "one")))
        let b = event("b", session: "A", payload: .init(codingAgentPrompt: prompt("p", session: "A", turn: "T", thread: "two")))
        let c = event("c", session: "A", payload: .init(codingAgentPrompt: prompt("p3", session: "A", turn: "T", provider: "other")))
        #expect(Experiment().examine([a, b]).outcome == .conflicting)
        #expect(Experiment().examine([a, c]).outcome == .conflicting)
    }

    @Test func syntheticRetainedEventsRemainInspectableAcrossSecondConnectionAndRebuild() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("fixture.sqlite")
        let repository = try ProvenanceSQLiteRepository(url: url)
        let a = event("turn-a", session: "A", type: .codingAgentTurnObserved, payload: .init(codingAgentTurn: turn("shared", session: "A")))
        let b = event("child-b", session: "B", payload: .init(codingAgentPrompt: prompt("b", session: "B", turn: "shared")))
        try await repository.appendEvent(a)
        try await repository.appendEvent(b)
        let secondConnection = try ProvenanceSQLiteRepository(url: url)
        let firstRead = try await secondConnection.eventLedgerEntries(limit: 10).map(\.event)
        #expect(firstRead == [a, b])
        #expect(Experiment().examine(firstRead).outcome == .conflicting)
        _ = try await secondConnection.rebuildProjectionsFromEventLedger(batchSize: 1)
        let replayRead = try await secondConnection.eventLedgerEntries(limit: 10).map(\.event)
        #expect(replayRead == firstRead)
        #expect(Experiment().examine(replayRead).claims == Experiment().examine(firstRead).claims)
        // The original connection remains alive; this is not process restart.
    }

    @Test func incompleteCoverageNeverProducesCleanClaims() {
        let a = event("same", session: "A", payload: .init(codingAgentPrompt: prompt("p", session: "A", turn: "T")))
        let b = event("same", session: "B", payload: .init(codingAgentPrompt: prompt("p", session: "B", turn: "T")))
        let duplicate = Experiment().examine([a, b])
        #expect(duplicate.outcome == .incomplete)
        #expect(duplicate.claims.map(\.sessionID) == ["A", "B"])
        #expect(duplicate.sourceEventIDs == ["same", "same"])
        #expect(!duplicate.evidenceTruncated)
        #expect(Experiment().examine([a, a]).outcome == .incomplete)
        let truncated = Experiment().examine([a], maxEvents: 0)
        #expect(truncated.outcome == .incomplete)
        #expect(truncated.evidenceTruncated)
        #expect(Experiment().examine(Array(repeating: a, count: 65)).evidenceTruncated)
        let oversized = event(String(repeating: "é", count: 129), session: "A", payload: .init(codingAgentPrompt: prompt("p", session: "A", turn: "T")))
        #expect(Experiment().examine([oversized]).evidenceTruncated)
        #expect(Experiment().examine([a], maxIdentifierBytes: 2).outcome == .incomplete)
        let future = Experiment().examine([event("future", session: "A", schema: 99, type: .codingAgentTurnObserved, payload: .init(codingAgentTurn: turn("T", session: "A")))])
        #expect(future.outcome == .incomplete)
        #expect(future.sourceEventIDs == ["future"])
        #expect(future.claims.isEmpty)
        #expect(Experiment().examine([event("wrong-type", session: "A", payload: .init(codingAgentTurn: turn("T", session: "A")))]).outcome == .incomplete)
        #expect(Experiment().examine([event("other", session: "A", payload: .init())]).outcome == .incomplete)
    }
}
