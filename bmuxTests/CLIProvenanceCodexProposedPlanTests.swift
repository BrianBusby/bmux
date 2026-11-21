import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct CLIProvenanceCodexProposedPlanTests {
    @Test
    func preservesProviderProposedPlanAsDistinctEvidenceAndReplays() async throws {
        let fixture = try CLIProvenanceCodexTranscriptImporterTests.StoreFixture()
        defer { fixture.remove() }
        let file = fixture.directoryURL.appendingPathComponent("proposal.jsonl")
        let text = "Investigate the index.\nValidate recovery."
        let lines = try [
            CLIProvenanceCodexTranscriptImporterTests.codexTranscriptLine(ordinal: 0, type: "session_meta", timestamp: "2026-11-13T13:21:13Z", payload: ["id": "session-1", "cwd": "/tmp"]),
            CLIProvenanceCodexTranscriptImporterTests.codexTranscriptLine(ordinal: 1, type: "event_msg", timestamp: "2026-11-13T13:21:20Z", payload: ["type": "task_started", "turn_id": "turn-1"]),
            CLIProvenanceCodexTranscriptImporterTests.codexTranscriptLine(ordinal: 2, type: "event_msg", timestamp: "2026-11-13T13:21:36Z", payload: ["type": "item_completed", "thread_id": "session-1", "turn_id": "turn-1", "completed_at_ms": 1_794_576_096_676, "item": ["type": "Plan", "id": "plan-1", "text": text]]),
            CLIProvenanceCodexTranscriptImporterTests.codexTranscriptLine(ordinal: 3, type: "event_msg", timestamp: "2026-11-13T13:21:36Z", payload: ["type": "item_completed", "thread_id": "session-1", "turn_id": "turn-1", "item": ["type": "Plan", "id": "plan-1", "text": text]]),
            CLIProvenanceCodexTranscriptImporterTests.codexTranscriptLine(ordinal: 4, type: "response_item", timestamp: "2026-11-13T13:21:36Z", payload: ["type": "message", "role": "assistant", "phase": "final_answer", "content": [["type": "output_text", "text": "<proposed_plan>\n" + text + "\n</proposed_plan>"]]]),
            CLIProvenanceCodexTranscriptImporterTests.codexTranscriptLine(ordinal: 5, type: "event_msg", timestamp: "2026-11-13T13:21:37Z", payload: ["type": "task_complete", "turn_id": "turn-1"]),
        ]
        try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
        let capture = CapturingProvenanceEngineClient()
        let importer = CLIProvenanceCodexTranscriptImporter(client: capture)
        _ = try await importer.importTranscripts(path: file.path)
        let events = await capture.appendedEventRequests.map(\.event)
        let proposals = events.filter { $0.eventType == .codingAgentProposedPlanObserved }
        #expect(proposals.count == 2)
        #expect(try #require(proposals.first).id == #require(proposals.last).id)
        let proposal = try #require(proposals.first?.payload.codingAgentProposedPlan)
        #expect(proposal.providerSessionID == "session-1")
        #expect(proposal.providerTurnID == "turn-1")
        #expect(proposal.providerItemID == "plan-1")
        #expect(proposal.text == text)
        #expect(!proposal.truncated)
        #expect(events.allSatisfy { $0.payload.codingAgentPlanUpdate == nil })
        let sqlite = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let replayImporter = CLIProvenanceCodexTranscriptImporter(client: sqlite)
        let first = try await replayImporter.importTranscripts(path: file.path)
        let second = try await replayImporter.importTranscripts(path: file.path)
        #expect(first.eventsAppended > 0)
        #expect(first.duplicateEvents == 1)
        #expect(second.eventsAppended == 0)
        #expect(second.duplicateEvents == first.eventsAppended + 1)
    }

    @Test
    func rejectsUnscopedAndForeignProposedPlans() async throws {
        let fixture = try CLIProvenanceCodexTranscriptImporterTests.StoreFixture()
        defer { fixture.remove() }
        let file = fixture.directoryURL.appendingPathComponent("foreign-proposal.jsonl")
        let lines = try [
            CLIProvenanceCodexTranscriptImporterTests.codexTranscriptLine(ordinal: 0, type: "session_meta", timestamp: "2026-11-13T13:21:13Z", payload: ["id": "session-1", "cwd": "/tmp"]),
            CLIProvenanceCodexTranscriptImporterTests.codexTranscriptLine(ordinal: 1, type: "event_msg", timestamp: "2026-11-13T13:21:36Z", payload: ["type": "item_completed", "thread_id": "other-session", "turn_id": "foreign-turn", "item": ["type": "Plan", "id": "plan-1", "text": "Foreign"]]),
            CLIProvenanceCodexTranscriptImporterTests.codexTranscriptLine(ordinal: 2, type: "event_msg", timestamp: "2026-11-13T13:21:36Z", payload: ["type": "item_completed", "thread_id": "session-1", "item": ["type": "Plan", "id": "plan-2", "text": "Missing turn"]]),
        ]
        try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
        let capture = CapturingProvenanceEngineClient()
        _ = try await CLIProvenanceCodexTranscriptImporter(client: capture).importTranscripts(path: file.path)
        let events = await capture.appendedEventRequests.map(\.event)
        #expect(events.allSatisfy { $0.eventType != .codingAgentProposedPlanObserved })
        #expect(events.allSatisfy { $0.payload.codingAgentTurn == nil })
    }

    @Test
    func conflictingAndTruncatedProposalsRemainDistinct() async throws {
        let fixture = try CLIProvenanceCodexTranscriptImporterTests.StoreFixture()
        defer { fixture.remove() }
        let file = fixture.directoryURL.appendingPathComponent("proposal-conflict.jsonl")
        let text = String(repeating: "x", count: 12_001)
        let lines = try [
            CLIProvenanceCodexTranscriptImporterTests.codexTranscriptLine(ordinal: 0, type: "session_meta", timestamp: "2026-11-13T13:21:13Z", payload: ["id": "session-1", "cwd": "/tmp"]),
            CLIProvenanceCodexTranscriptImporterTests.codexTranscriptLine(ordinal: 1, type: "event_msg", timestamp: "2026-11-13T13:21:36Z", payload: ["type": "item_completed", "thread_id": "session-1", "turn_id": "turn-1", "item": ["type": "Plan", "id": "plan-1", "text": text]]),
            CLIProvenanceCodexTranscriptImporterTests.codexTranscriptLine(ordinal: 2, type: "event_msg", timestamp: "2026-11-13T13:21:37Z", payload: ["type": "item_completed", "thread_id": "session-1", "turn_id": "turn-1", "item": ["type": "Plan", "id": "plan-1", "text": text + "y"]]),
        ]
        try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
        let capture = CapturingProvenanceEngineClient()
        _ = try await CLIProvenanceCodexTranscriptImporter(client: capture).importTranscripts(path: file.path)
        let events = await capture.appendedEventRequests.map(\.event).filter { $0.eventType == .codingAgentProposedPlanObserved }
        #expect(events.count == 2)
        let first = try #require(events.first)
        let last = try #require(events.last)
        #expect(first.id != last.id)
        #expect(first.payload.codingAgentProposedPlan?.truncated == true)
        #expect(first.payload.codingAgentProposedPlan?.text.count == 12_000)
        #expect(first.payload.codingAgentProposedPlan?.text == last.payload.codingAgentProposedPlan?.text)
    }

}
