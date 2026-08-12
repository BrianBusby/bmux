import Foundation
import ProvenanceEngineContracts
import ProvenanceEngineSDK
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite
struct WorkProvenanceObserverTests {
    @Test
    func defaultRuntimeStoreObservationCanBeReadThroughPublicCurrentContext() async throws {
        let homeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bmux-work-provenance-default-home-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: homeDirectory) }
        let location = WorkProvenanceStorageLocation(homeDirectory: homeDirectory)
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient =
            try ProvenanceEngineClientFactory().defaultSQLiteClient(homeDirectory: homeDirectory)
        let repositoryRoot = "/tmp/bmux-default-observed-repo"
        let snapshot = WorkProvenanceGitSnapshot(
            repositoryRoot: repositoryRoot,
            commonDirectory: "/tmp/bmux-default-observed-repo/.git",
            remoteSlug: "manaflow-ai/bmux",
            branch: "slice-e-provenance-v1-adoption",
            headCommit: "abcdefabcdefabcdefabcdefabcdefabcdefabcd",
            isDirty: true,
            statusEntries: [
                WorkProvenanceGitStatusEntry(path: "Sources/DefaultStore.swift", status: "modified")
            ]
        )
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: snapshot]),
            dateProvider: { Date(timeIntervalSince1970: 400) }
        )
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            stableWorkspaceID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            title: "Default Store",
            currentDirectory: repositoryRoot
        )

        await service.observeWorkspaceSnapshot(workspace)

        let reader = try ProvenanceEngineClientFactory().defaultSQLiteClient(homeDirectory: homeDirectory)
        let context = try await reader.currentContext(ProvenanceCurrentContextRequest(repositoryPath: repositoryRoot))
        let display = try await reader.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: workspace.stableWorkspaceID.uuidString
        ))

        #expect(FileManager.default.fileExists(atPath: location.databaseURL.path))
        #expect(!FileManager.default.fileExists(atPath: location.legacyDatabaseURL.path))
        #expect(context.found)
        #expect(context.worktree?.path == repositoryRoot)
        #expect(context.dirtyFiles.map(\.fileChange.path) == ["Sources/DefaultStore.swift"])
        #expect(display.found)
        #expect(display.display?.title == "Default Store")
        #expect(display.display?.branch == "slice-e-provenance-v1-adoption")
        #expect(display.display?.currentDirectory == repositoryRoot)
        #expect(display.display?.isDirty == true)
        #expect(display.display?.latestEventID != nil)
        #expect(display.display?.latestEventSequence == 1)
    }

    @Test
    func observeDirtyWorkspacePersistsUnattributedFileProvenanceAndDedupesUnchangedState() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let repositoryRoot = "/tmp/bmux-observed-repo"
        let snapshot = WorkProvenanceGitSnapshot(
            repositoryRoot: repositoryRoot,
            commonDirectory: "/tmp/bmux-observed-repo/.git",
            remoteSlug: "manaflow-ai/bmux",
            branch: "feature/provenance",
            headCommit: "0123456789012345678901234567890123456789",
            isDirty: true,
            statusEntries: [
                WorkProvenanceGitStatusEntry(path: "Sources/App.swift", status: "modified"),
                WorkProvenanceGitStatusEntry(path: "Sources/NewFile.swift", status: "untracked")
            ]
        )
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: snapshot]),
            dateProvider: { Date(timeIntervalSince1970: 300) }
        )
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            stableWorkspaceID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "Provenance",
            currentDirectory: repositoryRoot
        )

        await service.observeWorkspaceSnapshot(workspace)
        await service.observeWorkspaceSnapshot(workspace)

        let worktrees = try await client.worktrees(ProvenanceWorktreeListRequest())
        let context = try await client.currentContext(ProvenanceCurrentContextRequest(repositoryPath: repositoryRoot))
        let modified = try #require(context.dirtyFiles.first {
            $0.fileChange.path == "Sources/App.swift"
        })
        let untracked = try #require(context.dirtyFiles.first {
            $0.fileChange.path == "Sources/NewFile.swift"
        })

        #expect(worktrees.worktrees.count == 1)
        #expect(worktrees.worktrees.first?.repository?.remoteSlug == "manaflow-ai/bmux")
        #expect(context.worktree?.branch == "feature/provenance")
        #expect(context.worktree?.isDirty == true)
        #expect(modified.fileChange.status == "modified")
        #expect(modified.fileChange.attributionSource == .unattributed)
        #expect(modified.fileChange.attributionConfidence == .low)
        #expect(untracked.fileChange.status == "untracked")
    }

    @Test
    func nonRepositoryWorkspaceDoesNotAppendAnEvent() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [:])
        )
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            stableWorkspaceID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            title: "No Repo",
            currentDirectory: "/tmp/not-a-repo"
        )

        await service.observeWorkspaceSnapshot(workspace)

        let context = try await client.currentContext(ProvenanceCurrentContextRequest(repositoryPath: "/tmp/not-a-repo"))
        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: workspace.stableWorkspaceID.uuidString
        ))
        #expect(context.found == false)
        #expect(display.found)
        #expect(display.display?.title == "No Repo")
        #expect(display.display?.currentDirectory == "/tmp/not-a-repo")
        #expect(display.display?.isDirty == nil)
    }

    @Test
    func observeWorkspaceDisplayPersistsTitlePullRequestAndTicketChangesWhenGitIsUnchanged() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let repositoryRoot = "/tmp/bmux-display-observed-repo"
        let snapshot = WorkProvenanceGitSnapshot(
            repositoryRoot: repositoryRoot,
            commonDirectory: "/tmp/bmux-display-observed-repo/.git",
            remoteSlug: "manaflow-ai/bmux",
            branch: "ste-1964-canonical-domain-mutation-paths",
            headCommit: "fedcbafedcbafedcbafedcbafedcbafedcbafedc",
            isDirty: false,
            statusEntries: []
        )
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: snapshot]),
            pullRequestOwnerResolver: FakePullRequestOwnerResolver(ownersByURL: [
                "https://github.com/manaflow-ai/bmux/pull/42": WorkProvenancePullRequestOwner(
                    login: "brianbusby",
                    url: "https://github.com/brianbusby"
                )
            ]),
            ticketTitleResolver: FakeTicketTitleResolver(titlesByID: [
                "STE-1964": "Actual Linear ticket title"
            ]),
            dateProvider: { Date(timeIntervalSince1970: 500) }
        )
        let workspaceID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        let stableWorkspaceID = UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
        let firstWorkspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: workspaceID,
            stableWorkspaceID: stableWorkspaceID,
            title: "Initial Display",
            titleSource: "auto_prompt",
            currentDirectory: repositoryRoot,
            branch: "ste-1964-canonical-domain-mutation-paths",
            pullRequest: WorkProvenanceWorkspaceSnapshot.PullRequest(
                number: 41,
                url: "https://github.com/manaflow-ai/bmux/pull/41",
                ownerLogin: "octocat",
                ownerURL: "https://github.com/octocat",
                status: "open",
                branch: "ste-1964-canonical-domain-mutation-paths",
                isStale: false
            )
        )
        let secondWorkspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: workspaceID,
            stableWorkspaceID: stableWorkspaceID,
            title: "Merged Display",
            titleSource: "user",
            currentDirectory: repositoryRoot,
            branch: "ste-1964-canonical-domain-mutation-paths",
            pullRequest: WorkProvenanceWorkspaceSnapshot.PullRequest(
                number: 42,
                url: "https://github.com/manaflow-ai/bmux/pull/42",
                ownerLogin: nil,
                ownerURL: nil,
                status: "merged",
                branch: "ste-1964-canonical-domain-mutation-paths",
                isStale: true
            )
        )

        await service.observeWorkspaceSnapshot(firstWorkspace)
        await service.observeWorkspaceSnapshot(secondWorkspace)

        let worktrees = try await client.worktrees(ProvenanceWorktreeListRequest())
        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(workspaceID: stableWorkspaceID.uuidString))

        #expect(worktrees.worktrees.count == 1)
        #expect(display.found)
        #expect(display.display?.title == "Merged Display")
        #expect(display.display?.titleSource == "user")
        #expect(display.display?.branch == "ste-1964-canonical-domain-mutation-paths")
        #expect(display.display?.pullRequestNumber == 42)
        #expect(display.display?.pullRequestURL == "https://github.com/manaflow-ai/bmux/pull/42")
        #expect(display.display?.pullRequestOwnerLogin == "brianbusby")
        #expect(display.display?.pullRequestOwnerURL == "https://github.com/brianbusby")
        #expect(display.display?.pullRequestStatus == "merged")
        #expect(display.display?.pullRequestBranch == "ste-1964-canonical-domain-mutation-paths")
        #expect(display.display?.pullRequestIsStale == true)
        #expect(display.display?.currentDirectory == repositoryRoot)
        #expect(display.display?.isDirty == false)
        #expect(display.display?.latestEventID != nil)
        #expect(display.display?.latestEventSequence == 3)
        #expect(display.display?.ticketIDs == ["STE-1964"])
        #expect(display.display?.ticketLinks == [
            ProvenanceWorkspaceDisplayTicketLinkRecord(
                id: "STE-1964",
                title: "Actual Linear ticket title"
            )
        ])
    }

    @Test
    func promptLinkedPullRequestDoesNotInheritAmbientBranchTicket() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let repositoryRoot = "/tmp/bmux-prompt-linked-pr-repo"
        let snapshot = WorkProvenanceGitSnapshot(
            repositoryRoot: repositoryRoot,
            commonDirectory: "/tmp/bmux-prompt-linked-pr-repo/.git",
            remoteSlug: "CompanyCam/Company-Cam-API",
            branch: "ste-1967-send-company-industry-key-to-amplitude-pr26096",
            headCommit: "1111111111111111111111111111111111111111",
            isDirty: false,
            statusEntries: []
        )
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: snapshot]),
            dateProvider: { Date(timeIntervalSince1970: 550) }
        )
        let stableWorkspaceID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            stableWorkspaceID: stableWorkspaceID,
            title: "Here s comment docs ai-guidelines pull-requests md",
            currentDirectory: repositoryRoot,
            branch: "ste-1967-send-company-industry-key-to-amplitude-pr26096",
            pullRequest: WorkProvenanceWorkspaceSnapshot.PullRequest(
                number: 26117,
                url: "https://github.com/CompanyCam/Company-Cam-API/pull/26117",
                ownerLogin: nil,
                ownerURL: nil,
                status: "open",
                branch: nil,
                isStale: false
            )
        )

        await service.observeWorkspaceSnapshot(workspace)

        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(
            workspaceID: stableWorkspaceID.uuidString
        ))

        #expect(display.found)
        #expect(display.display?.branch == "ste-1967-send-company-industry-key-to-amplitude-pr26096")
        #expect(display.display?.pullRequestNumber == 26117)
        #expect(display.display?.pullRequestURL == "https://github.com/CompanyCam/Company-Cam-API/pull/26117")
        #expect(display.display?.pullRequestBranch == nil)
        #expect(display.display?.ticketIDs == [])
        #expect(display.display?.ticketLinks == [])
    }

    @Test
    func linearTicketTitleResolverQueriesLinearIssueTitle() async throws {
        let loader = FakeLinearGraphQLLoader(responseBody: """
        {"data":{"issue":{"title":"Actual Linear ticket title"}}}
        """)
        let resolver = WorkProvenanceLinearTicketTitleResolver(
            apiKeyProvider: { "linear-api-key" },
            load: { request in
                await loader.load(request)
            }
        )

        let titles = await resolver.titles(for: ["ste-1964", "STE-1964", "not-a-ticket"])
        let requests = await loader.requests
        let request = try #require(requests.first)
        let body = try #require(request.httpBody)
        let payload = try #require(String(data: body, encoding: .utf8))

        #expect(titles == ["STE-1964": "Actual Linear ticket title"])
        #expect(requests.count == 1)
        #expect(request.url == URL(string: "https://api.linear.app/graphql"))
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "linear-api-key")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(payload.contains(#""id":"STE-1964""#))
    }

    @Test
    func workspaceDisplayCurrentStateSnapshotNormalizesDisplayFacts() throws {
        let updatedAt = Date(timeIntervalSince1970: 700)
        let record = ProvenanceWorkspaceDisplayRecord(
            id: "workspace-display-1",
            workspaceID: "99999999-9999-9999-9999-999999999999",
            repositoryID: "repo-1",
            worktreeID: "worktree-1",
            currentDirectory: " /tmp/bmux ",
            title: " Current Slice ",
            titleSource: "user",
            branch: " pe-workspace-display-tab-projection ",
            pullRequestNumber: 57,
            pullRequestURL: "https://github.com/manaflow-ai/bmux/pull/57",
            pullRequestOwnerLogin: " octocat ",
            pullRequestOwnerURL: " https://github.com/octocat ",
            pullRequestStatus: "merged",
            pullRequestBranch: "pe-workspace-display-tab-projection",
            pullRequestIsStale: true,
            isDirty: false,
            ticketIDs: [" STE-1964 ", "STE-1964", "GH-57"],
            ticketLinks: [
                ProvenanceWorkspaceDisplayTicketLinkRecord(
                    id: "STE-1964",
                    system: "linear",
                    title: " Canonical domain mutation paths ",
                    url: "https://linear.app/company/issue/STE-1964"
                )
            ],
            latestEventID: " event-1 ",
            latestEventSequence: 12,
            observedAt: updatedAt,
            updatedAt: updatedAt
        )

        let snapshot = try #require(WorkspaceDisplayCurrentStateSnapshot(record))

        #expect(snapshot.stableWorkspaceID == UUID(uuidString: "99999999-9999-9999-9999-999999999999"))
        #expect(snapshot.title == "Current Slice")
        #expect(snapshot.currentDirectory == "/tmp/bmux")
        #expect(snapshot.branch == "pe-workspace-display-tab-projection")
        #expect(snapshot.pullRequest?.number == 57)
        #expect(snapshot.pullRequest?.url == URL(string: "https://github.com/manaflow-ai/bmux/pull/57"))
        #expect(snapshot.pullRequest?.ownerLogin == "octocat")
        #expect(snapshot.pullRequest?.ownerURL == URL(string: "https://github.com/octocat"))
        #expect(snapshot.pullRequest?.status == "merged")
        #expect(snapshot.pullRequest?.branch == "pe-workspace-display-tab-projection")
        #expect(snapshot.pullRequest?.isStale == true)
        #expect(snapshot.isDirty == false)
        #expect(snapshot.ticketLinks.map(\.id) == ["STE-1964", "GH-57"])
        #expect(snapshot.ticketLinks.first?.system == "linear")
        #expect(snapshot.ticketLinks.first?.title == "Canonical domain mutation paths")
        #expect(snapshot.ticketLinks.first?.url == URL(string: "https://linear.app/company/issue/STE-1964"))
        #expect(snapshot.ticketLinks.last?.system == "linear")
        #expect(snapshot.ticketLinks.last?.title == nil)
        #expect(snapshot.ticketLinks.last?.url == URL(string: "https://linear.app/company/issue/GH-57"))
        #expect(snapshot.latestEventID == "event-1")
        #expect(snapshot.latestEventSequence == 12)
    }

    @Test
    func workspaceDisplayCurrentStateSnapshotPrefersHigherEventSequence() throws {
        let older = try #require(WorkspaceDisplayCurrentStateSnapshot(workspaceDisplayRecord(
            branch: "older",
            sequence: 4,
            updatedAt: Date(timeIntervalSince1970: 900)
        )))
        let newer = try #require(WorkspaceDisplayCurrentStateSnapshot(workspaceDisplayRecord(
            branch: "newer",
            sequence: 5,
            updatedAt: Date(timeIntervalSince1970: 800)
        )))

        #expect(newer.isNewerThan(older))
        #expect(!older.isNewerThan(newer))
    }

    @MainActor
    @Test
    func workspaceDisplayCurrentStateSubscriptionRefreshesCurrentWorkspaceIDsWhenPEChanges() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let stableWorkspaceID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let scheduler = ManualCoalescerScheduler()
        let stream = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let subscription = WorkspaceDisplayCurrentStateSubscription(
            databaseURL: fixture.databaseURL,
            changeStream: { stream.stream },
            coalescer: NotificationBurstCoalescer(
                delay: 0.05,
                schedule: scheduler.schedule(delay:action:)
            )
        )
        var refreshes: [[UUID]] = []

        subscription.start(
            stableWorkspaceIDs: { [stableWorkspaceID] },
            refresh: { refreshes.append($0) }
        )
        stream.continuation.yield(())
        await scheduler.waitForPendingFlushCount(1)

        #expect(scheduler.delays == [0.05])
        #expect(refreshes.isEmpty)

        scheduler.fire(at: 0)
        #expect(refreshes == [[stableWorkspaceID]])

        subscription.stop()
        stream.continuation.finish()
    }

    private struct FakeGitInspector: WorkProvenanceGitInspecting {
        let snapshotsByDirectory: [String: WorkProvenanceGitSnapshot]

        func snapshot(for directory: String) async -> WorkProvenanceGitSnapshot? {
            snapshotsByDirectory[directory]
        }
    }

    private struct FakePullRequestOwnerResolver: WorkProvenancePullRequestOwnerResolving {
        let ownersByURL: [String: WorkProvenancePullRequestOwner]

        func owner(for pullRequestURL: String) async -> WorkProvenancePullRequestOwner? {
            ownersByURL[pullRequestURL]
        }
    }

    private struct FakeTicketTitleResolver: WorkProvenanceTicketTitleResolving {
        let titlesByID: [String: String]

        func titles(for ticketIDs: [String]) async -> [String: String] {
            titlesByID.filter { ticketIDs.contains($0.key) }
        }
    }

    private actor FakeLinearGraphQLLoader {
        private(set) var requests: [URLRequest] = []
        let responseBody: String
        let statusCode: Int

        init(responseBody: String, statusCode: Int = 200) {
            self.responseBody = responseBody
            self.statusCode = statusCode
        }

        func load(_ request: URLRequest) -> (Data, URLResponse) {
            requests.append(request)
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://api.linear.app/graphql")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(responseBody.utf8), response)
        }
    }

    private struct StoreFixture {
        let directoryURL: URL
        let databaseURL: URL

        init() throws {
            directoryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("bmux-work-provenance-observation-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            databaseURL = directoryURL.appendingPathComponent("provenance.sqlite")
        }

        func remove() {
            try? FileManager.default.removeItem(at: directoryURL)
        }
    }

    private final class ManualCoalescerScheduler {
        private struct PendingFlush {
            var isCancelled = false
            let action: @MainActor () -> Void
        }

        private var pendingFlushes: [PendingFlush] = []
        private(set) var delays: [TimeInterval] = []

        @MainActor
        func schedule(
            delay: TimeInterval,
            action: @escaping @MainActor () -> Void
        ) -> NotificationBurstCoalescer.Cancellation {
            let index = pendingFlushes.count
            delays.append(delay)
            pendingFlushes.append(PendingFlush(action: action))
            return { [weak self] in
                self?.pendingFlushes[index].isCancelled = true
            }
        }

        @MainActor
        func fire(at index: Int) {
            guard pendingFlushes.indices.contains(index), !pendingFlushes[index].isCancelled else { return }
            pendingFlushes[index].action()
        }

        @MainActor
        func waitForPendingFlushCount(_ count: Int) async {
            for _ in 0..<50 {
                if pendingFlushes.count >= count {
                    return
                }
                await Task.yield()
            }
        }
    }

    private func workspaceDisplayRecord(
        branch: String,
        sequence: Int,
        updatedAt: Date
    ) -> ProvenanceWorkspaceDisplayRecord {
        ProvenanceWorkspaceDisplayRecord(
            id: "workspace-display-\(sequence)",
            workspaceID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            repositoryID: nil,
            worktreeID: nil,
            currentDirectory: nil,
            title: nil,
            titleSource: nil,
            branch: branch,
            pullRequestNumber: nil,
            pullRequestURL: nil,
            pullRequestOwnerLogin: nil,
            pullRequestOwnerURL: nil,
            pullRequestStatus: nil,
            pullRequestBranch: nil,
            pullRequestIsStale: false,
            isDirty: nil,
            ticketIDs: [],
            ticketLinks: [],
            latestEventID: "event-\(sequence)",
            latestEventSequence: sequence,
            observedAt: updatedAt,
            updatedAt: updatedAt
        )
    }
}
