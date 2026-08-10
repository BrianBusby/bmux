import Combine
import Foundation
import Testing

@testable import BmuxSidebar

private struct WorkContextFixedLogLimitProvider: SidebarLogEntryLimitProviding {
    let configuredMaxSidebarLogEntries: Int?
}

@Suite struct WorkspaceWorkContextTests {
    @Test func explicitContextRepresentsBranchRemotePullRequestTicketAndStaleness() throws {
        let remoteURL = try #require(URL(string: "https://github.com/manaflow-ai/bmux.git"))
        let pullRequestURL = try #require(URL(string: "https://github.com/manaflow-ai/bmux/pull/25095"))
        let ticketURL = try #require(URL(string: "https://linear.app/manaflow/issue/STE-25095"))

        let context = WorkspaceWorkContext(
            branch: WorkspaceWorkContextBranch(
                name: "ste-25095-work-context",
                isDirty: true,
                source: .gitBranchReport,
                isStale: false
            ),
            repositoryRemote: WorkspaceWorkContextRepositoryRemote(
                slug: "manaflow-ai/bmux",
                url: remoteURL,
                source: .gitBranchReport
            ),
            pullRequest: WorkspaceWorkContextPullRequest(
                number: 25095,
                label: "manaflow-ai/bmux",
                url: pullRequestURL,
                ownerLogin: "octocat",
                ownerURL: URL(string: "https://github.com/octocat")!,
                status: .open,
                branch: "ste-25095-work-context",
                source: .pullRequestLookup,
                isStale: true
            ),
            ticket: WorkspaceWorkContextTicket(
                key: "STE-25095",
                number: 25095,
                url: ticketURL,
                source: .branchName
            )
        )

        #expect(context.branch?.name == "ste-25095-work-context")
        #expect(context.repositoryRemote?.slug == "manaflow-ai/bmux")
        #expect(context.pullRequest?.number == 25095)
        #expect(context.pullRequest?.ownerLogin == "octocat")
        #expect(context.pullRequest?.ownerURL?.absoluteString == "https://github.com/octocat")
        #expect(context.pullRequest?.isStale == true)
        #expect(context.ticket?.key == "STE-25095")
        #expect(context.ticket?.number == 25095)
    }

    @Test func sidebarProjectionPreservesCurrentBranchAndPullRequestIdentity() throws {
        let pullRequestURL = try #require(URL(string: "https://github.com/manaflow-ai/bmux/pull/25095"))
        let context = WorkspaceWorkContext(
            sidebarBranch: SidebarGitBranchState(branch: " ste-25095-work-context ", isDirty: false),
            sidebarPullRequest: SidebarPullRequestState(
                number: 25095,
                label: "manaflow-ai/bmux",
                url: pullRequestURL,
                ownerLogin: "octocat",
                ownerURL: URL(string: "https://github.com/octocat")!,
                status: .open,
                branch: " ste-25095-work-context ",
                isStale: true
            )
        )

        #expect(context.branch?.name == " ste-25095-work-context ")
        #expect(context.branch?.source == .sidebarMetadata)
        #expect(context.pullRequest?.number == 25095)
        #expect(context.pullRequest?.url == pullRequestURL)
        #expect(context.pullRequest?.ownerLogin == "octocat")
        #expect(context.pullRequest?.ownerURL?.absoluteString == "https://github.com/octocat")
        #expect(context.pullRequest?.branch == "ste-25095-work-context")
        #expect(context.pullRequest?.source == .sidebarMetadata)
        #expect(context.pullRequest?.isStale == true)
    }

    @MainActor
    @Test func metadataModelProjectsWorkspaceAndPanelWorkContext() throws {
        let model = WorkspaceSidebarMetadataModel(
            limitProvider: WorkContextFixedLogLimitProvider(configuredMaxSidebarLogEntries: nil)
        )
        let panelId = UUID()
        let pullRequestURL = try #require(URL(string: "https://github.com/manaflow-ai/bmux/pull/25095"))

        model.gitBranch = SidebarGitBranchState(branch: "main", isDirty: false)
        model.pullRequest = SidebarPullRequestState(
            number: 1,
            label: "manaflow-ai/bmux",
            url: try #require(URL(string: "https://github.com/manaflow-ai/bmux/pull/1")),
            status: .closed
        )
        model.panelGitBranches[panelId] = SidebarGitBranchState(branch: "ste-25095-work-context", isDirty: true)
        model.panelPullRequests[panelId] = SidebarPullRequestState(
            number: 25095,
            label: "manaflow-ai/bmux",
            url: pullRequestURL,
            status: .open,
            branch: "ste-25095-work-context"
        )

        #expect(model.workContext.branch?.name == "main")
        #expect(model.workContext.pullRequest?.number == 1)

        let panelContext = model.workContext(panelId: panelId)
        #expect(panelContext.branch?.name == "ste-25095-work-context")
        #expect(panelContext.branch?.isDirty == true)
        #expect(panelContext.pullRequest?.number == 25095)
        #expect(panelContext.pullRequest?.url == pullRequestURL)
    }

