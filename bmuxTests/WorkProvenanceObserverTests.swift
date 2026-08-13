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
    func observeWorkspaceDisplayPersistsTitlePullRequestAndRawEvidenceWhenGitIsUnchanged() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let repositoryRoot = "/tmp/bmux-display-observed-repo"
        let linearServer = FakeLinearGraphQLServer()
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
            ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                authorizationHeader: "linear-api-key",
                usesEnvironmentAuthorization: false,
                dataProvider: { request in try await linearServer.response(for: request) }
            ),
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
            ),
            currentWorkSummary: "Preparing initial display state",
            lastSubmittedPrompt: "Open PR 41 for the workspace",
            lastSubmittedPromptSubmittedAt: Date(timeIntervalSince1970: 490)
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
            ),
            currentWorkSummary: "Reviewing durable workspace display",
            lastSubmittedPrompt: "Update the workspace details panel",
            lastSubmittedPromptSubmittedAt: Date(timeIntervalSince1970: 501)
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
        #expect(display.display?.currentWorkSummary == "Reviewing durable workspace display")
        #expect(display.display?.lastSubmittedPrompt == "Update the workspace details panel")
        #expect(display.display?.lastSubmittedPromptSubmittedAt == Date(timeIntervalSince1970: 501))
        #expect(display.display?.latestEventID != nil)
        #expect(display.display?.latestEventSequence == 3)
        #expect(display.display?.ticketIDs == ["STE-1964"])
        #expect(display.display?.ticketLinks == [
            ProvenanceWorkspaceDisplayTicketLinkRecord(
                id: "STE-1964",
                system: "linear",
                title: "Canonical domain mutation paths",
                url: "https://linear.app/company/issue/STE-1964",
                ownerName: "Brian Busby"
            )
        ])
        #expect(await linearServer.requests == [
            FakeLinearGraphQLServer.Request(authorization: "linear-api-key", ticketID: "STE-1964")
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

        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(workspaceID: stableWorkspaceID.uuidString))

        #expect(display.found)
        #expect(display.display?.branch == "ste-1967-send-company-industry-key-to-amplitude-pr26096")
        #expect(display.display?.pullRequestNumber == 26117)
        #expect(display.display?.pullRequestURL == "https://github.com/CompanyCam/Company-Cam-API/pull/26117")
        #expect(display.display?.pullRequestBranch == nil)
        #expect(display.display?.ticketIDs == [] && display.display?.ticketLinks == [])
    }

    @Test
    func pullRequestTitleTicketEvidencePopulatesTicketLinksWhenBranchHasNoTicketKey() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let repositoryRoot = "/tmp/bmux-pr-title-ticket-repo"
        let branch = "canonical-domain-mutation-paths"
        let linearServer = FakeLinearGraphQLServer()
        let snapshot = WorkProvenanceGitSnapshot(
            repositoryRoot: repositoryRoot,
            commonDirectory: "\(repositoryRoot)/.git",
            remoteSlug: "manaflow-ai/bmux",
            branch: branch,
            headCommit: "4444444444444444444444444444444444444444",
            isDirty: false,
            statusEntries: []
        )
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: snapshot]),
            ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                authorizationHeader: "linear-api-key",
                usesEnvironmentAuthorization: false,
                dataProvider: { request in try await linearServer.response(for: request) }
            ),
            dateProvider: { Date(timeIntervalSince1970: 565) }
        )
        let stableWorkspaceID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!,
            stableWorkspaceID: stableWorkspaceID,
            title: "Persist Linear ticket titles in provenance",
            currentDirectory: repositoryRoot,
            branch: branch,
            pullRequest: WorkProvenanceWorkspaceSnapshot.PullRequest(
                number: 38,
                title: "STE-1964 Persist Linear ticket titles in provenance",
                url: "https://github.com/manaflow-ai/bmux/pull/38",
                ownerLogin: nil,
                ownerURL: nil,
                status: "open",
                branch: branch,
                isStale: false
            )
        )

        await service.observeWorkspaceSnapshot(workspace)

        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(workspaceID: stableWorkspaceID.uuidString))

        #expect(display.found)
        #expect(display.display?.branch == branch)
        #expect(display.display?.pullRequestBranch == branch)
        #expect(display.display?.ticketIDs == ["STE-1964"])
        #expect(display.display?.ticketLinks == [
            ProvenanceWorkspaceDisplayTicketLinkRecord(
                id: "STE-1964",
                system: "linear",
                title: "Canonical domain mutation paths",
                url: "https://linear.app/company/issue/STE-1964",
                ownerName: "Brian Busby"
            )
        ])
        #expect(await linearServer.requests == [
            FakeLinearGraphQLServer.Request(authorization: "linear-api-key", ticketID: "STE-1964")
        ])
    }

    @Test
    func laterPromptDisplayObservationPreservesExistingTicketLinksWhenNoNewTicketEvidenceExists() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let repositoryRoot = "/tmp/bmux-ticket-link-preserve-repo"
        let branch = "ste-1964-canonical-domain-mutation-paths"
        let linearServer = FakeLinearGraphQLServer()
        let snapshot = WorkProvenanceGitSnapshot(
            repositoryRoot: repositoryRoot,
            commonDirectory: "\(repositoryRoot)/.git",
            remoteSlug: "manaflow-ai/bmux",
            branch: branch,
            headCommit: "3333333333333333333333333333333333333333",
            isDirty: false,
            statusEntries: []
        )
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: snapshot]),
            ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                authorizationHeader: "linear-api-key",
                usesEnvironmentAuthorization: false,
                dataProvider: { request in try await linearServer.response(for: request) }
            ),
            dateProvider: { Date(timeIntervalSince1970: 570) }
        )
        let workspaceID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let stableWorkspaceID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
        let initialWorkspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: workspaceID,
            stableWorkspaceID: stableWorkspaceID,
            title: "Initial prompt",
            currentDirectory: repositoryRoot,
            branch: branch,
            pullRequest: WorkProvenanceWorkspaceSnapshot.PullRequest(
                number: 42,
                url: "https://github.com/manaflow-ai/bmux/pull/42",
                ownerLogin: nil,
                ownerURL: nil,
                status: "open",
                branch: branch,
                isStale: false
            )
        )
        let laterPromptWorkspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: workspaceID,
            stableWorkspaceID: stableWorkspaceID,
            title: "Later prompt without ticket evidence",
            currentDirectory: repositoryRoot,
            branch: branch,
            lastSubmittedPrompt: "Continue without new ticket evidence",
            lastSubmittedPromptSubmittedAt: Date(timeIntervalSince1970: 571)
        )

        await service.observeWorkspaceSnapshot(initialWorkspace)
        await service.observeWorkspaceSnapshot(laterPromptWorkspace)

        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(workspaceID: stableWorkspaceID.uuidString))

        #expect(display.found)
        #expect(display.display?.title == "Later prompt without ticket evidence")
        #expect(display.display?.pullRequestNumber == 42)
        #expect(display.display?.pullRequestURL == "https://github.com/manaflow-ai/bmux/pull/42")
        #expect(display.display?.lastSubmittedPrompt == "Continue without new ticket evidence")
        #expect(display.display?.lastSubmittedPromptSubmittedAt == Date(timeIntervalSince1970: 571))
        #expect(display.display?.ticketIDs == ["STE-1964"])
        #expect(display.display?.ticketLinks == [
            ProvenanceWorkspaceDisplayTicketLinkRecord(
                id: "STE-1964",
                system: "linear",
                title: "Canonical domain mutation paths",
                url: "https://linear.app/company/issue/STE-1964",
                ownerName: "Brian Busby"
            )
        ])
    }

    @Test
    func ambientBranchTicketDoesNotPopulateBranchOnlyWorkspaceDisplay() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let repositoryRoot = "/tmp/bmux-ambient-branch-ticket-repo"
        let branch = "ste-1967-send-company-industry-key-to-amplitude-pr26096"
        let snapshot = WorkProvenanceGitSnapshot(
            repositoryRoot: repositoryRoot,
            commonDirectory: "\(repositoryRoot)/.git",
            remoteSlug: "CompanyCam/Company-Cam-API",
            branch: branch,
            headCommit: "2222222222222222222222222222222222222222",
            isDirty: false,
            statusEntries: []
        )
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: snapshot]),
            dateProvider: { Date(timeIntervalSince1970: 560) }
        )
        let stableWorkspaceID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(uuidString: "ffffffff-eeee-dddd-cccc-bbbbbbbbbbbb")!,
            stableWorkspaceID: stableWorkspaceID,
            title: "Company-Cam-API",
            currentDirectory: repositoryRoot,
            branch: branch
        )

        await service.observeWorkspaceSnapshot(workspace)

        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(workspaceID: stableWorkspaceID.uuidString))
        #expect(display.found)
        #expect(display.display?.branch == branch)
        #expect(display.display?.pullRequestNumber == nil)
        #expect(display.display?.ticketIDs == [])
        #expect(display.display?.ticketLinks == [])
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
                    url: "https://linear.app/company/issue/STE-1964",
                    ownerName: " Brian Busby ",
                    ownerURL: " https://linear.app/company/user/brian "
                )
            ],
            currentWorkSummary: " Durable context reconciliation ",
            lastSubmittedPrompt: " Keep these facts visible ",
            lastSubmittedPromptSubmittedAt: Date(timeIntervalSince1970: 701),
            lastSubmittedPromptSessionID: " session-1 ",
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
        #expect(snapshot.ticketLinks.first?.ownerName == "Brian Busby")
        #expect(snapshot.ticketLinks.first?.ownerURL == URL(string: "https://linear.app/company/user/brian"))
        #expect(snapshot.ticketLinks.last?.system == "linear")
        #expect(snapshot.ticketLinks.last?.title == nil)
        #expect(snapshot.ticketLinks.last?.url == URL(string: "https://linear.app/company/issue/GH-57"))
        #expect(snapshot.currentWorkSummary == "Durable context reconciliation")
        #expect(snapshot.lastSubmittedPrompt == "Keep these facts visible")
        #expect(snapshot.lastSubmittedPromptSubmittedAt == Date(timeIntervalSince1970: 701))
        #expect(snapshot.lastSubmittedPromptSessionID == "session-1")
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

    private actor FakeLinearGraphQLServer {
        struct Request: Equatable, Sendable { let authorization: String?; let ticketID: String? }

        private(set) var requests: [Request] = []

        func response(for request: URLRequest) throws -> (Data, Int) {
            let ticketID = try Self.ticketID(from: request.httpBody)
            requests.append(Request(authorization: request.value(forHTTPHeaderField: "Authorization"), ticketID: ticketID))
            let payload = #"{"data":{"issue":{"title":"Canonical domain mutation paths","assignee":{"name":"Brian Busby"}}}}"#
            return (Data(payload.utf8), 200)
        }

        private static func ticketID(from data: Data?) throws -> String? {
            guard let data else { return nil }
            let json = try JSONSerialization.jsonObject(with: data)
            guard let object = json as? [String: Any],
                  let variables = object["variables"] as? [String: Any] else {
                return nil
            }
            return variables["id"] as? String
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

    private func workspaceDisplayRecord(
        branch: String,
        sequence: Int,
        updatedAt: Date
    ) -> ProvenanceWorkspaceDisplayRecord {
        ProvenanceWorkspaceDisplayRecord(
            id: "workspace-display-\(sequence)",
            workspaceID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            repositoryID: nil, worktreeID: nil, currentDirectory: nil, title: nil, titleSource: nil,
            branch: branch,
            pullRequestNumber: nil, pullRequestURL: nil, pullRequestOwnerLogin: nil, pullRequestOwnerURL: nil, pullRequestStatus: nil, pullRequestBranch: nil,
            pullRequestIsStale: false,
            isDirty: nil, ticketIDs: [], ticketLinks: [],
            latestEventID: "event-\(sequence)",
            latestEventSequence: sequence,
            observedAt: updatedAt,
            updatedAt: updatedAt
        )
    }
}
