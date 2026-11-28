import Foundation

extension ProvenanceFactualSessionProjectionSnapshot {
    /// Whether a derived claim can be tied entirely to visible turn evidence while ownership is disputed.
    public func permitsSemanticEvidence(_ refs: [ProvenanceSemanticEvidenceReference]) -> Bool {
        guard let unresolvedTurnIDs, !unresolvedTurnIDs.isEmpty else { return true }
        var evidence: [String: Set<String>] = [:]
        let visibleTurns = turns + (latestTurn.map { [$0] } ?? [])
        func include(_ kind: String, _ ids: [String]) {
            evidence[kind, default: []].formUnion(ids)
        }
        for snapshot in visibleTurns {
            include("coding_agent_turn", [snapshot.turn.id])
            include("coding_agent_prompt", snapshot.submittedPrompt.map { [$0.id] } ?? [])
            include("coding_agent_plan_update", snapshot.currentPlan.map { [$0.id] } ?? [])
            include("coding_agent_command", snapshot.completedCommands.map(\.id))
            include("coding_agent_reasoning_summary", snapshot.visibleReasoningSummaries.map(\.id))
            include("coding_agent_assistant_message", snapshot.assistantMessages.map(\.id))
            include("coding_agent_file_change_attribution", snapshot.fileChangeAttributions.map(\.id))
        }
        var hasVisibleTurnEvidence = false
        for ref in refs {
            if ref.kind == "factual_session_projection", ref.id == session.id { continue }
            if ref.kind == "coding_agent_thread", providerThreads.contains(where: { $0.id == ref.id }) { continue }
            guard evidence[ref.kind]?.contains(ref.id) == true else { return false }
            hasVisibleTurnEvidence = true
        }
        return hasVisibleTurnEvidence
    }
}