    @MainActor
    @Test func metadataModelProjectsPromptMentionPullRequestSourceWithoutChangingLegacyState() throws {
        let model = WorkspaceSidebarMetadataModel(
            limitProvider: WorkContextFixedLogLimitProvider(configuredMaxSidebarLogEntries: nil)
        )
        let panelId = UUID()
        let pullRequest = SidebarPullRequestState(
            number: 25095,
            label: "PR",
            url: try #require(URL(string: "https://github.com/manaflow-ai/bmux/pull/25095")),
            status: .open,
            branch: nil
        )

        model.updatePanelPullRequest(
            pullRequest,
            panelId: panelId,
            source: .promptMention
        )
        model.updatePullRequest(pullRequest, source: .promptMention)

        #expect(model.panelPullRequests[panelId] == pullRequest)
        #expect(model.pullRequest == pullRequest)
        #expect(model.workContext(panelId: panelId).pullRequest?.source == .promptMention)
        #expect(model.workContext.pullRequest?.source == .promptMention)

        model.updatePanelPullRequestSource(panelId: panelId, source: .sidebarMetadata)
        model.updatePullRequestSource(.sidebarMetadata)

        #expect(model.panelPullRequests[panelId] == pullRequest)
        #expect(model.pullRequest == pullRequest)
        #expect(model.workContext(panelId: panelId).pullRequest?.source == .sidebarMetadata)
        #expect(model.workContext.pullRequest?.source == .sidebarMetadata)
    }

    @MainActor
    @Test func promptMentionSourceIsVisibleDuringWorkspacePullRequestPublisherPulse() throws {
        let model = WorkspaceSidebarMetadataModel(
            limitProvider: WorkContextFixedLogLimitProvider(configuredMaxSidebarLogEntries: nil)
        )
        let promptPullRequest = SidebarPullRequestState(
            number: 25095,
            label: "PR",
            url: try #require(URL(string: "https://github.com/manaflow-ai/bmux/pull/25095")),
            status: .open
        )
        let legacyPullRequest = SidebarPullRequestState(
            number: 25194,
            label: "PR",
            url: try #require(URL(string: "https://github.com/manaflow-ai/bmux/pull/25194")),
            status: .open
        )

        var observedSources: [WorkspaceWorkContextSource?] = []
        let cancellable = model.pullRequestPublisher
            .dropFirst()
            .sink { _ in observedSources.append(model.workContext.pullRequest?.source) }
        defer { cancellable.cancel() }

        model.updatePullRequest(promptPullRequest, source: .promptMention)
        model.pullRequest = legacyPullRequest

        #expect(observedSources == [.promptMention, .sidebarMetadata])
    }

    @MainActor
    @Test func promptMentionSourceIsVisibleDuringPanelPullRequestsPublisherPulse() throws {
        let model = WorkspaceSidebarMetadataModel(
            limitProvider: WorkContextFixedLogLimitProvider(configuredMaxSidebarLogEntries: nil)
        )
        let panelId = UUID()
        let promptPullRequest = SidebarPullRequestState(
            number: 25095,
            label: "PR",
            url: try #require(URL(string: "https://github.com/manaflow-ai/bmux/pull/25095")),
            status: .open
        )
        let legacyPullRequest = SidebarPullRequestState(
            number: 25194,
            label: "PR",
            url: try #require(URL(string: "https://github.com/manaflow-ai/bmux/pull/25194")),
            status: .open
        )

        var observedSources: [WorkspaceWorkContextSource?] = []
        let cancellable = model.panelPullRequestsPublisher
            .dropFirst()
            .sink { _ in observedSources.append(model.workContext(panelId: panelId).pullRequest?.source) }
        defer { cancellable.cancel() }

        model.updatePanelPullRequest(promptPullRequest, panelId: panelId, source: .promptMention)
        model.panelPullRequests[panelId] = legacyPullRequest

        #expect(observedSources == [.promptMention, .sidebarMetadata])
    }

    @MainActor
    @Test func directLegacyPullRequestWritesProjectSidebarMetadataSource() throws {
        let model = WorkspaceSidebarMetadataModel(
            limitProvider: WorkContextFixedLogLimitProvider(configuredMaxSidebarLogEntries: nil)
        )
        let panelId = UUID()
        let pullRequest = SidebarPullRequestState(
            number: 25095,
            label: "PR",
            url: try #require(URL(string: "https://github.com/manaflow-ai/bmux/pull/25095")),
            status: .open
        )

        model.panelPullRequests[panelId] = pullRequest
        model.pullRequest = pullRequest

        #expect(model.workContext(panelId: panelId).pullRequest?.source == .sidebarMetadata)
        #expect(model.workContext.pullRequest?.source == .sidebarMetadata)
    }

