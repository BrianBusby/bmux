import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    /// The built-in producer's activity and phase are historical inferences unless
    /// their turn is still current; a completed command is never live activity.
    static func permitsCurrentInterpretation(
        _ record: ProvenanceSemanticInferenceRecord,
        latestTurn: ProvenanceFactualSessionProjectionTurnSnapshot?
    ) -> Bool {
        let activity = ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue
        let phase = ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue
        guard record.producerID == ProvenanceCodingAgentSessionSemanticInferenceProducer.producerID,
              record.kind == activity || record.kind == phase else { return true }
        guard let turn = latestTurn?.turn,
              ["started", "running", "in_progress", "blocked"].contains(turn.status.lowercased()),
              record.supportingEvidenceRefs.contains(where: { $0.kind == "coding_agent_turn" && $0.id == turn.id }) else {
            return false
        }
        if record.kind == activity {
            guard let payload = ProvenanceCodingAgentCurrentActivityPayload(semanticPayloadValue: record.payload) else {
                return false
            }
            return payload.basis != "completed_command" && payload.basis != "failed_command"
        }
        guard let payload = ProvenanceCodingAgentSessionPhasePayload(semanticPayloadValue: record.payload) else {
            return false
        }
        return !payload.signals.contains("completed_command") && !payload.signals.contains("failed_command")
    }
}
