import Foundation
import ProvenanceEngineContracts

extension ProvenanceSQLiteRepository {
    func relatedSessionCandidateSessionIDs(excluding targetSessionID: String) throws -> [String] {
        let query = try database.prepare(
            """
            SELECT id
            FROM provenance_sessions
            WHERE id != ?
            ORDER BY updated_at_seconds DESC, id ASC
            """
        )
        defer { query.finalize() }
        try query.bind(targetSessionID, at: 1)
        var ids: [String] = []
        while try query.step() {
            if let id = query.string(at: 0) {
                ids.append(id)
            }
        }
        return ids
    }

    func relatedSessionTreeContext(
        targetSessionID: String
    ) throws -> RelatedSessionTreeContext {
        var ancestors: [String: RelatedSessionTreePath] = [:]
        var ancestorRelationships: [ProvenanceSessionRelationshipRecord] = []
        var currentSessionID = targetSessionID
        var visited = Set<String>([targetSessionID])

        while let relationship = try relatedSessionRelationship(sessionID: currentSessionID),
              !visited.contains(relationship.parentSessionID),
              ancestorRelationships.count < 50 {
            visited.insert(relationship.parentSessionID)
            ancestorRelationships.append(relationship)
            ancestors[relationship.parentSessionID] = RelatedSessionTreePath(
                depth: ancestorRelationships.count,
                relationships: ancestorRelationships
            )
            currentSessionID = relationship.parentSessionID
        }

        var descendants: [String: RelatedSessionTreePath] = [:]
        var queue = try relatedSessionChildRelationships(parentSessionID: targetSessionID).map {
            ($0, [$0])
        }
        var descendantVisited = Set<String>([targetSessionID])
        while !queue.isEmpty, descendants.count < 500 {
            let item = queue.removeFirst()
            let relationship = item.0
            let path = item.1
            guard !descendantVisited.contains(relationship.sessionID) else { continue }
            descendantVisited.insert(relationship.sessionID)
            descendants[relationship.sessionID] = RelatedSessionTreePath(
                depth: path.count,
                relationships: path
            )
            for child in try relatedSessionChildRelationships(parentSessionID: relationship.sessionID) {
                queue.append((child, path + [child]))
            }
        }

        var siblings: [String: RelatedSessionTreePath] = [:]
        if let targetRelationship = try relatedSessionRelationship(sessionID: targetSessionID) {
            for sibling in try relatedSessionChildRelationships(parentSessionID: targetRelationship.parentSessionID) {
                guard sibling.sessionID != targetSessionID else { continue }
                siblings[sibling.sessionID] = RelatedSessionTreePath(
                    depth: 1,
                    relationships: [targetRelationship, sibling]
                )
            }
        }
        return RelatedSessionTreeContext(
            ancestors: ancestors,
            descendants: descendants,
            siblings: siblings
        )
    }

    func relatedSessionRelationship(
        sessionID: String
    ) throws -> ProvenanceSessionRelationshipRecord? {
        let query = try database.prepare(
            """
            SELECT
                session_id,
                parent_session_id,
                root_session_id,
                inbound_delegation_id,
                depth,
                source,
                confidence,
                created_at_seconds,
                updated_at_seconds
            FROM provenance_session_relationships
            WHERE session_id = ?
            """
        )
        defer { query.finalize() }
        try query.bind(sessionID, at: 1)
        guard try query.step() else { return nil }
        return try relatedSessionRelationship(from: query)
    }

    func relatedSessionChildRelationships(
        parentSessionID: String
    ) throws -> [ProvenanceSessionRelationshipRecord] {
        let query = try database.prepare(
            """
            SELECT
                session_id,
                parent_session_id,
                root_session_id,
                inbound_delegation_id,
                depth,
                source,
                confidence,
                created_at_seconds,
                updated_at_seconds
            FROM provenance_session_relationships
            WHERE parent_session_id = ?
            ORDER BY depth ASC, updated_at_seconds ASC, session_id ASC
            """
        )
        defer { query.finalize() }
        try query.bind(parentSessionID, at: 1)
        var relationships: [ProvenanceSessionRelationshipRecord] = []
        while try query.step() {
            relationships.append(try relatedSessionRelationship(from: query))
        }
        return relationships
    }

    func relatedSessionRelationship(
        from query: ProvenanceSQLiteStatement
    ) throws -> ProvenanceSessionRelationshipRecord {
        guard let sessionID = query.string(at: 0),
              let parentSessionID = query.string(at: 1),
              let rootSessionID = query.string(at: 2),
              let sourceValue = query.string(at: 5),
              let source = ProvenanceSource(rawValue: sourceValue),
              let confidenceValue = query.string(at: 6),
              let confidence = ProvenanceConfidence(rawValue: confidenceValue) else {
            throw ProvenanceSQLiteError.sqlite(message: "invalid session relationship row")
        }
        return ProvenanceSessionRelationshipRecord(
            sessionID: sessionID,
            parentSessionID: parentSessionID,
            rootSessionID: rootSessionID,
            inboundDelegationID: query.string(at: 3),
            depth: query.int(at: 4),
            source: source,
            confidence: confidence,
            createdAt: Date(timeIntervalSince1970: query.double(at: 7) ?? 0),
            updatedAt: Date(timeIntervalSince1970: query.double(at: 8) ?? 0)
        )
    }
}
