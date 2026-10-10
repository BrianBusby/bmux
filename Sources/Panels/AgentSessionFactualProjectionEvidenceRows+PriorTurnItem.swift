import ProvenanceEngineContracts

extension AgentSessionFactualProjectionEvidenceRows {
    enum PriorTurnItem: Equatable {
        case detail(ProvenanceFactualSessionProjectionTurnSnapshot)
        case reference(ProvenanceFactualSessionProjectionTurnReference)

        var id: String {
            switch self {
            case .detail(let turnSnapshot):
                turnSnapshot.turn.id
            case .reference(let turn):
                turn.turnID
            }
        }
    }
}
