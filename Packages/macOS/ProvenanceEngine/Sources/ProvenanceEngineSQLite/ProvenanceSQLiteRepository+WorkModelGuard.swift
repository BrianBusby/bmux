import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    // This guards only the supplied model. It is not a semantic publication API:
    // a publisher must also validate every predecessor and all of its other inputs.
    func withMatchingWorkModel(_ request: ProvenanceSessionWorkModelRequest,
                               expected: ProvenanceSessionWorkModelResponse,
                               operation: () throws -> Void) throws -> Bool {
        guard expected.found, expected.model != nil, expected.sessionID == request.sessionID else { return false }
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            guard try sessionWorkModelSnapshot(request) == expected else {
                try database.execute("COMMIT")
                return false
            }
            try operation()
            try database.execute("COMMIT")
            return true
        } catch {
            let original = error
            try database.execute("ROLLBACK")
            throw original
        }
    }
}
