import Foundation

struct CLIProvenanceSessionTree: Equatable {
    let rootSessionID: String
    let found: Bool
    let reason: String?
    let sessions: [[String: AnyHashable]]
    let relationships: [[String: AnyHashable]]
    let externalIdentities: [[String: AnyHashable]]

    var payload: [String: Any] {
        [
            "found": found,
            "reason": reason ?? NSNull(),
            "root_session_id": rootSessionID,
            "summary": [
                "session_count": sessions.count,
                "relationship_count": relationships.count,
                "external_identity_count": externalIdentities.count,
                "max_depth": sessions.compactMap { $0["tree_depth"] as? Int }.max() ?? 0
            ],
            "sessions": arrayPayload(sessions),
            "relationships": arrayPayload(relationships),
            "external_identities": arrayPayload(externalIdentities)
        ]
    }

    private func arrayPayload(_ values: [[String: AnyHashable]]) -> [[String: Any]] {
        values.map(dictionaryPayload)
    }

    private func dictionaryPayload(_ value: [String: AnyHashable]) -> [String: Any] {
        value.reduce(into: [String: Any]()) { partial, item in
            partial[item.key] = item.value
        }
    }
}
