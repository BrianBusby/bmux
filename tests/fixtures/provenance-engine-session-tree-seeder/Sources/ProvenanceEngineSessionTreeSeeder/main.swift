import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK

@main
struct ProvenanceEngineSessionTreeSeeder {
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count >= 2 else {
            throw SeederError.usage
        }

        let databaseURL = URL(fileURLWithPath: arguments[1])
        let scenario = arguments.dropFirst(2).first ?? "basic"
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: databaseURL.path) {
            try FileManager.default.removeItem(at: databaseURL)
        }

        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: databaseURL)
        switch scenario {
        case "basic":
            try await seedBasicSessionTree(client: client)
        case "limit":
            try await seedLimitSessionTree(client: client)
        default:
            throw SeederError.unknownScenario(scenario)
        }
    }

    private static func seedBasicSessionTree(client: any ProvenanceEngineClient) async throws {
        let parent = session(
            id: "codex-parent",
            surfaceID: "surface-1",
            status: "active",
            startedAt: 100,
            updatedAt: 100
        )
        let child = session(
            id: "codex-child",
            surfaceID: "surface-2",
            status: "completed",
            startedAt: 120,
            updatedAt: 140
        )
        let grandchild = session(
            id: "codex-grandchild",
            surfaceID: "surface-3",
            status: "active",
            startedAt: 130,
            updatedAt: 130
        )
        let unrelated = ProvenanceSessionRecord(
            id: "unrelated",
            agentKind: "claude",
            workspaceID: "workspace-9",
            surfaceID: "surface-9",
            worktreeID: "worktree-9",
            cwd: "/other",
            status: "active",
            startedAt: Date(timeIntervalSince1970: 200),
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        try await appendSessions([parent, child, grandchild, unrelated], to: client)
        try await appendRelationship(
            relationship(
                sessionID: child.id,
                parentSessionID: parent.id,
                rootSessionID: parent.id,
                depth: 1,
                createdAt: 120,
                updatedAt: 140
            ),
            identities: [
                identity(
                    id: "identity-child",
                    sessionID: child.id,
                    externalID: "subagent-1",
                    createdAt: 120,
                    updatedAt: 140
                ),
            ],
            to: client
        )
        try await appendRelationship(
            relationship(
                sessionID: grandchild.id,
                parentSessionID: child.id,
                rootSessionID: parent.id,
                depth: 2,
                createdAt: 130,
                updatedAt: 130
            ),
            identities: [
                identity(
                    id: "identity-grandchild",
                    sessionID: grandchild.id,
                    externalID: "subagent-2",
                    createdAt: 130,
                    updatedAt: 130
                ),
            ],
            to: client
        )
        try await appendRelationship(
            relationship(
                sessionID: unrelated.id,
                parentSessionID: "unrelated-parent",
                rootSessionID: "unrelated-parent",
                depth: 1,
                createdAt: 200,
                updatedAt: 200
            ),
            identities: [
                ProvenanceExternalIdentityRecord(
                    id: "identity-unrelated",
                    sessionID: unrelated.id,
                    system: "claude",
                    kind: "thread",
                    externalID: "claude-thread",
                    source: .observed,
                    confidence: .high,
                    createdAt: Date(timeIntervalSince1970: 200),
                    updatedAt: Date(timeIntervalSince1970: 200)
                ),
            ],
            to: client
        )
    }

    private static func seedLimitSessionTree(client: any ProvenanceEngineClient) async throws {
        let root = ProvenanceSessionRecord(
            id: "limit-root",
            agentKind: "codex",
            status: "active",
            startedAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        try await appendSessions([root], to: client)

        for index in 1...120 {
            let timestamp = TimeInterval(1_000 + index)
            let child = ProvenanceSessionRecord(
                id: String(format: "limit-child-%03d", index),
                agentKind: "codex",
                status: "active",
                startedAt: Date(timeIntervalSince1970: timestamp),
                updatedAt: Date(timeIntervalSince1970: timestamp)
            )
            try await appendSessions([child], to: client)
            try await appendRelationship(
                relationship(
                    sessionID: child.id,
                    parentSessionID: root.id,
                    rootSessionID: root.id,
                    depth: 1,
                    createdAt: timestamp,
                    updatedAt: timestamp
                ),
                identities: [],
                to: client
            )
        }
    }

    private static func session(
        id: String,
        surfaceID: String,
        status: String,
        startedAt: TimeInterval,
        updatedAt: TimeInterval
    ) -> ProvenanceSessionRecord {
        ProvenanceSessionRecord(
            id: id,
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: surfaceID,
            worktreeID: "worktree-1",
            cwd: "/repo",
            status: status,
            startedAt: Date(timeIntervalSince1970: startedAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt)
        )
    }

    private static func relationship(
        sessionID: String,
        parentSessionID: String,
        rootSessionID: String,
        depth: Int,
        createdAt: TimeInterval,
        updatedAt: TimeInterval
    ) -> ProvenanceSessionRelationshipRecord {
        ProvenanceSessionRelationshipRecord(
            sessionID: sessionID,
            parentSessionID: parentSessionID,
            rootSessionID: rootSessionID,
            depth: depth,
            source: .observed,
            confidence: .high,
            createdAt: Date(timeIntervalSince1970: createdAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt)
        )
    }

    private static func identity(
        id: String,
        sessionID: String,
        externalID: String,
        createdAt: TimeInterval,
        updatedAt: TimeInterval
    ) -> ProvenanceExternalIdentityRecord {
        ProvenanceExternalIdentityRecord(
            id: id,
            sessionID: sessionID,
            system: "codex",
            kind: "subsession",
            externalID: externalID,
            source: .observed,
            confidence: .high,
            createdAt: Date(timeIntervalSince1970: createdAt),
            updatedAt: Date(timeIntervalSince1970: updatedAt)
        )
    }

    private static func appendSessions(
        _ sessions: [ProvenanceSessionRecord],
        to client: any ProvenanceEngineClient
    ) async throws {
        for session in sessions {
            _ = try await client.appendEvent(ProvenanceAppendEventRequest(
                event: ProvenanceEvent(
                    id: "event-\(session.id)",
                    eventType: .sessionObserved,
                    timestamp: session.updatedAt,
                    sessionID: session.id,
                    source: .observed,
                    confidence: .high,
                    payload: ProvenanceEventPayload(session: session)
                )
            ))
        }
    }

    private static func appendRelationship(
        _ relationship: ProvenanceSessionRelationshipRecord,
        identities: [ProvenanceExternalIdentityRecord],
        to client: any ProvenanceEngineClient
    ) async throws {
        _ = try await client.appendEvent(ProvenanceAppendEventRequest(
            event: ProvenanceEvent(
                id: "event-relationship-\(relationship.sessionID)",
                eventType: .sessionStarted,
                timestamp: relationship.updatedAt,
                sessionID: relationship.sessionID,
                source: .observed,
                confidence: .high,
                payload: ProvenanceEventPayload(
                    sessionRelationship: relationship,
                    externalIdentities: identities
                )
            )
        ))
    }
}

enum SeederError: Error, CustomStringConvertible {
    case usage
    case unknownScenario(String)

    var description: String {
        switch self {
        case .usage:
            return "Usage: ProvenanceEngineSessionTreeSeeder <database-path> [basic|limit]"
        case .unknownScenario(let scenario):
            return "Unknown scenario: \(scenario)"
        }
    }
}
