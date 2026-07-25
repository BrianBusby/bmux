import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

@Suite
struct LocalDurabilitySDKTests {
    @Test
    func successfulAppendSurvivesClientRecreation() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = Self.repository(timestamp: timestamp)
        let worktree = Self.worktree(repository: repository, timestamp: timestamp)
        let writer = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)

        let response = try await writer.appendEvent(
            ProvenanceAppendEventRequest(
                event: ProvenanceEvent(
                    id: "event-durable-worktree",
                    eventType: .worktreeObserved,
                    timestamp: timestamp,
                    repositoryID: repository.id,
                    worktreeID: worktree.id,
                    source: .observed,
                    confidence: .high,
                    payload: ProvenanceEventPayload(repository: repository, worktree: worktree)
                )
            )
        )

        let reader = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let worktrees = try await reader.worktrees(ProvenanceWorktreeListRequest())

        #expect(response.eventID == "event-durable-worktree")
        #expect(worktrees.worktrees == [
            ProvenanceWorktreeListEntry(worktree: worktree, repository: repository),
        ])
    }

    @Test
    func duplicateEventIDFailsWithoutReplacingAcceptedProjection() async throws {
        let url = Self.temporaryDatabaseURL()
        defer { Self.removeTemporaryDatabaseDirectory(for: url) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = Self.repository(timestamp: timestamp)
        let worktree = Self.worktree(repository: repository, timestamp: timestamp)
        let replacementRepository = ProvenanceRepositoryRecord(
            id: "repository-replacement",
            path: "/repos/replacement",
            remoteSlug: "owner/replacement",
            createdAt: timestamp,
            updatedAt: timestamp.addingTimeInterval(10)
        )
        let replacementWorktree = Self.worktree(repository: replacementRepository, timestamp: timestamp.addingTimeInterval(10))
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)

        _ = try await client.appendEvent(
            ProvenanceAppendEventRequest(
                event: ProvenanceEvent(
                    id: "event-duplicate-durability",
                    eventType: .worktreeObserved,
                    timestamp: timestamp,
                    repositoryID: repository.id,
                    worktreeID: worktree.id,
                    source: .observed,
                    confidence: .high,
                    payload: ProvenanceEventPayload(repository: repository, worktree: worktree)
                )
            )
        )

        do {
            _ = try await client.appendEvent(
                ProvenanceAppendEventRequest(
                    event: ProvenanceEvent(
                        id: "event-duplicate-durability",
                        eventType: .worktreeObserved,
                        timestamp: timestamp.addingTimeInterval(10),
                        repositoryID: replacementRepository.id,
                        worktreeID: replacementWorktree.id,
                        source: .observed,
                        confidence: .high,
                        payload: ProvenanceEventPayload(
                            repository: replacementRepository,
                            worktree: replacementWorktree
                        )
                    )
                )
            )
            Issue.record("Expected duplicate event append to throw")
        } catch {
            #expect(String(describing: error).contains("UNIQUE") || String(describing: error).contains("unique"))
        }

        let reopened = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let worktrees = try await reopened.worktrees(ProvenanceWorktreeListRequest())

        #expect(worktrees.worktrees == [
            ProvenanceWorktreeListEntry(worktree: worktree, repository: repository),
        ])
    }

    private static func repository(timestamp: Date) -> ProvenanceRepositoryRecord {
        ProvenanceRepositoryRecord(
            id: "repository-durable",
            path: "/repos/durable",
            remoteSlug: "owner/durable",
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    private static func worktree(
        repository: ProvenanceRepositoryRecord,
        timestamp: Date
    ) -> ProvenanceWorktreeRecord {
        ProvenanceWorktreeRecord(
            id: "worktree-\(repository.id)",
            repositoryID: repository.id,
            path: repository.path,
            branch: "main",
            currentHEAD: "durable-head",
            isDirty: false,
            status: "active",
            lastReconciledAt: timestamp,
            updatedAt: timestamp
        )
    }

    private static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-engine-local-durability-sdk-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("provenance.sqlite")
    }

    private static func removeTemporaryDatabaseDirectory(for url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
