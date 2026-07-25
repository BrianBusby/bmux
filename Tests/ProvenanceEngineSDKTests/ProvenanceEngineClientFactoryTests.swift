import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

@Suite
struct ProvenanceEngineClientFactoryTests {
    @Test
    func sqliteClientReturnsPublicContractClientBackedByDatabaseURL() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)

        _ = try await client.appendEvent(
            ProvenanceAppendEventRequest(
                event: ProvenanceEvent(
                    id: "event-1",
                    eventType: .worktreeObserved,
                    timestamp: timestamp,
                    repositoryID: "repository-1",
                    worktreeID: "worktree-1",
                    source: .observed,
                    confidence: .high,
                    payload: ProvenanceEventPayload(
                        repository: ProvenanceRepositoryRecord(
                            id: "repository-1",
                            path: "/tmp/repository",
                            remoteSlug: "owner/repository",
                            createdAt: timestamp,
                            updatedAt: timestamp
                        ),
                        worktree: ProvenanceWorktreeRecord(
                            id: "worktree-1",
                            repositoryID: "repository-1",
                            path: "/tmp/repository",
                            branch: "main",
                            currentHEAD: "abc123",
                            isDirty: false,
                            status: "active",
                            updatedAt: timestamp
                        )
                    )
                )
            )
        )

        let response = try await client.worktrees(ProvenanceWorktreeListRequest(repositoryID: nil, limit: nil))

        #expect(response.worktrees.map(\.worktree.id) == ["worktree-1"])
        #expect(response.worktrees.first?.repository?.remoteSlug == "owner/repository")
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func sqliteClientReadsSessionTreeThroughPublicContract() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let rootSession = ProvenanceSessionRecord(
            id: "session-root",
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: "surface-1",
            status: "active",
            startedAt: timestamp,
            updatedAt: timestamp
        )
        let childSession = ProvenanceSessionRecord(
            id: "session-child",
            agentKind: "codex",
            workspaceID: "workspace-1",
            surfaceID: "surface-2",
            status: "completed",
            startedAt: Date(timeIntervalSince1970: 1_800_000_010),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_020)
        )
        let relationship = ProvenanceSessionRelationshipRecord(
            sessionID: childSession.id,
            parentSessionID: rootSession.id,
            rootSessionID: rootSession.id,
            inboundDelegationID: "delegation-1",
            depth: 1,
            source: .observed,
            confidence: .high,
            createdAt: childSession.startedAt ?? childSession.updatedAt,
            updatedAt: childSession.updatedAt
        )
        let externalIdentity = ProvenanceExternalIdentityRecord(
            id: "identity-child",
            sessionID: childSession.id,
            system: "codex",
            kind: "worker",
            externalID: "child-1",
            source: .observed,
            confidence: .high,
            createdAt: childSession.startedAt ?? childSession.updatedAt,
            updatedAt: childSession.updatedAt
        )

        for session in [rootSession, childSession] {
            _ = try await client.appendEvent(
                ProvenanceAppendEventRequest(
                    event: ProvenanceEvent(
                        id: "event-\(session.id)",
                        eventType: .sessionObserved,
                        timestamp: session.updatedAt,
                        sessionID: session.id,
                        source: .observed,
                        confidence: .high,
                        payload: ProvenanceEventPayload(session: session)
                    )
                )
            )
        }
        _ = try await client.appendEvent(
            ProvenanceAppendEventRequest(
                event: ProvenanceEvent(
                    id: "event-relationship",
                    eventType: .sessionStarted,
                    timestamp: relationship.updatedAt,
                    sessionID: childSession.id,
                    source: .observed,
                    confidence: .high,
                    payload: ProvenanceEventPayload(
                        sessionRelationship: relationship,
                        externalIdentities: [externalIdentity]
                    )
                )
            )
        )

        let tree = try await client.sessionTree(
            ProvenanceSessionTreeRequest(rootSessionID: rootSession.id)
        )

        #expect(tree.found)
        #expect(tree.reason == nil)
        #expect(tree.rootSessionID == rootSession.id)
        #expect(tree.sessions == [rootSession, childSession])
        #expect(tree.relationships == [relationship])
        #expect(tree.externalIdentities == [externalIdentity])
    }

    @Test
    func defaultSQLiteClientUsesEngineOwnedStatePathUnderHomeDirectory() async throws {
        let homeDirectory = Self.temporaryHomeDirectory()
        defer { try? FileManager.default.removeItem(at: homeDirectory) }
        let client = try ProvenanceEngineClientFactory().defaultSQLiteClient(homeDirectory: homeDirectory)

        _ = try await client.health()

        let expectedDatabaseURL = homeDirectory
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
            .appendingPathComponent("provenance-engine", isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
        #expect(FileManager.default.fileExists(atPath: expectedDatabaseURL.path))
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-sdk-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func temporaryHomeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-sdk-home-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
