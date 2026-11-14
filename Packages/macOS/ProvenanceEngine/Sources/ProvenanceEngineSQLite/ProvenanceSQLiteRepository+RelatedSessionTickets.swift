import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    /// Workspace tickets describe current workspace metadata, not a historical session assignment.
    func relatedSessionCurrentTicketReason(
        _ ticket: String, candidate: RelatedSessionProfile, repositoryScope: Set<String>
    ) throws -> ProvenanceRelatedSessionRelationshipReason? {
        var workspaceIDs = Set([candidate.session.workspaceID].compactMap { $0 })
        let query = try database.prepare("""
            SELECT DISTINCT workspace_id FROM provenance_workspace_coding_agent_session_associations
            WHERE canonical_session_id = ? ORDER BY workspace_id
            """)
        defer { query.finalize() }
        try query.bind(candidate.session.id, at: 1)
        while try query.step() {
            if let workspaceID = query.string(at: 0) { workspaceIDs.insert(workspaceID) }
        }
        for workspaceID in workspaceIDs.sorted() {
            guard let display = try workspaceDisplay(.init(workspaceID: workspaceID)).display else { continue }
            guard let repositoryID = display.repositoryID else { continue }
            let displayRepositoryKeys = try artifactCollisionRepositoryKeys(
                repositoryID: repositoryID, repositoryPath: nil
            )
            guard !repositoryScope.isDisjoint(with: displayRepositoryKeys) else { continue }
            let idsMatch = display.ticketIDs.contains(ticket)
            let linksMatch = display.ticketLinks.contains { $0.id == ticket }
            guard idsMatch || linksMatch else { continue }
            let fields = (idsMatch ? ["ticket_ids"] : []) + (linksMatch ? ["ticket_links"] : [])
            let references = fields.compactMap { field -> ProvenanceRelatedSessionEvidenceReference? in
                guard let metadata = display.fieldMetadata[field], let eventID = metadata.evidenceEventID else { return nil }
                return .init(kind: "event", id: eventID, eventSequence: metadata.evidenceEventSequence,
                    field: "workspace_display:\(field)", sourceState: metadata.source.rawValue)
            }
            let displayReference = ProvenanceRelatedSessionEvidenceReference(
                kind: "workspace_display", id: display.id, eventSequence: display.latestEventSequence,
                field: "current_ticket", sourceState: "current_state_historical_validity_unknown"
            )
            let sessionReference = ProvenanceRelatedSessionEvidenceReference(
                kind: "session", id: candidate.session.id, field: "linked_workspace"
            )
            let observedAt = fields.compactMap { display.fieldMetadata[$0]?.observedAt }.max()
            return .init(kind: .currentWorkspaceTicket, targetValue: ticket, relatedValue: ticket,
                evidence: uniqueRelatedSessionEvidence(references + [displayReference, sessionReference]),
                observedAt: observedAt)
        }
        return nil
    }
}
