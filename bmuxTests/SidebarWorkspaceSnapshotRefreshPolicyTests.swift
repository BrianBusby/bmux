import AppKit
import BmuxSidebar
import BmuxWorkspaces
import ProvenanceEngineContracts
import SwiftUI
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite struct SidebarWorkspaceSnapshotRefreshPolicyTests {
    @Test func contextMenuPinChangeUpdatesDisplayedFieldsAndDefersNoisyFields() {
        let current = Self.snapshot(
            title: "lmao",
            isPinned: false,
            customColorHex: nil,
            remoteConnectionStatusText: "Connected",
            latestConversationMessage: "old message",
            listeningPorts: [3000],
            finderDirectoryPath: "/old"
        )
        let next = Self.snapshot(
            title: "lmao",
            isPinned: true,
            customColorHex: nil,
            remoteConnectionStatusText: "Disconnected",
            latestConversationMessage: "new message",
            listeningPorts: [3000, 4000],
            finderDirectoryPath: nil
        )

        let decision = SidebarWorkspaceSnapshotRefreshPolicy().decision(
            current: current,
            next: next,
            force: false,
            contextMenuVisible: true
        )

        var expectedDisplayed = current
        expectedDisplayed = expectedDisplayed.applyingContextMenuImmediateFields(from: next)
        #expect(decision.workspaceSnapshotStorage == expectedDisplayed)
        #expect(decision.workspaceSnapshotStorage?.isPinned == true)
        #expect(decision.workspaceSnapshotStorage?.remoteConnectionStatusText == "Connected")
        #expect(decision.workspaceSnapshotStorage?.latestConversationMessage == "old message")
        #expect(decision.workspaceSnapshotStorage?.listeningPorts == [3000])
        #expect(decision.workspaceSnapshotStorage?.finderDirectoryPath == nil)
        #expect(decision.pendingWorkspaceSnapshot == next)
        #expect(decision.hasDeferredWorkspaceObservationInvalidation)
    }

    @Test func contextMenuImmediateOnlyChangeDoesNotCreateDeferredFlush() {
        let current = Self.snapshot(
            title: "old",
            customDescription: nil,
            isPinned: false,
            customColorHex: nil,
            finderDirectoryPath: nil
        )
        let next = Self.snapshot(
            title: "new",
            customDescription: "description",
            isPinned: true,
            customColorHex: "#C0392B",
            finderDirectoryPath: "/tmp/workspace"
        )

        let decision = SidebarWorkspaceSnapshotRefreshPolicy().decision(
            current: current,
            next: next,
            force: false,
            contextMenuVisible: true
        )

        #expect(decision.workspaceSnapshotStorage == next)
        #expect(decision.pendingWorkspaceSnapshot == nil)
        #expect(!decision.hasDeferredWorkspaceObservationInvalidation)
    }

    @Test func contextMenuMediaActivityChangeUpdatesDisplayedGlyphImmediately() {
        let current = Self.snapshot(
            remoteConnectionStatusText: "Connected",
            latestConversationMessage: "old message",
            listeningPorts: [3000],
            mediaActivity: BrowserMediaActivity(isPlayingAudio: true)
        )
        let next = Self.snapshot(
            remoteConnectionStatusText: "Disconnected",
            latestConversationMessage: "new message",
            listeningPorts: [3000, 4000],
            mediaActivity: BrowserMediaActivity(isPlayingAudio: false)
        )

        let decision = SidebarWorkspaceSnapshotRefreshPolicy().decision(
            current: current,
            next: next,
            force: false,
            contextMenuVisible: true
        )

        #expect(decision.workspaceSnapshotStorage?.mediaActivity.isPlayingAudio == false)
        #expect(decision.workspaceSnapshotStorage?.remoteConnectionStatusText == "Connected")
        #expect(decision.workspaceSnapshotStorage?.latestConversationMessage == "old message")
        #expect(decision.workspaceSnapshotStorage?.listeningPorts == [3000])
        #expect(decision.pendingWorkspaceSnapshot == next)
        #expect(decision.hasDeferredWorkspaceObservationInvalidation)
    }

    @Test func contextMenuTitleChangeCarriesMatchingPullRequestRows() {
        let current = Self.snapshot(
            title: "Assessing stale route parameter comment",
            pullRequestRows: [Self.pullRequest(number: 25194)]
        )
        let next = Self.snapshot(
            title: "Assessing route parameter comment",
            pullRequestRows: [Self.pullRequest(number: 25095)]
        )

        let decision = SidebarWorkspaceSnapshotRefreshPolicy().decision(
            current: current,
            next: next,
            force: false,
            contextMenuVisible: true
        )

        #expect(decision.workspaceSnapshotStorage?.title == "Assessing route parameter comment")
        #expect(decision.workspaceSnapshotStorage?.pullRequestRows.map(\.number) == [25095])
        #expect(decision.pendingWorkspaceSnapshot == nil)
        #expect(!decision.hasDeferredWorkspaceObservationInvalidation)
    }

    @Test(arguments: [
        (" Canonical domain mutation paths ", "STE-1964: Canonical domain mutation paths"),
        (" ", "STE-1964"),
        ("ste-1964", "STE-1964"),
    ]) func ticketDisplayLinkText(title: String, expected: String) {
        let ticket = SidebarWorkspaceSnapshotBuilder.TicketDisplay(
            id: "STE-1964",
            title: title,
            url: nil,
            ownerName: nil,
            ownerURL: nil
        )

        #expect(ticket.linkText == expected)
    }

    @Test(arguments: [
        (" Context Efficiency ", "Context Efficiency"),
        (" ", "context-efficiency-c1b9a"),
    ]) func projectDisplayLinkText(title: String, expected: String) {
        let project = SidebarWorkspaceSnapshotBuilder.ProjectDisplay(
            id: "context-efficiency-c1b9a",
            title: title,
            url: nil
        )

        #expect(project.linkText == expected)
    }

    @Test func livePullRequestRowsOverrideStaleProvenancePullRequest() throws {
        let rows = SidebarWorkspaceSnapshotBuilder.pullRequestDisplays(
            livePullRequests: [try Self.livePullRequest(number: 26196)],
            provenancePullRequest: try Self.provenancePullRequest(number: 26201),
            latestSubmittedMessage: nil,
            latestConversationMessage: nil,
            label: "PR"
        )

        #expect(rows.map(\.number) == [26196])
        #expect(rows.first?.url == URL(string: "https://github.com/CompanyCam/Company-Cam-API/pull/26196"))
        #expect(rows.first?.isFromProvenance == false)
    }

    @Test func livePullRequestRowsUseMatchingProvenanceOwnerDetails() throws {
        let rows = SidebarWorkspaceSnapshotBuilder.pullRequestDisplays(
            livePullRequests: [try Self.livePullRequest(number: 26171)],
            provenancePullRequest: try Self.provenancePullRequest(
                number: 26171,
                ownerLogin: "BrianBusby",
                ownerURL: "https://github.com/BrianBusby"
            ),
            latestSubmittedMessage: nil,
            latestConversationMessage: nil,
            label: "PR"
        )

        let row = try #require(rows.first)
        #expect(row.number == 26171)
        #expect(row.ownerLogin == "BrianBusby")
        #expect(row.ownerURL == URL(string: "https://github.com/BrianBusby"))
        #expect(row.isFromProvenance == false)
    }

    @Test func livePullRequestRowsPreserveKnownBranch() throws {
        let rows = SidebarWorkspaceSnapshotBuilder.pullRequestDisplays(
            livePullRequests: [try Self.livePullRequest(number: 26171, branch: "inp-2153-advanced-checklists")],
            provenancePullRequest: nil,
            latestSubmittedMessage: nil,
            latestConversationMessage: nil,
            label: "PR"
        )

        let row = try #require(rows.first)
        #expect(row.number == 26171)
        #expect(row.branch == "inp-2153-advanced-checklists")
    }

    @Test func livePullRequestRowsPreserveKnownTitle() throws {
        let rows = SidebarWorkspaceSnapshotBuilder.pullRequestDisplays(
            livePullRequests: [try Self.livePullRequest(number: 26171, title: "Fix route parameter handling", status: .merged)],
            provenancePullRequest: nil,
            latestSubmittedMessage: nil,
            latestConversationMessage: nil,
            label: "PR"
        )

        let row = try #require(rows.first)
        #expect(row.number == 26171)
        #expect(row.title == "Fix route parameter handling")
        #expect(row.primaryLine(statusLabel: "merged") == "PR #26171 merged")
        #expect(row.titleLine == "Fix route parameter handling")
    }

    @Test func latestPromptPullRequestURLOverridesStaleProvenancePullRequestWhenLiveStateIsMissing() throws {
        let rows = SidebarWorkspaceSnapshotBuilder.pullRequestDisplays(
            livePullRequests: [],
            provenancePullRequest: try Self.provenancePullRequest(number: 26201),
            latestSubmittedMessage: "seeing this on https://github.com/CompanyCam/Company-Cam-API/pull/26196",
            latestConversationMessage: nil,
            label: "PR"
        )

        #expect(rows.map(\.number) == [26196])
        #expect(rows.first?.url == URL(string: "https://github.com/CompanyCam/Company-Cam-API/pull/26196"))
        #expect(rows.first?.isFromProvenance == false)
    }

    @Test func barePromptPullRequestNumberSuppressesConflictingProvenancePullRequest() throws {
        let rows = SidebarWorkspaceSnapshotBuilder.pullRequestDisplays(
            livePullRequests: [],
            provenancePullRequest: try Self.provenancePullRequest(number: 26201),
            latestSubmittedMessage: "PR #26196 now has a single signed commit",
            latestConversationMessage: nil,
            label: "PR"
        )

        #expect(rows.isEmpty)
    }

    @Test func provenancePullRequestIsSuppressedWithoutExplicitIntent() throws {
        let rows = SidebarWorkspaceSnapshotBuilder.pullRequestDisplays(
            livePullRequests: [],
            provenancePullRequest: try Self.provenancePullRequest(number: 26201),
            latestSubmittedMessage: "continue checking the blocked merge",
            latestConversationMessage: nil,
            label: "PR"
        )

        #expect(rows.isEmpty)
    }

    @Test func provenancePullRequestRendersWhenPromptMentionsSameNumber() throws {
        let rows = SidebarWorkspaceSnapshotBuilder.pullRequestDisplays(
            livePullRequests: [],
            provenancePullRequest: try Self.provenancePullRequest(
                number: 26201,
                branch: "inp-2153-advanced-checklists"
            ),
            latestSubmittedMessage: "continue checking pull 26201",
            latestConversationMessage: nil,
            label: "PR"
        )

        #expect(rows.map(\.number) == [26201])
        let row = try #require(rows.first)
        #expect(row.isFromProvenance == true)
        #expect(row.branch == "inp-2153-advanced-checklists")
    }

    @Test func provenancePullRequestRendersForPullRequestScopedWorktree() throws {
        let rows = SidebarWorkspaceSnapshotBuilder.pullRequestDisplays(
            livePullRequests: [],
            provenancePullRequest: try Self.provenancePullRequest(number: 26201),
            provenanceCurrentDirectory: "/private/tmp/companycam-pr-26201",
            latestSubmittedMessage: "continue checking the blocked merge",
            latestConversationMessage: nil,
            label: "PR"
        )

        #expect(rows.map(\.number) == [26201])
        #expect(rows.first?.isFromProvenance == true)
    }

    @Test func closedContextMenuStoresNextAndClearsPending() {
        let current = Self.snapshot(title: "old", isPinned: false)
        let next = Self.snapshot(title: "new", isPinned: true)

        let decision = SidebarWorkspaceSnapshotRefreshPolicy().decision(
            current: current,
            next: next,
            force: false,
            contextMenuVisible: false
        )

        #expect(decision.workspaceSnapshotStorage == next)
        #expect(decision.pendingWorkspaceSnapshot == nil)
        #expect(!decision.hasDeferredWorkspaceObservationInvalidation)
    }

    private static func snapshot(
        presentationKey: SidebarWorkspaceSnapshotBuilder.PresentationKey? = nil,
        title: String = "workspace",
        customDescription: String? = nil,
        isPinned: Bool = false,
        customColorHex: String? = nil,
        remoteConnectionStatusText: String = "Disconnected",
        latestConversationMessage: String? = nil,
        latestSubmittedMessage: String? = nil,
        pullRequestRows: [SidebarWorkspaceSnapshotBuilder.PullRequestDisplay] = [],
        projectRows: [SidebarWorkspaceSnapshotBuilder.ProjectDisplay] = [],
        listeningPorts: [Int] = [],
        finderDirectoryPath: String? = nil,
        repoBadgeAppearance: WorkspaceRepoBadgeAppearance? = nil,
        ticketRows: [SidebarWorkspaceSnapshotBuilder.TicketDisplay] = [],
        mediaActivity: BrowserMediaActivity = BrowserMediaActivity(),
        hasActiveAIWork: Bool = false
    ) -> SidebarWorkspaceSnapshotBuilder.Snapshot {
        SidebarWorkspaceSnapshotBuilder.Snapshot(
            presentationKey: presentationKey ?? Self.presentationKey(),
            title: title,
            customDescription: customDescription,
            isPinned: isPinned,
            customColorHex: customColorHex,
            remoteWorkspaceSidebarText: nil,
            remoteConnectionStatusText: remoteConnectionStatusText,
            remoteStateHelpText: "",
            showsRemoteReconnectAffordance: false,
            copyableSidebarSSHError: nil,
            latestConversationMessage: latestConversationMessage,
            latestSubmittedMessage: latestSubmittedMessage,
            metadataEntries: [],
            metadataBlocks: [],
            latestLog: nil,
            progress: nil,
            compactGitBranchSummaryText: nil,
            compactDirectoryCandidates: [],
            compactBranchDirectoryCandidates: [],
            branchDirectoryLines: [],
            branchLinesContainBranch: false,
            pullRequestRows: pullRequestRows,
            projectRows: projectRows,
            ticketRows: ticketRows,
            listeningPorts: listeningPorts,
            finderDirectoryPath: finderDirectoryPath,
            repoBadgeAppearance: repoBadgeAppearance,
            mediaActivity: mediaActivity,
            hasActiveAIWork: hasActiveAIWork
        )
    }

    private static func presentationKey(
        showsWorkspaceDescription: Bool = true,
        usesVerticalBranchLayout: Bool = true,
        showsGitBranch: Bool = true,
        usesViewportAwarePath: Bool = false,
        visibleAuxiliaryDetails: SidebarWorkspaceAuxiliaryDetailVisibility = SidebarWorkspaceAuxiliaryDetailVisibility(
            showsMetadata: true,
            showsLog: true,
            showsProgress: true,
            showsBranchDirectory: true,
            showsPullRequests: true,
            showsPorts: true
        ),
        provenanceDisplaySnapshot: WorkspaceDisplayCurrentStateSnapshot? = nil
    ) -> SidebarWorkspaceSnapshotBuilder.PresentationKey {
        SidebarWorkspaceSnapshotBuilder.PresentationKey(
            showsWorkspaceDescription: showsWorkspaceDescription,
            usesVerticalBranchLayout: usesVerticalBranchLayout,
            showsGitBranch: showsGitBranch,
            usesViewportAwarePath: usesViewportAwarePath,
            visibleAuxiliaryDetails: visibleAuxiliaryDetails,
            provenanceDisplaySnapshot: provenanceDisplaySnapshot
        )
    }

    private static func pullRequest(
        number: Int,
        title: String? = nil,
        isStale: Bool = false
    ) -> SidebarWorkspaceSnapshotBuilder.PullRequestDisplay {
        SidebarWorkspaceSnapshotBuilder.PullRequestDisplay(
            id: "pr#\(number)|https://github.com/manaflow-ai/bmux/pull/\(number)",
            number: number,
            title: title,
            label: "PR",
            url: URL(string: "https://github.com/manaflow-ai/bmux/pull/\(number)")!,
            status: .open,
            ownerLogin: nil,
            ownerURL: nil,
            branch: nil,
            isStale: isStale,
            isFromProvenance: false
        )
    }

    private static func livePullRequest(
        number: Int,
        title: String? = nil,
        status: SidebarPullRequestStatus = .open,
        branch: String? = nil
    ) throws -> SidebarPullRequestState {
        SidebarPullRequestState(
            number: number,
            title: title,
            label: "PR",
            url: try #require(URL(string: "https://github.com/CompanyCam/Company-Cam-API/pull/\(number)")),
            status: status,
            branch: branch
        )
    }

    private static func provenancePullRequest(
        number: Int,
        status: String = "open",
        ownerLogin: String? = nil,
        ownerURL: String? = nil,
        branch: String? = nil
    ) throws -> WorkspaceDisplayCurrentStatePullRequestSnapshot {
        let updatedAt = Date(timeIntervalSince1970: 900)
        let record = ProvenanceWorkspaceDisplayRecord(
            id: "workspace-display-\(number)",
            workspaceID: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
            repositoryID: nil,
            worktreeID: nil,
            currentDirectory: nil,
            title: nil,
            titleSource: nil,
            branch: nil,
            pullRequestNumber: number,
            pullRequestURL: "https://github.com/CompanyCam/Company-Cam-API/pull/\(number)",
            pullRequestOwnerLogin: ownerLogin,
            pullRequestOwnerURL: ownerURL,
            pullRequestStatus: status,
            pullRequestBranch: branch,
            pullRequestIsStale: false,
            isDirty: nil,
            ticketIDs: [],
            ticketLinks: [],
            latestEventID: "event-\(number)",
            latestEventSequence: number,
            observedAt: updatedAt,
            updatedAt: updatedAt
        )
        return try #require(WorkspaceDisplayCurrentStateSnapshot(record)?.pullRequest)
    }
}