    @Test func sidebarProjectionMarksBranchMismatchedPullRequestStale() throws {
        let context = WorkspaceWorkContext(
            sidebarBranch: SidebarGitBranchState(branch: "ste-25095-current", isDirty: false),
            sidebarPullRequest: SidebarPullRequestState(
                number: 25095,
                label: "PR",
                url: try #require(URL(string: "https://github.com/manaflow-ai/bmux/pull/25095")),
                status: .open,
                branch: "ste-25194-old"
            )
        )

        #expect(context.pullRequest?.isStale == true)
        #expect(context.pullRequest?.source == .sidebarMetadata)
    }

    @Test(arguments: [
        ("ste-1234-add-thing", "STE-1234", 1234),
        ("STE-1234-add-thing", "STE-1234", 1234),
        ("feature/ste-1234-add-thing", "STE-1234", 1234),
        ("ste_1234_add_thing", "STE-1234", 1234),
        ("ste/1234/add-thing", "STE-1234", 1234),
        ("users/brian/cc1-42-work", "CC1-42", 42),
    ])
    func branchTicketExtractionNormalizesCommonTicketForms(
        branchName: String,
        expectedKey: String,
        expectedNumber: Int
    ) throws {
        let ticket = try #require(WorkspaceWorkContextTicket(branchName: branchName))

        #expect(ticket.key == expectedKey)
        #expect(ticket.number == expectedNumber)
        #expect(ticket.url == nil)
        #expect(ticket.source == .branchName)
        #expect(ticket.isStale == false)
    }

    @Test(arguments: [
        "main",
        "feature/no-ticket",
        "feature-1234",
        "release-2026-07-18",
        "s-1234-too-short",
        "ste-1234a",
    ])
    func branchTicketExtractionIgnoresBranchesWithoutTicketKeys(branchName: String) {
        #expect(WorkspaceWorkContextTicket(branchName: branchName) == nil)
    }

    @MainActor
    @Test func metadataModelProjectsBranchDerivedTicketsForWorkspaceAndPanelContext() {
        let model = WorkspaceSidebarMetadataModel(
            limitProvider: WorkContextFixedLogLimitProvider(configuredMaxSidebarLogEntries: nil)
        )
        let panelId = UUID()

        model.gitBranch = SidebarGitBranchState(branch: "STE-1234-add-thing", isDirty: false)
        model.panelGitBranches[panelId] = SidebarGitBranchState(branch: "feature/ste_5678-add-thing", isDirty: true)

        #expect(model.workContext.ticket?.key == "STE-1234")
        #expect(model.workContext.ticket?.number == 1234)
        #expect(model.workContext.ticket?.source == .branchName)

        let panelContext = model.workContext(panelId: panelId)
        #expect(panelContext.ticket?.key == "STE-5678")
        #expect(panelContext.ticket?.number == 5678)
        #expect(panelContext.ticket?.source == .branchName)
    }

    @Test func pullRequestLookupRequestProjectsRepositoryAndBranchWithoutPerformingLookup() throws {
        let remoteURL = try #require(URL(string: "https://github.com/manaflow-ai/bmux.git"))
        let context = WorkspaceWorkContext(
            branch: WorkspaceWorkContextBranch(
                name: " ste-25095-work-context ",
                isDirty: false,
                source: .gitBranchReport
            ),
            repositoryRemote: WorkspaceWorkContextRepositoryRemote(
                slug: "manaflow-ai/bmux",
                url: remoteURL,
                source: .gitBranchReport
            )
        )

        let request = try #require(context.pullRequestLookupRequest)
        #expect(request.repositoryRemote.slug == "manaflow-ai/bmux")
        #expect(request.repositoryRemote.url == remoteURL)
        #expect(request.branch == "ste-25095-work-context")
        #expect(request.source == .gitBranchReport)
    }

    @Test func pullRequestLookupRequestRequiresFreshRepositoryAndBranchContext() throws {
        let remoteURL = URL(string: "https://github.com/manaflow-ai/bmux.git")!
        let remote = WorkspaceWorkContextRepositoryRemote(
            slug: "manaflow-ai/bmux",
            url: remoteURL,
            source: .gitBranchReport
        )
        let branch = WorkspaceWorkContextBranch(
            name: "ste-25095-work-context",
            isDirty: false,
            source: .gitBranchReport
        )

        #expect(WorkspaceWorkContext(repositoryRemote: remote).pullRequestLookupRequest == nil)
        #expect(WorkspaceWorkContext(branch: branch).pullRequestLookupRequest == nil)
        #expect(
            WorkspaceWorkContext(
                branch: WorkspaceWorkContextBranch(
                    name: "ste-25095-work-context",
                    isDirty: false,
                    source: .gitBranchReport,
                    isStale: true
                ),
                repositoryRemote: remote
            ).pullRequestLookupRequest == nil
        )
        #expect(
            WorkspaceWorkContext(
                branch: branch,
                repositoryRemote: WorkspaceWorkContextRepositoryRemote(
                    slug: "manaflow-ai/bmux",
                    url: nil,
                    source: .gitBranchReport,
                    isStale: true
                )
            ).pullRequestLookupRequest == nil
        )
    }
}
