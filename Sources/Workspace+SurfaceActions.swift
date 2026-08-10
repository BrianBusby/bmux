import Foundation
import BmuxTerminal
import Bonsplit

extension Workspace {
    enum SurfaceReorderActionTarget: Equatable {
        case index(Int)
        case before(UUID)
        case after(UUID)
    }

    enum SurfaceReorderActionResult: Equatable {
        case reordered(paneId: PaneID)
        case surfaceNotFound
        case anchorNotInSamePane
        case failed
    }

    enum SurfaceMoveActionResult: Equatable {
        case moved(paneId: PaneID)
        case surfaceNotFound
        case targetPaneNotFound
        case failed
    }

    @discardableResult
    func createTerminalSurfaceForAction(
        inPane paneId: PaneID,
        focus: Bool? = nil,
        workingDirectory: String? = nil,
        initialCommand: String? = nil,
        tmuxStartCommand: String? = nil,
        initialInput: String? = nil,
        startupEnvironment: [String: String] = [:],
        runtimeSpawnPolicy: TerminalSurfaceRuntimeSpawnPolicy = .immediate,
        autoRefreshMetadata: Bool = true,
        preserveFocusWhenUnfocused: Bool = true,
        remotePTYSessionID: String? = nil,
        suppressWorkspaceRemoteStartupCommand: Bool = false,
        restoredSurfaceId: UUID? = nil,
        inheritWorkingDirectoryFallback: Bool = false,
        workingDirectoryFallbackSourcePanelId: UUID? = nil,
        terminalConfigPreferredPanelId: UUID? = nil,
        terminalConfigFallbackPaneId: PaneID? = nil,
        lifecyclePublication: TerminalPanelCreationPublication = .surfaceCreated(origin: "terminal_tab"),
        allowTextBoxFocusDefault: Bool = true
    ) -> TerminalPanelCreationOutcome {
        newTerminalSurfaceOutcome(
            inPane: paneId,
            focus: focus,
            workingDirectory: workingDirectory,
            initialCommand: initialCommand,
            tmuxStartCommand: tmuxStartCommand,
            initialInput: initialInput,
            startupEnvironment: startupEnvironment,
            runtimeSpawnPolicy: runtimeSpawnPolicy,
            autoRefreshMetadata: autoRefreshMetadata,
            preserveFocusWhenUnfocused: preserveFocusWhenUnfocused,
            remotePTYSessionID: remotePTYSessionID,
            suppressWorkspaceRemoteStartupCommand: suppressWorkspaceRemoteStartupCommand,
            restoredSurfaceId: restoredSurfaceId,
            inheritWorkingDirectoryFallback: inheritWorkingDirectoryFallback,
            workingDirectoryFallbackSourcePanelId: workingDirectoryFallbackSourcePanelId,
            terminalConfigPreferredPanelId: terminalConfigPreferredPanelId,
            terminalConfigFallbackPaneId: terminalConfigFallbackPaneId,
            lifecyclePublication: lifecyclePublication,
            allowTextBoxFocusDefault: allowTextBoxFocusDefault
        )
    }

    @discardableResult
    func createTerminalSplitForAction(
        from panelId: UUID,
        orientation: SplitOrientation,
        insertFirst: Bool = false,
        focus: Bool = true,
        workingDirectory: String? = nil,
        initialCommand: String? = nil,
        tmuxStartCommand: String? = nil,
        initialInput: String? = nil,
        startupEnvironment: [String: String] = [:],
        initialDividerPosition: CGFloat? = nil,
        remotePTYSessionID: String? = nil,
        suppressWorkspaceRemoteStartupCommand: Bool = false,
        inheritWorkingDirectoryFallback: Bool = true,
        allowTextBoxFocusDefault: Bool = true
    ) -> TerminalPanelCreationOutcome {
        newTerminalSplitOutcome(
            from: panelId,
            orientation: orientation,
            insertFirst: insertFirst,
            focus: focus,
            workingDirectory: workingDirectory,
            initialCommand: initialCommand,
            tmuxStartCommand: tmuxStartCommand,
            initialInput: initialInput,
            startupEnvironment: startupEnvironment,
            initialDividerPosition: initialDividerPosition,
            remotePTYSessionID: remotePTYSessionID,
            suppressWorkspaceRemoteStartupCommand: suppressWorkspaceRemoteStartupCommand,
            inheritWorkingDirectoryFallback: inheritWorkingDirectoryFallback,
            allowTextBoxFocusDefault: allowTextBoxFocusDefault
        )
    }