@Suite struct SidebarWorkspaceRowLineLimitPolicyTests {
    @Test func workspaceTitlesUseAtMostThreeLinesWhenWrappingIsEnabled() {
        #expect(SidebarWorkspaceRowLineLimitPolicy.titleLineLimit(wrapsWorkspaceTitles: true) == 3)
    }

    @Test func workspaceTitlesStaySingleLineWhenWrappingIsDisabled() {
        #expect(SidebarWorkspaceRowLineLimitPolicy.titleLineLimit(wrapsWorkspaceTitles: false) == 1)
    }

    @Test func linkedTitlesUseAtMostThreeLinesWhenWrappingIsEnabled() {
        #expect(SidebarWorkspaceRowLineLimitPolicy.linkedTitleLineLimit(wrapsWorkspaceTitles: true) == 3)
    }

    @Test func linkedTitlesStaySingleLineWhenWrappingIsDisabled() {
        #expect(SidebarWorkspaceRowLineLimitPolicy.linkedTitleLineLimit(wrapsWorkspaceTitles: false) == 1)
    }

    @Test func workspaceTitleWrappingIsEnabledByDefault() {
        #expect(SidebarWorkspaceTitleWrapSettings.defaultWrap)
    }

    @Test func conversationSubtitleCanUseThreeLines() throws {
        let subtitle = try #require(SidebarWorkspaceRowLineLimitPolicy.subtitle(
            notificationText: nil,
            conversationMessage: "First line\nSecond line\nThird line"
        ))

        #expect(subtitle.text == "First line\nSecond line\nThird line")
        #expect(subtitle.lineLimit == 3)
    }

    @Test func notificationSubtitleStaysCompactAndWinsOverConversation() throws {
        let subtitle = try #require(SidebarWorkspaceRowLineLimitPolicy.subtitle(
            notificationText: "Build finished",
            conversationMessage: "A longer conversation summary"
        ))

        #expect(subtitle.text == "Build finished")
        #expect(subtitle.lineLimit == 2)
    }

    @Test func conversationSubtitlePrefersSubmittedPromptOverAssistantReply() {
        let subtitle = SidebarWorkspaceRowLineLimitPolicy.conversationMessage(
            latestSubmittedMessage: "last prompt I submitted",
            latestConversationMessage: "assistant response that arrived later",
            hidesAllDetails: false,
            iMessageModeEnabled: true
        )

        #expect(subtitle == "last prompt I submitted")
    }

    @Test func conversationSubtitleHidesDisplayedPullRequestPrompt() {
        let subtitle = SidebarWorkspaceRowLineLimitPolicy.conversationMessage(
            latestSubmittedMessage: "do an adversarial review of this pr: https://github.com/CompanyCam/Company-Cam-API/pull/25964",
            latestConversationMessage: nil,
            hidesAllDetails: false,
            iMessageModeEnabled: true,
            hiddenPullRequestNumbers: [25964]
        )

        #expect(subtitle == nil)
    }

    @Test func conversationSubtitleKeepsDifferentPullRequestPrompt() {
        let subtitle = SidebarWorkspaceRowLineLimitPolicy.conversationMessage(
            latestSubmittedMessage: "do an adversarial review of this pr: https://github.com/CompanyCam/Company-Cam-API/pull/25964",
            latestConversationMessage: nil,
            hidesAllDetails: false,
            iMessageModeEnabled: true,
            hiddenPullRequestNumbers: [12345]
        )

        #expect(subtitle != nil)
    }

    @Test func conversationSubtitleDoesNotFallBackToAssistantReply() {
        let subtitle = SidebarWorkspaceRowLineLimitPolicy.conversationMessage(
            latestSubmittedMessage: nil,
            latestConversationMessage: "assistant response that arrived later",
            hidesAllDetails: false,
            iMessageModeEnabled: true
        )

        #expect(subtitle == nil)
    }

    @Test func conversationSubtitleIsHiddenOutsideIMessageDetails() {
        #expect(SidebarWorkspaceRowLineLimitPolicy.conversationMessage(
            latestSubmittedMessage: "last prompt I submitted",
            latestConversationMessage: "assistant response",
            hidesAllDetails: true,
            iMessageModeEnabled: true
        ) == nil)
        #expect(SidebarWorkspaceRowLineLimitPolicy.conversationMessage(
            latestSubmittedMessage: "last prompt I submitted",
            latestConversationMessage: "assistant response",
            hidesAllDetails: false,
            iMessageModeEnabled: false
        ) == nil)
    }

    @Test func blankConversationSubtitleIsHidden() {
        #expect(SidebarWorkspaceRowLineLimitPolicy.subtitle(
            notificationText: nil,
            conversationMessage: " \n "
        ) == nil)
    }
}

