import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func appendLedgerIDCandidate(_ request: ProvenanceAppendEventRequest) async throws -> ProvenanceLedgerIDCandidateResult {
        try database.execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            guard try insertEvent(request.event, ignoreIDConflict: true) else {
                let query = try database.prepare("SELECT 1 FROM provenance_events WHERE id = ?")
                defer { query.finalize() }
                try query.bind(request.event.id, at: 1)
                guard try query.step() else {
                    throw ProvenanceSQLiteError.sqlite(message: "ledger insertion produced no row without an existing event ID")
                }
                try database.execute("COMMIT")
                return .idAlreadyPresent
            }
            try applyProjectionUpdates(from: request.event, latestEventSequence: eventSequence(id: request.event.id))
            try database.execute("COMMIT")
            return .inserted
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
    }

}
