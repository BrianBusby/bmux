import AppKit
import CmuxSidebar
import CmuxWorkspaces
import SwiftUI
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
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

        let decision = SidebarWorkspaceSnapshotRefreshPolicy.decision(
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

        let decision = SidebarWorkspaceSnapshotRefreshPolicy.decision(
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

        let decision = SidebarWorkspaceSnapshotRefreshPolicy.decision(
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

    @Test func closedContextMenuStoresNextAndClearsPending() {
        let current = Self.snapshot(title: "old", isPinned: false)
        let next = Self.snapshot(title: "new", isPinned: true)

        let decision = SidebarWorkspaceSnapshotRefreshPolicy.decision(
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
        listeningPorts: [Int] = [],
        finderDirectoryPath: String? = nil,
        repoBadgeAppearance: WorkspaceRepoBadgeAppearance? = nil,
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
            metadataEntries: [],
            metadataBlocks: [],
            latestLog: nil,
            progress: nil,
            compactGitBranchSummaryText: nil,
            compactDirectoryCandidates: [],
            compactBranchDirectoryCandidates: [],
            branchDirectoryLines: [],
            branchLinesContainBranch: false,
            pullRequestRows: [],
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
        )
    ) -> SidebarWorkspaceSnapshotBuilder.PresentationKey {
        SidebarWorkspaceSnapshotBuilder.PresentationKey(
            showsWorkspaceDescription: showsWorkspaceDescription,
            usesVerticalBranchLayout: usesVerticalBranchLayout,
            showsGitBranch: showsGitBranch,
            usesViewportAwarePath: usesViewportAwarePath,
            visibleAuxiliaryDetails: visibleAuxiliaryDetails
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
            repoRootPath: "/Users/brian/repos/cmux"
        )
        let appearance = try #require(appearanceCandidate)

        #expect(appearance.name == "cmux")
        #expect(appearance.colorHex == "#F2C94C")
    }

    @Test func reusesColorForSameNormalizedRepoPath() throws {
        var resolver = WorkspaceRepoBadgeAppearanceResolver(
            palette: ["#F2C94C", "#56CCF2"]
        )

        let firstCandidate = resolver.appearance(
            repoRootPath: "/Users/brian/repos/cmux"
        )
        let secondCandidate = resolver.appearance(
            repoRootPath: "/Users/brian/repos/cmux/"
        )
        let first = try #require(firstCandidate)
        let second = try #require(secondCandidate)

        #expect(first.name == "cmux")
        #expect(second.name == "cmux")
        #expect(first.colorHex == second.colorHex)
    }

    @Test func assignsDifferentColorsToDifferentReposWhenPaletteAllows() throws {
        var resolver = WorkspaceRepoBadgeAppearanceResolver(
            palette: ["#F2C94C", "#56CCF2"]
        )

        let cmuxCandidate = resolver.appearance(repoRootPath: "/repo/cmux")
        let apiCandidate = resolver.appearance(repoRootPath: "/repo/api")
        let cmux = try #require(cmuxCandidate)
        let api = try #require(apiCandidate)

        #expect(cmux.colorHex == "#F2C94C")
        #expect(api.colorHex == "#56CCF2")
    }
}

@Suite struct WorkspaceRepoBadgeAppearanceColorPolicyTests {
    @Test func usesRepoColorWhenWorkspaceHasNoCustomColor() {
        let colorHex = WorkspaceRepoBadgeAppearanceColorPolicy.effectiveColorHex(
            customColorHex: nil,
            repoBadgeAppearance: WorkspaceRepoBadgeAppearance(
                name: "cmux",
                colorHex: "#F2C94C"
            )
        )

        #expect(colorHex == "#F2C94C")
    }

    @Test func keepsExplicitWorkspaceColorAheadOfRepoColor() {
        let colorHex = WorkspaceRepoBadgeAppearanceColorPolicy.effectiveColorHex(
            customColorHex: "#56CCF2",
            repoBadgeAppearance: WorkspaceRepoBadgeAppearance(
                name: "cmux",
                colorHex: "#F2C94C"
            )
        )

        #expect(colorHex == "#56CCF2")
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
    @Test func hoverRevealIsIndependentFromStaleContextMenuVisibility() {
        var state = SidebarWorkspaceRowInteractionState()

        state.contextMenuDidAppear()
        state.contextMenuTrackingDidEnd()
        state.setPointerHovering(true)

        #expect(
            state.shouldShowCloseButton(
                canCloseWorkspace: true,
                shortcutHintModeActive: false
            ),
            "A stale SwiftUI context-menu lifecycle flag must not permanently suppress hover-only close affordances after AppKit menu tracking has ended."
        )

        state.setPointerHovering(false)

        #expect(
            !state.shouldShowCloseButton(
                canCloseWorkspace: true,
                shortcutHintModeActive: false
            ),
            "The stale SwiftUI menu flag must not make the close affordance visible when the pointer is no longer hovering."
        )
    }

    @Test func contextMenuTrackingBeginHidesExistingCloseButtonBeforeSwiftUIMenuAppears() {
        var state = SidebarWorkspaceRowInteractionState()

        state.setPointerHovering(true)
        #expect(state.shouldShowCloseButton(canCloseWorkspace: true, shortcutHintModeActive: false))

        state.contextMenuTrackingDidBegin()

        #expect(
            !state.shouldShowCloseButton(
                canCloseWorkspace: true,
                shortcutHintModeActive: false
            ),
            "Right-click menu tracking must hide an already-visible close affordance even before SwiftUI reports the context menu appearance."
        )
    }

    @Test func hoverDuringContextMenuTrackingStaysHiddenUntilTrackingEnds() {
        var state = SidebarWorkspaceRowInteractionState()

        state.contextMenuDidAppear()
        state.setPointerHovering(true)

        #expect(
            !state.shouldShowCloseButton(
                canCloseWorkspace: true,
                shortcutHintModeActive: false
            ),
            "Pointer hover updates observed during context-menu tracking must not reveal the close affordance under the menu."
        )

        state.contextMenuTrackingDidEnd()

        #expect(
            state.shouldShowCloseButton(
                canCloseWorkspace: true,
                shortcutHintModeActive: false
            ),
            "Once AppKit menu tracking ends, the last reconciled pointer position may reveal the close affordance even if SwiftUI menu state is stale."
        )
    }

    @Test func coordinatorPreservesHoverExitWhileMenuTrackingSuppressesCloseButton() {
        var state = SidebarWorkspaceRowInteractionState()
        let binding = Binding<SidebarWorkspaceRowInteractionState>(
            get: { state },
            set: { state = $0 }
        )
        let coordinator = SidebarWorkspaceRowHoverTracker.Coordinator(
            rowInteractionState: binding
        )

        coordinator.menuTrackingChanged(true)
        coordinator.pointerHoverChanged(true)
        coordinator.pointerHoverChanged(false)
        coordinator.menuTrackingChanged(false)

        #expect(
            !state.shouldShowCloseButton(
                canCloseWorkspace: true,
                shortcutHintModeActive: false
            ),
            "A pointer exit observed during menu tracking must overwrite any earlier deferred hover enter before the menu dismisses."
        )
    }

    @Test func menuTrackingSuppressionOnlyAppliesToPointerMenusInsideRow() {
        #expect(SidebarWorkspaceRowMenuTrackingScope.shouldSuppressCloseButton(
            pointerInsideRow: true,
            eventType: .rightMouseDown,
            modifierFlags: []
        ))
        #expect(SidebarWorkspaceRowMenuTrackingScope.shouldSuppressCloseButton(
            pointerInsideRow: true,
            eventType: .leftMouseDown,
            modifierFlags: .control
        ))
        #expect(
            !SidebarWorkspaceRowMenuTrackingScope.shouldSuppressCloseButton(
                pointerInsideRow: false,
                eventType: .rightMouseDown,
                modifierFlags: []
            ),
            "A menu opened outside this row must not suppress this row's hover state."
        )
        #expect(
            !SidebarWorkspaceRowMenuTrackingScope.shouldSuppressCloseButton(
                pointerInsideRow: true,
                eventType: .keyDown,
                modifierFlags: []
            ),
            "Keyboard-driven or app-level menu tracking must not be treated like this row's pointer context menu."
        )
    }

    @Test func pointerExitWhileContextMenuIsVisibleStaysHiddenAfterDismissal() {
        var state = SidebarWorkspaceRowInteractionState()

        state.setPointerHovering(true)
        state.contextMenuDidAppear()
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