@Suite struct WorkspaceRepoBadgeAppearanceResolverTests {
    @Test func returnsNilForBlankRepoPath() {
        var resolver = WorkspaceRepoBadgeAppearanceResolver(
            palette: ["#F2C94C"]
        )

        let blankAppearance = resolver.appearance(repoRootPath: " \n ")
        let missingAppearance = resolver.appearance(repoRootPath: nil)

        #expect(blankAppearance == nil)
        #expect(missingAppearance == nil)
    }

    @Test func usesLastPathComponentAsRepoName() throws {
        var resolver = WorkspaceRepoBadgeAppearanceResolver(
            palette: ["#F2C94C"]
        )

        let appearanceCandidate = resolver.appearance(
            repoRootPath: "/Users/brian/repos/bmux"
        )
        let appearance = try #require(appearanceCandidate)

        #expect(appearance.name == "bmux")
        #expect(appearance.colorHex == "#F2C94C")
    }

    @Test func reusesColorForSameNormalizedRepoPath() throws {
        var resolver = WorkspaceRepoBadgeAppearanceResolver(
            palette: ["#F2C94C", "#56CCF2"]
        )

        let firstCandidate = resolver.appearance(
            repoRootPath: "/Users/brian/repos/bmux"
        )
        let secondCandidate = resolver.appearance(
            repoRootPath: "/Users/brian/repos/bmux/"
        )
        let first = try #require(firstCandidate)
        let second = try #require(secondCandidate)

        #expect(first.name == "bmux")
        #expect(second.name == "bmux")
        #expect(first.colorHex == second.colorHex)
    }

