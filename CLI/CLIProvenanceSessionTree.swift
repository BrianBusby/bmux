import Foundation

struct CLIProvenanceSessionTree: Equatable {
    let rootSessionID: String
    let found: Bool
    let reason: String?
    let sessions: [[String: AnyHashable]]
    let relationships: [[String: AnyHashable]]
    let externalIdentities: [[String: AnyHashable]]

    init(
        rootSessionID: String,
        found: Bool,
        reason: String?,
        sessions: [[String: AnyHashable]],
        relationships: [[String: AnyHashable]],
        externalIdentities: [[String: AnyHashable]]
    ) {
        self.rootSessionID = rootSessionID
        self.found = found
        self.reason = reason
        self.sessions = sessions
        self.relationships = relationships
        self.externalIdentities = externalIdentities
    }

    init(
        response: ProvenanceSessionTreeResponse,
        noSessionReason: String,
        externalIdentityLimit: Int
    ) {
        let depthsBySessionID = Dictionary(uniqueKeysWithValues: response.relationships.map {
            ($0.sessionID, $0.depth)
        })
        self.init(
            rootSessionID: response.rootSessionID,
            found: response.found,
            reason: response.found ? nil : noSessionReason,
            sessions: response.sessions.map { session in
                Self.compactPayload([
                    "id": session.id,
                    "agent_kind": session.agentKind,
                    "workspace_id": session.workspaceID,
                    "surface_id": session.surfaceID,
                    "worktree_id": session.worktreeID,
                    "cwd": session.cwd,
                    "status": session.status,
                    "started_at": session.startedAt?.timeIntervalSince1970,
                    "updated_at": session.updatedAt.timeIntervalSince1970,
                    "tree_depth": depthsBySessionID[session.id] ?? 0
                ])
            },
            relationships: response.relationships.map { relationship in
                Self.compactPayload([
                    "session_id": relationship.sessionID,
                    "parent_session_id": relationship.parentSessionID,
                    "root_session_id": relationship.rootSessionID,
                    "inbound_delegation_id": relationship.inboundDelegationID,
                    "depth": relationship.depth,
                    "source": relationship.source.rawValue,
                    "confidence": relationship.confidence.rawValue,
                    "created_at": relationship.createdAt.timeIntervalSince1970,
                    "updated_at": relationship.updatedAt.timeIntervalSince1970
                ])
            },
            externalIdentities: response.externalIdentities.prefix(externalIdentityLimit).map { identity in
                Self.compactPayload([
                    "id": identity.id,
                    "session_id": identity.sessionID,
                    "system": identity.system,
                    "kind": identity.kind,
                    "external_id": identity.externalID,
                    "source": identity.source.rawValue,
                    "confidence": identity.confidence.rawValue,
                    "created_at": identity.createdAt.timeIntervalSince1970,
                    "updated_at": identity.updatedAt.timeIntervalSince1970
                ])
            }
        )
    }

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

    private static func compactPayload(_ values: [String: AnyHashable?]) -> [String: AnyHashable] {
        values.reduce(into: [String: AnyHashable]()) { partial, item in
            if let value = item.value {
                partial[item.key] = value
            }
        }
    }
}
