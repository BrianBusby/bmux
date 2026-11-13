import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    // Internal transaction seam; this does not itself validate inference predecessors.
    func withMatchingWorkModel(_ request: ProvenanceSessionWorkModelRequest,
                               expected: ProvenanceSessionWorkModelResponse,
                               operation: () throws -> Void) throws -> Bool {
        false
    }
}