    @Test func assignsDifferentColorsToDifferentReposWhenPaletteAllows() throws {
        var resolver = WorkspaceRepoBadgeAppearanceResolver(
            palette: ["#F2C94C", "#56CCF2"]
        )

        let bmuxCandidate = resolver.appearance(repoRootPath: "/repo/bmux")
        let apiCandidate = resolver.appearance(repoRootPath: "/repo/api")
        let bmux = try #require(bmuxCandidate)
        let api = try #require(apiCandidate)

        #expect(bmux.colorHex == "#F2C94C")
        #expect(api.colorHex == "#56CCF2")
    }
}

@Suite struct WorkspaceRepoBadgeAppearanceColorPolicyTests {
    @Test func usesRepoColorWhenWorkspaceHasNoCustomColor() {
        let colorHex = WorkspaceRepoBadgeAppearanceColorPolicy.effectiveColorHex(
            customColorHex: nil,
            repoBadgeAppearance: WorkspaceRepoBadgeAppearance(
                name: "bmux",
                colorHex: "#F2C94C"
            )
        )

        #expect(colorHex == "#F2C94C")
    }

    @Test func keepsExplicitWorkspaceColorAheadOfRepoColor() {
        let colorHex = WorkspaceRepoBadgeAppearanceColorPolicy.effectiveColorHex(
            customColorHex: "#56CCF2",
            repoBadgeAppearance: WorkspaceRepoBadgeAppearance(
                name: "bmux",
                colorHex: "#F2C94C"
            )
        )

        #expect(colorHex == "#56CCF2")
    }

