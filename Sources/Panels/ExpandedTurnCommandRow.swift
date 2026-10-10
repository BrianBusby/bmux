import ProvenanceEngineContracts

struct ExpandedTurnCommandRow: Identifiable, Equatable {
    let record: ProvenanceCodingAgentCommandRecord
    let presentation: ExpandedTurnCommandPresentation
    var id: String { record.id }
}
