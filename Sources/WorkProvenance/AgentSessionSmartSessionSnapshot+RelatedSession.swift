import ProvenanceEngineContracts

extension AgentSessionSmartSessionSnapshot {
    struct RelatedSession: Equatable, Sendable {
        let sessionID: String
        let lifecycleState: String
        let completionState: String
        let relationshipReasons: [String]
        let freshnessState: String

        init(_ brief: ProvenanceRelatedSessionBrief) {
            sessionID = brief.sessionID
            lifecycleState = brief.lifecycleState
            completionState = brief.completionState
            relationshipReasons = brief.relationshipReasons.map { $0.kind.rawValue }
            freshnessState = brief.freshness.state
        }

        var bridgePayload: [String: Any] {
            [
                "sessionId": sessionID,
                "lifecycleState": lifecycleState,
                "completionState": completionState,
                "relationshipReasons": relationshipReasons,
                "freshnessState": freshnessState
            ]
        }
    }
}