    @Test func foregroundIsBlackInLightAppearance() {
        let foreground = WorkspaceRepoBadgeAppearanceColorPolicy.foregroundNSColor(
            repoColorHex: "#56CCF2",
            colorScheme: .light
        )

        #expect(foreground.usingColorSpace(.sRGB)?.hexString(includeAlpha: true) == "#000000FF")
    }

    @Test func foregroundUsesBrightRepoColorInDarkAppearance() {
        let foreground = WorkspaceRepoBadgeAppearanceColorPolicy.foregroundNSColor(
            repoColorHex: "#2F80ED",
            colorScheme: .dark
        )
        let matchingRepoForeground = WorkspaceRepoBadgeAppearanceColorPolicy.foregroundNSColor(
            repoColorHex: "#2F80ED",
            colorScheme: .dark
        )
        let otherRepoForeground = WorkspaceRepoBadgeAppearanceColorPolicy.foregroundNSColor(
            repoColorHex: "#F2C94C",
            colorScheme: .dark
        )
        let foregroundHex = foreground.usingColorSpace(.sRGB)?.hexString(includeAlpha: true)
        let matchingRepoForegroundHex = matchingRepoForeground
            .usingColorSpace(.sRGB)?
            .hexString(includeAlpha: true)
        let otherRepoForegroundHex = otherRepoForeground
            .usingColorSpace(.sRGB)?
            .hexString(includeAlpha: true)

        #expect(foregroundHex == matchingRepoForegroundHex)
        #expect(foregroundHex != otherRepoForegroundHex)
        #expect(bmuxContrastRatio(foreground: foreground, background: .black) >= 4.5)
    }
}

