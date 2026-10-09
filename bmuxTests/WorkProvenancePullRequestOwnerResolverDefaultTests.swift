import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing
import SQLite3

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct WorkProvenancePullRequestOwnerResolverDefaultTests {
    @Test
    func defaultObservationServiceKeepsPullRequestFactsWithoutOwnerLookup() async throws {
        let databaseDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "bmux-work-provenance-default-pr-owner-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: databaseDir) }
        try FileManager.default.createDirectory(at: databaseDir, withIntermediateDirectories: true)
        let client = try ProvenanceEngineClientFactory().sqliteClient(
            databaseURL: databaseDir.appendingPathComponent("provenance.sqlite")
        )
        let repositoryRoot = "/tmp/bmux-default-pr-owner-resolver-repo"
        let branch = "feature/runtime-owned-pr-metadata"
        let stableWorkspaceID = UUID(uuidString: "12121212-1212-1212-1212-121212121212")!
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(gitSnapshot: WorkProvenanceGitSnapshot(
                repositoryRoot: repositoryRoot,
                commonDirectory: "\(repositoryRoot)/.git",
                remoteSlug: "manaflow-ai/bmux",
                branch: branch,
                headCommit: "1212121212121212121212121212121212121212",
                isDirty: false,
                statusEntries: []
            )),
            dateProvider: { Date(timeIntervalSince1970: 575) }
        )

        await service.observeWorkspaceSnapshot(WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(uuidString: "34343434-3434-3434-3434-343434343434")!,
            stableWorkspaceID: stableWorkspaceID,
            title: "Runtime-owned PR metadata",
            currentDirectory: repositoryRoot,
            branch: branch,
            pullRequest: WorkProvenanceWorkspaceSnapshot.PullRequest(
                number: 5314,
                url: "https://github.com/manaflow-ai/bmux/pull/5314",
                ownerLogin: nil,
                ownerURL: nil,
                status: "open",
                branch: nil,
                isStale: false
            )
        ))

        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: stableWorkspaceID.uuidString
        ))
        #expect(display.found)
        #expect(display.display?.pullRequestNumber == 5314)
        #expect(display.display?.pullRequestOwnerLogin == nil)
        #expect(display.display?.pullRequestOwnerURL == nil)
        #expect(display.display?.pullRequestBranch == nil)
        #expect(display.display?.ticketIDs == [])
    }

    @Test(arguments: ["manual", "automatic", "duplicate", "cancelled", "superseded"])
    func failedTicketWriteCanRetryTheSameWorkspaceSnapshot(recovery: String) async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-ticket-retry-\(UUID())/provenance.sqlite")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let git = WorkProvenanceGitSnapshot(
            repositoryRoot: "/tmp/ticket-retry", commonDirectory: nil, remoteSlug: nil,
            branch: "main", headCommit: nil, isDirty: false, statusEntries: []
        )
        let retryStarted = AsyncStream<Void>.makeStream()
        let retryAllowed = AsyncStream<Void>.makeStream()
        defer { retryStarted.continuation.finish(); retryAllowed.continuation.finish() }
        let service = WorkProvenanceObservationService(
            client: client, gitInspector: FakeGitInspector(gitSnapshot: git),
            ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                authorizationProvider: WorkProvenanceEnvironmentLinearAuthorizationProvider(environment: [:])
            ),
            retryDelay: { _ in
                guard recovery != "manual" else { return }
                retryStarted.continuation.yield(())
                var iterator = retryAllowed.stream.makeAsyncIterator()
                _ = await iterator.next()
            }
        )
        let snapshot = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(), stableWorkspaceID: UUID(), title: "Review checklist builder",
            currentDirectory: git.repositoryRoot,
            pullRequest: .init(
                number: 11712, title: "INP-2430 Add follow-up items to mobile checklist builder",
                url: "https://github.com/CompanyCam/companycam-mobile/pull/11712",
                ownerLogin: nil, ownerURL: nil, status: "open", branch: nil, isStale: false
            )
        )
        var handle: OpaquePointer?
        #expect(sqlite3_open(url.path, &handle) == SQLITE_OK)
        let writer = try #require(handle)
        defer { sqlite3_close(writer) }
        #expect(sqlite3_exec(writer, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_OK)
        if recovery != "manual" {
            let observation = Task { await service.observeWorkspaceSnapshot(snapshot) }
            var retries = retryStarted.stream.makeAsyncIterator()
            _ = await retries.next()
            #expect(await service.lastErrorDescription != nil)
            #expect(sqlite3_exec(writer, "ROLLBACK", nil, nil, nil) == SQLITE_OK)
            if recovery == "duplicate" {
                await service.observeWorkspaceSnapshot(snapshot)
            } else if recovery == "cancelled" {
                observation.cancel()
            } else if recovery == "superseded" {
                await service.observeWorkspaceSnapshot(WorkProvenanceWorkspaceSnapshot(
                    workspaceID: snapshot.workspaceID, stableWorkspaceID: snapshot.stableWorkspaceID,
                    title: "Updated checklist review", currentDirectory: snapshot.currentDirectory,
                    pullRequest: snapshot.pullRequest
                ))
            }
            retryAllowed.continuation.yield(())
            await observation.value
        } else {
            await service.observeWorkspaceSnapshot(snapshot)
            #expect(await service.lastErrorDescription != nil)
            #expect(sqlite3_exec(writer, "ROLLBACK", nil, nil, nil) == SQLITE_OK)
            await service.observeWorkspaceSnapshot(snapshot)
        }
        let result = try await client.workspaceDisplay(.init(workspaceID: snapshot.stableWorkspaceID.uuidString))
        if recovery == "cancelled" {
            #expect(result.display == nil)
            return
        }
        if recovery == "superseded" { #expect(result.display?.title == "Updated checklist review") }
        #expect(result.display?.ticketIDs == ["INP-2430"])
        #expect(result.display?.ticketLinks.first?.url == "https://linear.app/companycam/issue/INP-2430")
    }

    @Test
    func supersededSnapshotDoesNotWriteAfterDelayedGitInspection() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-observation-superseded-\(UUID())/provenance.sqlite")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let entered = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        defer { entered.continuation.finish(); release.continuation.finish() }
        let service = WorkProvenanceObservationService(
            client: client, gitInspector: GatedGitInspector(entered: entered.continuation, release: release.stream)
        )
        let workspaceID = UUID(), stableID = UUID()
        let old = WorkProvenanceWorkspaceSnapshot(
            workspaceID: workspaceID, stableWorkspaceID: stableID,
            title: "Earlier review", currentDirectory: "/tmp/earlier-review"
        )
        let observation = Task { await service.observeWorkspaceSnapshot(old) }
        var entries = entered.stream.makeAsyncIterator()
        _ = await entries.next()
        await service.observeWorkspaceSnapshot(WorkProvenanceWorkspaceSnapshot(
            workspaceID: workspaceID, stableWorkspaceID: stableID,
            title: "Current review", currentDirectory: "/tmp/current-review"
        ))
        release.continuation.yield(())
        await observation.value
        let result = try await client.workspaceDisplay(.init(workspaceID: stableID.uuidString))
        #expect(result.display?.title == "Current review")
        #expect(result.display?.currentDirectory == "/tmp/current-review")
    }

    @Test
    func ticketIsPersistedBeforeOptionalEnrichmentCompletes() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-ticket-enrichment-\(UUID())/provenance.sqlite")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let entered = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        defer { entered.continuation.finish(); release.continuation.finish() }
        let git = WorkProvenanceGitSnapshot(
            repositoryRoot: "/tmp/checklist-review", commonDirectory: nil, remoteSlug: nil,
            branch: "main", headCommit: nil, isDirty: false, statusEntries: []
        )
        let service = WorkProvenanceObservationService(
            client: client, gitInspector: FakeGitInspector(gitSnapshot: git),
            ticketLinkResolver: GatedTicketResolver(entered: entered.continuation, release: release.stream)
        )
        let snapshot = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(), stableWorkspaceID: UUID(), title: "Review checklist builder",
            currentDirectory: git.repositoryRoot,
            pullRequest: .init(
                number: 11712, title: "INP-2430 Add follow-up items to mobile checklist builder",
                url: "https://github.com/CompanyCam/companycam-mobile/pull/11712",
                ownerLogin: nil, ownerURL: nil, status: "open", branch: nil, isStale: false
            )
        )
        let observation = Task { await service.observeWorkspaceSnapshot(snapshot) }
        var entries = entered.stream.makeAsyncIterator()
        _ = await entries.next()
        let immediate = try await client.workspaceDisplay(.init(workspaceID: snapshot.stableWorkspaceID.uuidString))
        #expect(immediate.display?.ticketIDs == ["INP-2430"])
        #expect(immediate.display?.ticketLinks.first?.url == "https://linear.app/companycam/issue/INP-2430")
        release.continuation.yield(())
        await observation.value
        let enriched = try await client.workspaceDisplay(.init(workspaceID: snapshot.stableWorkspaceID.uuidString))
        #expect(enriched.display?.ticketLinks.first?.title == "Checklist follow-up items")
    }

    private struct GatedTicketResolver: WorkProvenanceTicketLinkResolving {
        let entered: AsyncStream<Void>.Continuation
        let release: AsyncStream<Void>

        func workspaceLinks(for ticketIDs: [String]) async -> WorkProvenanceWorkspaceLinkFacts {
            entered.yield(())
            var iterator = release.makeAsyncIterator()
            _ = await iterator.next()
            return .init(ticketLinks: [.init(
                id: "INP-2430", system: "linear", title: "Checklist follow-up items",
                url: "https://linear.app/companycam/issue/INP-2430/checklist-follow-up-items"
            )])
        }
    }

    private struct GatedGitInspector: WorkProvenanceGitInspecting {
        let entered: AsyncStream<Void>.Continuation
        let release: AsyncStream<Void>

        func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot? {
            if directory == "/tmp/earlier-review" {
                entered.yield(())
                var iterator = release.makeAsyncIterator()
                _ = await iterator.next()
            }
            return WorkProvenanceGitSnapshot(
                repositoryRoot: directory, commonDirectory: nil, remoteSlug: nil,
                branch: "main", headCommit: nil, isDirty: false, statusEntries: []
            )
        }
    }

    private struct FakeGitInspector: WorkProvenanceGitInspecting {
        let gitSnapshot: WorkProvenanceGitSnapshot

        func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot? {
            gitSnapshot
        }
    }
}
