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

    @Test(arguments: [false, true])
    func failedTicketWriteCanRetryTheSameWorkspaceSnapshot(automatic: Bool) async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-ticket-retry-\(UUID())/provenance.sqlite")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let client = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: url)
        let git = WorkProvenanceGitSnapshot(
            repositoryRoot: "/tmp/ticket-retry", commonDirectory: nil, remoteSlug: nil,
            branch: "main", headCommit: nil, isDirty: false, statusEntries: []
        )
        let service = WorkProvenanceObservationService(
            client: client, gitInspector: FakeGitInspector(gitSnapshot: git),
            ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                authorizationProvider: WorkProvenanceEnvironmentLinearAuthorizationProvider(environment: [:])
            )
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
        if automatic {
            let observation = Task { await service.observeWorkspaceSnapshot(snapshot) }
            let deadline = ContinuousClock.now.advanced(by: .seconds(15))
            while await service.lastErrorDescription == nil, ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(await service.lastErrorDescription != nil)
            #expect(sqlite3_exec(writer, "ROLLBACK", nil, nil, nil) == SQLITE_OK)
            await observation.value
        } else {
            await service.observeWorkspaceSnapshot(snapshot)
            #expect(await service.lastErrorDescription != nil)
            #expect(sqlite3_exec(writer, "ROLLBACK", nil, nil, nil) == SQLITE_OK)
            await service.observeWorkspaceSnapshot(snapshot)
        }
        let result = try await client.workspaceDisplay(.init(workspaceID: snapshot.stableWorkspaceID.uuidString))
        #expect(result.display?.ticketIDs == ["INP-2430"])
        #expect(result.display?.ticketLinks.first?.url == "https://linear.app/companycam/issue/INP-2430")
    }

    private struct FakeGitInspector: WorkProvenanceGitInspecting {
        let gitSnapshot: WorkProvenanceGitSnapshot

        func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot? {
            gitSnapshot
        }
    }
}
