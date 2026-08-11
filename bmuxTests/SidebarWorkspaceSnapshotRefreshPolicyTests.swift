import AppKit
import BmuxSidebar
import BmuxWorkspaces
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
        isStale: Bool = false
    ) -> SidebarWorkspaceSnapshotBuilder.PullRequestDisplay {
        SidebarWorkspaceSnapshotBuilder.PullRequestDisplay(
            id: "pr#\(number)|https://github.com/manaflow-ai/bmux/pull/\(number)",
            number: number,
            label: "PR",
            url: URL(string: "https://github.com/manaflow-ai/bmux/pull/\(number)")!,
            ownerLogin: nil,
            status: .open,
            isStale: isStale
        )
    }
}

@Suite struct SidebarWorkspaceRowLineLimitPolicyTests {
    @Test func workspaceTitlesUseAtMostThreeLinesWhenWrappingIsEnabled() {
        #expect(SidebarWorkspaceRowLineLimitPolicy.titleLineLimit(wrapsWorkspaceTitles: true) == 3)
    }

    @Test func workspaceTitlesStaySingleLineWhenWrappingIsDisabled() {
        #expect(SidebarWorkspaceRowLineLimitPolicy.titleLineLimit(wrapsWorkspaceTitles: false) == 1)
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

        #expect(
            state.shouldShowCloseButton(
                canCloseWorkspace: true,
                shortcutHintModeActive: false
            ),
            "AppKit menu tracking ending must clear stale SwiftUI context-menu visibility so later hover can reveal row affordances."
        )
    }

    @Test func appKitMenuTrackingEndUsesReconciledPointerExit() {
        var state = SidebarWorkspaceRowInteractionState()

        state.setPointerHovering(true)
        state.contextMenuDidAppear()

        let didEndTracking = state.contextMenuTrackingDidEnd(pointerInsideRow: false)
        #expect(didEndTracking)

        #expect(
            !state.shouldShowCloseButton(
                canCloseWorkspace: true,
                shortcutHintModeActive: false
            ),
            "If the pointer leaves through the context menu, AppKit menu tracking reconciliation must keep the row affordance hidden."
        )
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

        #expect(
            !state.shouldShowCloseButton(
                canCloseWorkspace: true,
                shortcutHintModeActive: false
            ),
            "Pointer hover updates observed during the context-menu lifecycle must not reveal the close affordance under the menu."
        )

        state.contextMenuDidDisappear()

        #expect(
            state.shouldShowCloseButton(
                canCloseWorkspace: true,
                shortcutHintModeActive: false
            ),
            "Once the context menu dismisses, the last observed pointer position may reveal the close affordance."
        )
    }

    @Test func contextMenuDismissalRestoresHoverWithoutPointerMovement() {
        var state = SidebarWorkspaceRowInteractionState()

        state.setPointerHovering(true)
        state.contextMenuDidAppear()
        state.contextMenuDidDisappear()

        #expect(
            state.shouldShowCloseButton(
                canCloseWorkspace: true,
                shortcutHintModeActive: false
            ),
            "Closing a context menu without moving the pointer must restore the row hover affordance."
        )
    }

    @Test func pointerExitWhileContextMenuIsVisibleStaysHiddenAfterDismissal() {
        var state = SidebarWorkspaceRowInteractionState()

        state.setPointerHovering(true)
        state.contextMenuDidAppear()
        state.contextMenuTrackingObserverDidInstall()
        state.setPointerHovering(false)
        state.contextMenuDidDisappear()

        #expect(
            !state.shouldShowCloseButton(
                canCloseWorkspace: true,
                shortcutHintModeActive: false
            ),
            "Pointer exit remains authoritative even when it is observed during the context-menu lifecycle."
        )
    }

    @Test func swiftUIOnlyFastContextMenuDismissalKeepsInitialHoverFallback() {
        var state = SidebarWorkspaceRowInteractionState()

        state.setPointerHovering(true)
        state.contextMenuDidAppear()
        state.setPointerHovering(false)
        state.contextMenuDidDisappear()

        #expect(
            state.shouldShowCloseButton(
                canCloseWorkspace: true,
                shortcutHintModeActive: false
            ),
            "A SwiftUI hover-exit caused by the menu taking focus must not erase the initial hover fallback before the AppKit reconciler mounts."
        )
    }

    @Test func noHoverDoesNotRevealCloseButtonWhileContextMenuIsVisible() {
        var state = SidebarWorkspaceRowInteractionState()

        state.contextMenuDidAppear()
        state.setPointerHovering(false)

        #expect(
            !state.shouldShowCloseButton(
                canCloseWorkspace: true,
                shortcutHintModeActive: false
            ),
            "A visible context menu must not make the close affordance visible when the pointer is not hovering."
        )
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

        #expect(
            state.shouldShowCloseButton(
                canCloseWorkspace: true,
                shortcutHintModeActive: false
            ),
            "When sidebar updates or row reuse clear SwiftUI hover state while the pointer is still inside the row, the AppKit hover reconciler must restore the close affordance without waiting for another mouse move."
        )
    }

    @Test func contextMenuAppearanceHidesExistingCloseButtonUntilPointerIsReconciled() {
        var state = SidebarWorkspaceRowInteractionState()

        state.setPointerHovering(true)
        #expect(state.shouldShowCloseButton(canCloseWorkspace: true, shortcutHintModeActive: false))

        state.contextMenuDidAppear()

        #expect(
            !state.shouldShowCloseButton(
                canCloseWorkspace: true,
                shortcutHintModeActive: false
            ),
            "Opening a context menu must clear the row close affordance until tracking reports the pointer is still inside."
        )
    }

    @Test func contextMenuDismissalCanRevealAfterPointerReconciliation() {
        var state = SidebarWorkspaceRowInteractionState()

        state.setPointerHovering(true)
        state.contextMenuDidAppear()
        state.contextMenuDidDisappear()
        state.setPointerHovering(true)

        #expect(
            state.shouldShowCloseButton(
                canCloseWorkspace: true,
                shortcutHintModeActive: false
            ),
            "Closing the context menu may reveal the close affordance again only after pointer tracking reconciles inside the row."
        )
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