@Suite struct SidebarSelectedWorkspaceScrollPolicyTests {
    @Test func skipsScrollWhenSelectedWorkspaceIdIsNil() {
        #expect(!SidebarSelectedWorkspaceScrollPolicy.shouldScrollSelectedWorkspace(
            selectedWorkspaceId: nil as String?,
            oldWorkspaceIds: ["a"],
            newWorkspaceIds: ["a"]
        ))
    }

    @Test func requestsScrollWhenSelectedWorkspaceFirstAppears() {
        #expect(SidebarSelectedWorkspaceScrollPolicy.shouldScrollSelectedWorkspace(
            selectedWorkspaceId: "b",
            oldWorkspaceIds: ["a"],
            newWorkspaceIds: ["a", "b"]
        ))
    }

    @Test func requestsScrollWhenSelectedWorkspaceMovesToTop() {
        #expect(SidebarSelectedWorkspaceScrollPolicy.shouldScrollSelectedWorkspace(
            selectedWorkspaceId: "c",
            oldWorkspaceIds: ["a", "b", "c"],
            newWorkspaceIds: ["c", "a", "b"]
        ))
    }

    @Test func requestsScrollWhenAnotherReorderShiftsSelectedWorkspaceIndex() {
        #expect(SidebarSelectedWorkspaceScrollPolicy.shouldScrollSelectedWorkspace(
            selectedWorkspaceId: "b",
            oldWorkspaceIds: ["a", "b", "c"],
            newWorkspaceIds: ["c", "a", "b"]
        ))
    }

    @Test func skipsScrollWhenWorkspaceBeforeSelectedWorkspaceCloses() {
        #expect(!SidebarSelectedWorkspaceScrollPolicy.shouldScrollSelectedWorkspace(selectedWorkspaceId: "d", oldWorkspaceIds: ["a", "b", "c", "d"], newWorkspaceIds: ["a", "c", "d"]))
    }
    @Test func skipsScrollWhenReorderLeavesSelectedWorkspaceIndexUnchanged() {
        #expect(!SidebarSelectedWorkspaceScrollPolicy.shouldScrollSelectedWorkspace(
            selectedWorkspaceId: "a",
            oldWorkspaceIds: ["a", "b", "c"],
            newWorkspaceIds: ["a", "c", "b"]
        ))
    }

    @Test func skipsScrollWhenSelectedWorkspaceIsMissing() {
        #expect(!SidebarSelectedWorkspaceScrollPolicy.shouldScrollSelectedWorkspace(
            selectedWorkspaceId: "b",
            oldWorkspaceIds: ["a", "b"],
            newWorkspaceIds: ["a", "c"]
        ))
    }

    @Test func scrollTargetIsSelfWithoutGroup() {
        let workspaceId = UUID()
        #expect(SidebarSelectedWorkspaceScrollPolicy.scrollTargetWorkspaceId(
            selectedWorkspaceId: workspaceId,
            group: nil
        ) == workspaceId)
    }

    @Test func scrollTargetIsSelfInExpandedGroup() {
        let workspaceId = UUID()
        #expect(SidebarSelectedWorkspaceScrollPolicy.scrollTargetWorkspaceId(
            selectedWorkspaceId: workspaceId,
            group: makeGroup(isCollapsed: false, anchorWorkspaceId: UUID())
        ) == workspaceId)
    }

    @Test func scrollTargetIsGroupAnchorWhenGroupIsCollapsed() {
        let anchorId = UUID()
        #expect(SidebarSelectedWorkspaceScrollPolicy.scrollTargetWorkspaceId(
            selectedWorkspaceId: UUID(),
            group: makeGroup(isCollapsed: true, anchorWorkspaceId: anchorId)
        ) == anchorId)
    }

    private func makeGroup(isCollapsed: Bool, anchorWorkspaceId: UUID) -> WorkspaceGroup {
        WorkspaceGroup(
            id: UUID(),
            name: "group",
            isCollapsed: isCollapsed,
            isPinned: false,
            anchorWorkspaceId: anchorWorkspaceId,
            customColor: nil,
            iconSymbol: nil
        )
    }
}