    @discardableResult
    func createBrowserSurfaceForAction(
        inPane paneId: PaneID,
        url: URL? = nil,
        initialRequest: URLRequest? = nil,
        focus: Bool? = nil,
        selectWhenNotFocused: Bool = false,
        insertAtEnd: Bool = false,
        preferredProfileID: UUID? = nil,
        bypassInsecureHTTPHostOnce: String? = nil,
        creationPolicy: BrowserPanelCreationPolicy = .userInitiated,
        omnibarVisible: Bool = true,
        transparentBackground: Bool = false,
        bypassRemoteProxy: Bool = false
    ) -> BrowserPanel? {
        newBrowserSurface(
            inPane: paneId,
            url: url,
            initialRequest: initialRequest,
            focus: focus,
            selectWhenNotFocused: selectWhenNotFocused,
            insertAtEnd: insertAtEnd,
            preferredProfileID: preferredProfileID,
            bypassInsecureHTTPHostOnce: bypassInsecureHTTPHostOnce,
            creationPolicy: creationPolicy,
            omnibarVisible: omnibarVisible,
            transparentBackground: transparentBackground,
            bypassRemoteProxy: bypassRemoteProxy
        )
    }

    @discardableResult
    func createBrowserSplitForAction(
        from panelId: UUID,
        orientation: SplitOrientation,
        insertFirst: Bool = false,
        url: URL? = nil,
        preferredProfileID: UUID? = nil,
        focus: Bool = true,
        creationPolicy: BrowserPanelCreationPolicy = .userInitiated,
        omnibarVisible: Bool = true,
        transparentBackground: Bool = false,
        bypassRemoteProxy: Bool = false,
        initialDividerPosition: CGFloat? = nil
    ) -> BrowserPanel? {
        newBrowserSplit(
            from: panelId,
            orientation: orientation,
            insertFirst: insertFirst,
            url: url,
            preferredProfileID: preferredProfileID,
            focus: focus,
            creationPolicy: creationPolicy,
            omnibarVisible: omnibarVisible,
            transparentBackground: transparentBackground,
            bypassRemoteProxy: bypassRemoteProxy,
            initialDividerPosition: initialDividerPosition
        )
    }

    @discardableResult
    func reorderSurfaceForAction(
        panelId: UUID,
        target: SurfaceReorderActionTarget,
        focus: Bool = true
    ) -> SurfaceReorderActionResult {
        guard panels[panelId] != nil,
              let sourcePane = paneId(forPanelId: panelId) else {
            return .surfaceNotFound
        }

        let targetIndex: Int
        switch target {
        case .index(let index):
            targetIndex = index
        case .before(let anchorPanelId):
            guard let anchorPane = paneId(forPanelId: anchorPanelId),
                  anchorPane == sourcePane,
                  let anchorIndex = indexInPane(forPanelId: anchorPanelId) else {
                return .anchorNotInSamePane
            }
            targetIndex = anchorIndex
        case .after(let anchorPanelId):
            guard let anchorPane = paneId(forPanelId: anchorPanelId),
                  anchorPane == sourcePane,
                  let anchorIndex = indexInPane(forPanelId: anchorPanelId) else {
                return .anchorNotInSamePane
            }
            targetIndex = anchorIndex + 1
        }

        guard reorderSurface(panelId: panelId, toIndex: targetIndex, focus: focus) else {
            return .failed
        }
        return .reordered(paneId: sourcePane)
    }

    @discardableResult
    func moveSurfaceForAction(
        panelId: UUID,
        toPane paneId: PaneID,
        atIndex index: Int? = nil,
        focus: Bool = true
    ) -> SurfaceMoveActionResult {
        guard panels[panelId] != nil,
              surfaceIdFromPanelId(panelId) != nil else {
            return .surfaceNotFound
        }
        guard bonsplitController.allPaneIds.contains(paneId) else {
            return .targetPaneNotFound
        }
        guard moveSurface(panelId: panelId, toPane: paneId, atIndex: index, focus: focus) else {
            return .failed
        }
        return .moved(paneId: paneId)
    }

