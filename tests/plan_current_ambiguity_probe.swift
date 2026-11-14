import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK

@main
struct PlanCurrentAmbiguityProbe {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count == 4 || args.count == 5 else { throw NSError(domain: "probe", code: 1) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: URL(fileURLWithPath: args[1]))
        let request = ProvenanceFactualSessionProjectionRequest(sessionID: args[2])
        let snapshot = try await client.factualSessionProjection(request)
        guard let turn = snapshot.snapshot?.latestTurn?.turn else { throw NSError(domain: "missing-turn", code: 2) }
        if args[3] == "seed" {
            let timestamp = Date(timeIntervalSince1970: 1_767_225_601)
            let plan = ProvenanceCodingAgentPlanUpdateRecord(
                id: "structured-plan", sessionID: args[2], threadID: turn.threadID, turnID: turn.id,
                provider: "codex", steps: [.init(id: "structured-step", order: 0, text: "Original structured step", status: "in_progress")],
                observedAt: timestamp, source: .observed, confidence: .high
            )
            let event = ProvenanceEvent(
                id: "structured-plan-event", eventType: .codingAgentPlanUpdated, timestamp: timestamp,
                sessionID: args[2], source: .observed,
                evidenceOrigin: ProvenanceEvidenceOrigin(rawValue: "synthetic-structured-agent-plan"),
                confidence: .high, payload: ProvenanceEventPayload(codingAgentPlanUpdate: plan)
            )
            _ = try await client.appendEvent(ProvenanceAppendEventRequest(event: event))
        }
        let factual = try await client.factualSessionProjection(request)
        let revisionID = args.count == 5 ? args[4] : nil
        let outcome = try await client.turnOutcome(ProvenanceTurnOutcomeRequest(turnID: turn.id, revisionID: revisionID))
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .secondsSince1970
        struct Response: Encodable { let factual: ProvenanceFactualSessionProjectionResponse; let outcome: ProvenanceTurnOutcomeResponse }
        print(String(decoding: try encoder.encode(Response(factual: factual, outcome: outcome)), as: UTF8.self))
    }
}