@Suite struct SidebarWorkspaceRowInteractionStateTests {
    @Test func appKitMenuTrackingEndClearsStaleContextMenuVisibility() {
        var state = SidebarWorkspaceRowInteractionState()

        state.contextMenuDidAppear()
        #expect(state.contextMenuVisible)

        let didEndTracking = state.contextMenuTrackingDidEnd(pointerInsideRow: true)
        #expect(didEndTracking)
        state.setPointerHovering(true)

        #expect(state.shouldShowCloseButton(canCloseWorkspace: true, shortcutHintModeActive: false))
    }

    @Test func appKitMenuTrackingEndUsesReconciledPointerExit() {
        var state = SidebarWorkspaceRowInteractionState()

        state.setPointerHovering(true)
        state.contextMenuDidAppear()

        let didEndTracking = state.contextMenuTrackingDidEnd(pointerInsideRow: false)
        #expect(didEndTracking)

        #expect(!state.shouldShowCloseButton(canCloseWorkspace: true, shortcutHintModeActive: false))
    }

    @Test @MainActor func menuTrackingReconcilerIgnoresSubmenuEndNotifications() {
        let rootMenu = NSMenu()
        let submenu = NSMenu()
        let item = NSMenuItem(title: "submenu", action: nil, keyEquivalent: "")
        rootMenu.addItem(item)
        rootMenu.setSubmenu(submenu, for: item)

        #expect(SidebarWorkspaceRowMenuTrackingReconcilerView.shouldReconcileMenuEnd(object: rootMenu))
        #expect(!SidebarWorkspaceRowMenuTrackingReconcilerView.shouldReconcileMenuEnd(object: submenu))
        #expect(!SidebarWorkspaceRowMenuTrackingReconcilerView.shouldReconcileMenuEnd(object: nil))
    }