    @discardableResult
    func renameSurfaceTitleForAction(
        surfaceId: UUID,
        title: String
    ) -> CustomTitleApplyOutcome {
        applySurfaceTitleEditForAction(
            surfaceId: surfaceId,
            title: title,
            emptyTitleClears: false
        )
    }

    @discardableResult
    func commitSurfaceTitleEditForAction(
        surfaceId: UUID,
        title: String
    ) -> CustomTitleApplyOutcome {
        applySurfaceTitleEditForAction(
            surfaceId: surfaceId,
            title: title,
            emptyTitleClears: true
        )
    }

    @discardableResult
    func clearSurfaceTitleForAction(surfaceId: UUID) -> CustomTitleApplyOutcome {
        applySurfaceTitleEditForAction(
            surfaceId: surfaceId,
            title: nil,
            emptyTitleClears: true
        )
    }

    @discardableResult
    func setSurfacePinnedForAction(surfaceId: UUID, pinned: Bool) -> Bool {
        guard panels[surfaceId] != nil else { return false }
        setPanelPinned(panelId: surfaceId, pinned: pinned)
        return true
    }

    @discardableResult
    func toggleSurfacePinnedForAction(surfaceId: UUID) -> Bool? {
        guard panels[surfaceId] != nil else { return nil }
        let pinned = !isPanelPinned(surfaceId)
        setPanelPinned(panelId: surfaceId, pinned: pinned)
        return pinned
    }

    func surfaceIsUnreadForAction(surfaceId: UUID) -> Bool? {
        guard panels[surfaceId] != nil else { return nil }
        return manualUnreadPanelIds.contains(surfaceId) ||
            restoredUnreadPanelIds.contains(surfaceId) ||
            hasUnreadNotificationForSurfaceAction(panelId: surfaceId)
    }

    @discardableResult
    func setSurfaceUnreadForAction(surfaceId: UUID, unread: Bool) -> Bool {
        guard panels[surfaceId] != nil else { return false }
        if unread {
            markPanelUnread(surfaceId)
        } else {
            markPanelRead(surfaceId)
        }
        return true
    }

    @discardableResult
    func toggleSurfaceUnreadForAction(surfaceId: UUID) -> Bool? {
        guard let isUnread = surfaceIsUnreadForAction(surfaceId: surfaceId) else { return nil }
        let unread = !isUnread
        setSurfaceUnreadForAction(surfaceId: surfaceId, unread: unread)
        return unread
    }

    @discardableResult
    func toggleSurfaceSplitZoomForAction(surfaceId: UUID) -> Bool {
        guard panels[surfaceId] != nil else { return false }
        return toggleSplitZoom(panelId: surfaceId)
    }

    @discardableResult
    func toggleSurfaceFullWidthTabForAction(surfaceId: UUID) -> Bool? {
        guard panels[surfaceId] != nil,
              let paneId = paneId(forPanelId: surfaceId),
              toggleFullWidthTabMode(panelId: surfaceId) else {
            return nil
        }
        return bonsplitController.isFullWidthTabMode(inPane: paneId)
    }

    @discardableResult
    func applySurfaceTitleEditForAction(
        surfaceId: UUID,
        title: String?,
        emptyTitleClears: Bool
    ) -> CustomTitleApplyOutcome {
        guard let panelId = panelIdForSurfaceTitleAction(surfaceId) else {
            return .rejected(.targetMissing)
        }
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            if emptyTitleClears {
                return applyPanelCustomTitle(panelId: panelId, title: nil, source: .user)
            }
            return .rejected(.emptyTitle)
        }
        return applyPanelCustomTitle(panelId: panelId, title: trimmed, source: .user)
    }

    private func panelIdForSurfaceTitleAction(_ surfaceId: UUID) -> UUID? {
        if panels[surfaceId] != nil {
            return surfaceId
        }
        return panelIdFromSurfaceId(TabID(uuid: surfaceId))
    }
}
