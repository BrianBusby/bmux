import Combine
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
    func linearWebLinkBuilderBuildsCompanyCamIssueAndProjectURLs() {
        let builder = LinearWebLinkBuilder()

        #expect(builder.issueURLString(for: " inp-2122 ") == "https://linear.app/companycam/issue/INP-2122")
        #expect(builder.issueURLString(
            apiURL: " https://linear.app/companycam/issue/INP-2122 ",
            ticketID: "STE-1964"
        ) == "https://linear.app/companycam/issue/INP-2122")
        #expect(builder.projectURLString(
            forProjectSlug: " starter-template-rollout "
        ) == "https://linear.app/companycam/project/starter-template-rollout")
        #expect(builder.projectURLString(
            apiURL: " https://linear.app/companycam/project/starter-template-rollout ",
            projectSlug: "fallback-project"
        ) == "https://linear.app/companycam/project/starter-template-rollout")
    }

    @MainActor
    @Test
    func workspaceResolverSearchesAllCandidateManagersByRuntimeOrStableID() throws {
        let firstManager = TabManager(), secondManager = TabManager()
        let firstWorkspace = Workspace(title: "First Workspace"), targetWorkspace = Workspace(title: "Prompt Linked Workspace")
        firstManager.tabs = [firstWorkspace]; secondManager.tabs = [targetWorkspace]
        var immediateObservationCount = 0
        let cancellable = targetWorkspace.sidebarImmediateObservationChangeSubject.sink { immediateObservationCount += 1 }
        defer { cancellable.cancel() }
        let managers = [firstManager, secondManager]
        let match = try #require(WorkProvenanceRuntime.workspaceMatch(matching: targetWorkspace.stableId, in: managers))

        #expect(WorkProvenanceRuntime.workspace(matching: targetWorkspace.id, in: managers) === targetWorkspace)
        #expect(WorkProvenanceRuntime.workspace(matching: targetWorkspace.stableId, in: managers) === targetWorkspace)
        #expect(match.tabManager === secondManager)
        #expect(match.workspace === targetWorkspace)
        #expect(WorkProvenanceRuntime.stableWorkspaceIDs(in: managers + [secondManager]) == [firstWorkspace.stableId, targetWorkspace.stableId])
        #expect(WorkProvenanceRuntime.notifyWorkspaceDisplayCurrentStateDidChange(
            stableWorkspaceID: targetWorkspace.stableId,
            in: managers
        ))
        #expect(immediateObservationCount == 1)
    }

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
        let backingClient: any ProvenanceEngineContracts.ProvenanceEngineClient = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let client = RecordingProvenanceEngineClient(backing: backingClient)
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
            Self.linearTicketLink()
        ])
        #expect(display.display?.projectLinks == [
            Self.linearProjectLink()
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
            pullRequestOwnerResolver: FakePullRequestOwnerResolver(ownersByURL: [:]),
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
    func promptLinkedPullRequestResolvedDetailsPopulateOwnerAndTicketLinks() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let client: any ProvenanceEngineContracts.ProvenanceEngineClient = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let repositoryRoot = "/tmp/bmux-prompt-linked-pr-details-repo"
        let snapshot = WorkProvenanceGitSnapshot(
            repositoryRoot: repositoryRoot,
            commonDirectory: "\(repositoryRoot)/.git",
            remoteSlug: "CompanyCam/Company-Cam-API",
            branch: "codeowners-report-approved-status",
            headCommit: "6666666666666666666666666666666666666666",
            isDirty: false,
            statusEntries: []
        )
        let linearServer = FakeLinearGraphQLServer()
        let service = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: snapshot]),
            pullRequestOwnerResolver: FakePullRequestOwnerResolver(ownersByURL: [
                "https://github.com/CompanyCam/Company-Cam-API/pull/26171": WorkProvenancePullRequestOwner(
                    login: "BrianBusby",
                    url: "https://github.com/BrianBusby",
                    title: "INP-2122 Promote/Edit starter template Dash form cleanup",
                    branch: "inp-2122-edit-starter-template-dash-form-cleanup"
                )
            ]),
            ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                authorizationHeader: "linear-api-key",
                usesEnvironmentAuthorization: false,
                dataProvider: { request in try await linearServer.response(for: request) }
            ),
            dateProvider: { Date(timeIntervalSince1970: 555) }
        )
        let stableWorkspaceID = UUID(uuidString: "12121212-3434-5656-7878-909090909090")!
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: UUID(uuidString: "abababab-cdcd-efef-1212-343434343434")!,
            stableWorkspaceID: stableWorkspaceID,
            title: "Addressing Claude comments",
            currentDirectory: repositoryRoot,
            branch: "codeowners-report-approved-status",
            pullRequest: WorkProvenanceWorkspaceSnapshot.PullRequest(
                number: 26171,
                url: "https://github.com/CompanyCam/Company-Cam-API/pull/26171",
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
        #expect(display.display?.pullRequestNumber == 26171)
        #expect(display.display?.pullRequestURL == "https://github.com/CompanyCam/Company-Cam-API/pull/26171")
        #expect(display.display?.pullRequestOwnerLogin == "BrianBusby")
        #expect(display.display?.pullRequestOwnerURL == "https://github.com/BrianBusby")
        #expect(display.display?.pullRequestBranch == "inp-2122-edit-starter-template-dash-form-cleanup")
        #expect(display.display?.ticketIDs == ["INP-2122"])
        #expect(display.display?.ticketLinks == [
            Self.linearTicketLink(id: "INP-2122")
        ])
        #expect(display.display?.projectLinks == [
            Self.linearProjectLink()
        ])
        let displayRecord = try #require(display.display)
        let displaySnapshot = try #require(WorkspaceDisplayCurrentStateSnapshot(displayRecord))
        let ticketLink = try #require(displaySnapshot.ticketLinks.first)
        let projectLink = try #require(displaySnapshot.projectLinks.first)
        let sidebarTicket = SidebarWorkspaceSnapshotBuilder.TicketDisplay(
            id: ticketLink.id,
            title: ticketLink.title,
            url: ticketLink.url
        )
        let sidebarProject = SidebarWorkspaceSnapshotBuilder.ProjectDisplay(
            id: projectLink.id,
            title: projectLink.title,
            url: projectLink.url
        )
        #expect(ticketLink.url == URL(string: "https://linear.app/companycam/issue/INP-2122"))
        #expect(sidebarTicket.linkText == "INP-2122: Canonical domain mutation paths")
        #expect(projectLink.url == URL(string: "https://linear.app/companycam/project/context-efficiency-c1b9a"))
        #expect(sidebarProject.linkText == "Context Efficiency")
        #expect(await linearServer.requests == [
            FakeLinearGraphQLServer.Request(authorization: "linear-api-key", ticketID: "INP-2122")
        ])
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
            Self.linearTicketLink()
        ])
        #expect(display.display?.projectLinks == [
            Self.linearProjectLink()
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
            Self.linearTicketLink()
        ])
        #expect(display.display?.projectLinks == [
            Self.linearProjectLink()
        ])
    }

    @Test
    func laterTicketLookupFailurePreservesExistingTicketTitleAndOwner() async throws {
        let fixture = try StoreFixture()
        defer { fixture.remove() }
        let backingClient: any ProvenanceEngineContracts.ProvenanceEngineClient = try ProvenanceEngineClientFactory().sqliteClient(databaseURL: fixture.databaseURL)
        let client = RecordingProvenanceEngineClient(backing: backingClient)
        let repositoryRoot = "/tmp/bmux-ticket-link-lookup-failure-repo"
        let branch = "durable-ticket-link-preserve"
        let linearServer = FakeLinearGraphQLServer()
        let snapshot = WorkProvenanceGitSnapshot(
            repositoryRoot: repositoryRoot,
            commonDirectory: "\(repositoryRoot)/.git",
            remoteSlug: "manaflow-ai/bmux",
            branch: branch,
            headCommit: "5555555555555555555555555555555555555555",
            isDirty: false,
            statusEntries: []
        )
        let stableWorkspaceID = UUID(uuidString: "dddddddd-eeee-ffff-aaaa-bbbbbbbbbbbb")!
        let workspaceID = UUID(uuidString: "eeeeeeee-ffff-aaaa-bbbb-cccccccccccc")!
        let initialService = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: snapshot]),
            ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                authorizationHeader: "linear-api-key",
                usesEnvironmentAuthorization: false,
                dataProvider: { request in try await linearServer.response(for: request) }
            ),
            dateProvider: { Date(timeIntervalSince1970: 580) }
        )
        let retryService = WorkProvenanceObservationService(
            client: client,
            gitInspector: FakeGitInspector(snapshotsByDirectory: [repositoryRoot: snapshot]),
            ticketLinkResolver: WorkProvenanceLinearTicketLinkResolver(
                authorizationHeader: nil,
                usesEnvironmentAuthorization: false
            ),
            dateProvider: { Date(timeIntervalSince1970: 581) }
        )
        let workspace = WorkProvenanceWorkspaceSnapshot(
            workspaceID: workspaceID,
            stableWorkspaceID: stableWorkspaceID,
            title: "Retry Linear lookup",
            currentDirectory: repositoryRoot,
            branch: branch,
            pullRequest: WorkProvenanceWorkspaceSnapshot.PullRequest(
                number: 43,
                title: "STE-1964 Retry Linear lookup",
                url: "https://github.com/manaflow-ai/bmux/pull/43",
                ownerLogin: nil,
                ownerURL: nil,
                status: "open",
                branch: branch,
                isStale: false
            )
        )

        await initialService.observeWorkspaceSnapshot(workspace)
        await retryService.observeWorkspaceSnapshot(workspace)

        let display = try await client.workspaceDisplay(ProvenanceWorkspaceDisplayRequest(workspaceID: stableWorkspaceID.uuidString))
        let latestEvent = try #require(await client.appendedEvents().last?.payload.workspaceDisplay)

        #expect(display.found)
        #expect(display.display?.ticketIDs == ["STE-1964"])
        #expect(display.display?.ticketLinks == [
            Self.linearTicketLink()
        ])
        #expect(display.display?.projectLinks == [
            Self.linearProjectLink()
        ])
        #expect(latestEvent.ticketIDs == ["STE-1964"])
        #expect(latestEvent.ticketLinks == [
            Self.linearTicketLink()
        ])
        #expect(latestEvent.projectLinks == [
            Self.linearProjectLink()
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
        #expect(display.display?.projectLinks == [])
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

    private actor RecordingProvenanceEngineClient: ProvenanceEngineContracts.ProvenanceEngineClient {
        private let backing: any ProvenanceEngineContracts.ProvenanceEngineClient
        private var events: [ProvenanceEngineContracts.ProvenanceEvent] = []

        init(backing: any ProvenanceEngineContracts.ProvenanceEngineClient) {
            self.backing = backing
        }

        func appendedEvents() -> [ProvenanceEngineContracts.ProvenanceEvent] {
            events
        }

        func health() async throws -> ProvenanceEngineContracts.ProvenanceEngineHealth {
            try await backing.health()
        }

        func appendEvent(
            _ request: ProvenanceEngineContracts.ProvenanceAppendEventRequest
        ) async throws -> ProvenanceEngineContracts.ProvenanceAppendEventResponse {
            events.append(request.event)
            return try await backing.appendEvent(request)
        }

        func recordSessionLifecycle(
            _ request: ProvenanceEngineContracts.ProvenanceSessionLifecycleRequest
        ) async -> ProvenanceEngineContracts.ProvenanceSessionLifecycleResponse {
            await backing.recordSessionLifecycle(request)
        }

        func sessionTree(
            _ request: ProvenanceEngineContracts.ProvenanceSessionTreeRequest
        ) async throws -> ProvenanceEngineContracts.ProvenanceSessionTreeResponse {
            try await backing.sessionTree(request)
        }

        func fileExplanation(
            _ request: ProvenanceEngineContracts.ProvenanceFileExplanationRequest
        ) async throws -> ProvenanceEngineContracts.ProvenanceFileExplanationResponse {
            try await backing.fileExplanation(request)
        }

        func worktrees(
            _ request: ProvenanceEngineContracts.ProvenanceWorktreeListRequest
        ) async throws -> ProvenanceEngineContracts.ProvenanceWorktreeListResponse {
            try await backing.worktrees(request)
        }

        func currentContext(
            _ request: ProvenanceEngineContracts.ProvenanceCurrentContextRequest
        ) async throws -> ProvenanceEngineContracts.ProvenanceCurrentContextResponse {
            try await backing.currentContext(request)
        }

        func workspaceDisplay(
            _ request: ProvenanceEngineContracts.ProvenanceWorkspaceDisplayRequest
        ) async throws -> ProvenanceEngineContracts.ProvenanceWorkspaceDisplayResponse {
            try await backing.workspaceDisplay(request)
        }

        func factualSessionProjection(
            _ request: ProvenanceEngineContracts.ProvenanceFactualSessionProjectionRequest
        ) async throws -> ProvenanceEngineContracts.ProvenanceFactualSessionProjectionResponse {
            try await backing.factualSessionProjection(request)
        }
    }

    private static func linearTicketLink(id: String = "STE-1964") -> ProvenanceWorkspaceDisplayTicketLinkRecord {
        ProvenanceWorkspaceDisplayTicketLinkRecord(
            id: id,
            system: "linear",
            title: "Canonical domain mutation paths",
            url: "https://linear.app/companycam/issue/\(id)",
            ownerName: "Brian Busby"
        )
    }

    private static func linearProjectLink() -> ProvenanceWorkspaceDisplayProjectLinkRecord {
        ProvenanceWorkspaceDisplayProjectLinkRecord(
            id: "context-efficiency-c1b9a",
            system: "linear",
            title: "Context Efficiency",
            url: "https://linear.app/companycam/project/context-efficiency-c1b9a"
        )
    }

    private actor FakeLinearGraphQLServer {
        struct Request: Equatable, Sendable {
            let authorization: String?
            let ticketID: String?
            let requestedURL: Bool

            init(authorization: String?, ticketID: String?, requestedURL: Bool = true) {
                self.authorization = authorization
                self.ticketID = ticketID
                self.requestedURL = requestedURL
            }
        }

        private(set) var requests: [Request] = []

        func response(for request: URLRequest) throws -> (Data, Int) {
            let issueRequest = try Self.issueRequest(from: request.httpBody)
            requests.append(Request(
                authorization: request.value(forHTTPHeaderField: "Authorization"),
                ticketID: issueRequest.ticketID,
                requestedURL: issueRequest.requestedURL
            ))
            let fallbackTicketID = issueRequest.ticketID ?? "STE-1964"
            let payload = """
            {"data":{"issue":{"title":"Canonical domain mutation paths","url":"https://linear.app/companycam/issue/\(fallbackTicketID)","assignee":{"name":"Brian Busby"},"project":{"id":"linear-project-1","name":"Context Efficiency","url":"https://linear.app/companycam/project/context-efficiency-c1b9a","slugId":"context-efficiency-c1b9a"}}}}
            """
            return (Data(payload.utf8), 200)
        }

        private static func issueRequest(from data: Data?) throws -> (ticketID: String?, requestedURL: Bool) {
            guard let data else { return (ticketID: nil, requestedURL: false) }
            let json = try JSONSerialization.jsonObject(with: data)
            guard let object = json as? [String: Any],
                  let variables = object["variables"] as? [String: Any] else {
                return (ticketID: nil, requestedURL: false)
            }
            let query = object["query"] as? String
            return (
                ticketID: variables["id"] as? String,
                requestedURL: query?.contains("url") ?? false
            )
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
}