    @Test func hoverDuringContextMenuStaysHiddenUntilDismissal() {
        var state = SidebarWorkspaceRowInteractionState()

        state.contextMenuDidAppear()
        state.setPointerHovering(true)

        #expect(!state.shouldShowCloseButton(canCloseWorkspace: true, shortcutHintModeActive: false))

        state.contextMenuDidDisappear()

        #expect(state.shouldShowCloseButton(canCloseWorkspace: true, shortcutHintModeActive: false))
    }

    @Test func contextMenuDismissalRestoresHoverWithoutPointerMovement() {
        var state = SidebarWorkspaceRowInteractionState()

        state.setPointerHovering(true)
        state.contextMenuDidAppear()
        state.contextMenuDidDisappear()

        #expect(state.shouldShowCloseButton(canCloseWorkspace: true, shortcutHintModeActive: false))
    }

    @Test func pointerExitWhileContextMenuIsVisibleStaysHiddenAfterDismissal() {
        var state = SidebarWorkspaceRowInteractionState()

        state.setPointerHovering(true)
        state.contextMenuDidAppear()
        state.contextMenuTrackingObserverDidInstall()
        state.setPointerHovering(false)
        state.contextMenuDidDisappear()

        #expect(!state.shouldShowCloseButton(canCloseWorkspace: true, shortcutHintModeActive: false))
    }

    @Test func swiftUIOnlyFastContextMenuDismissalKeepsInitialHoverFallback() {
        var state = SidebarWorkspaceRowInteractionState()

        state.setPointerHovering(true)
        state.contextMenuDidAppear()
        state.setPointerHovering(false)
        state.contextMenuDidDisappear()

        #expect(state.shouldShowCloseButton(canCloseWorkspace: true, shortcutHintModeActive: false))
    }

    @Test func noHoverDoesNotRevealCloseButtonWhileContextMenuIsVisible() {
        var state = SidebarWorkspaceRowInteractionState()

        state.contextMenuDidAppear()
        state.setPointerHovering(false)

        #expect(!state.shouldShowCloseButton(canCloseWorkspace: true, shortcutHintModeActive: false))
    }

    @Test @MainActor func hoverReconcilerRestoresCloseButtonAfterLifecycleHoverReset() {
        var state = SidebarWorkspaceRowInteractionState()

        let view = SidebarWorkspaceRowHoverReconcilerView()
        view.frame = NSRect(x: 0, y: 0, width: 120, height: 28)
        view.onPointerHoverChanged = { state.setPointerHovering($0) }

        view.reconcilePointerLocation(pointInView: NSPoint(x: 60, y: 14))
        #expect(state.shouldShowCloseButton(canCloseWorkspace: true, shortcutHintModeActive: false))

        state.setPointerHovering(false)
        #expect(!state.shouldShowCloseButton(canCloseWorkspace: true, shortcutHintModeActive: false))

        view.reconcilePointerLocation(pointInView: NSPoint(x: 60, y: 14))

        #expect(state.shouldShowCloseButton(canCloseWorkspace: true, shortcutHintModeActive: false))
    }

    @Test func contextMenuAppearanceHidesExistingCloseButtonUntilPointerIsReconciled() {
        var state = SidebarWorkspaceRowInteractionState()

        state.setPointerHovering(true)
        #expect(state.shouldShowCloseButton(canCloseWorkspace: true, shortcutHintModeActive: false))

        state.contextMenuDidAppear()

        #expect(!state.shouldShowCloseButton(canCloseWorkspace: true, shortcutHintModeActive: false))
    }

    @Test func contextMenuDismissalCanRevealAfterPointerReconciliation() {
        var state = SidebarWorkspaceRowInteractionState()

        state.setPointerHovering(true)
        state.contextMenuDidAppear()
        state.contextMenuDidDisappear()
        state.setPointerHovering(true)

        #expect(state.shouldShowCloseButton(canCloseWorkspace: true, shortcutHintModeActive: false))
    }

    @Test func closeButtonHiddenWhenWorkspaceCannotBeClosed() {
        var state = SidebarWorkspaceRowInteractionState()

        state.setPointerHovering(true)

        #expect(!state.shouldShowCloseButton(
            canCloseWorkspace: false,
            shortcutHintModeActive: false
        ))
    }

    @Test func closeButtonHiddenDuringShortcutHintMode() {
        var state = SidebarWorkspaceRowInteractionState()

        state.setPointerHovering(true)

        #expect(!state.shouldShowCloseButton(
            canCloseWorkspace: true,
            shortcutHintModeActive: true
        ))
    }
}
