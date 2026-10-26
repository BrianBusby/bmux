/// Payload estimates or results for one bounded outcome-retention pass.
struct ProvenanceOutcomePruneReport: Equatable, Sendable {
    let policyVersion: Int
    let candidateRows: Int
    let candidateBytes: Int64
    let prunedRows: Int
}
