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
