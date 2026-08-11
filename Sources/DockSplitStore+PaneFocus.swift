import AppKit
import Bonsplit

extension DockSplitStore {
    func noteKeyboardFocusIntent(window: NSWindow?) {
        AppDelegate.shared?.noteRightSidebarKeyboardFocusIntent(mode: .dock, in: window)
    }

    @discardableResult
    func requestPanelFocusForAction(panelId: UUID, window: NSWindow?) -> Bool {
        guard containsPanel(panelId) else { return false }
        noteKeyboardFocusIntent(window: window)
        focusPanel(panelId)
        return true
    }

    @discardableResult
    func closePanelForAction(panelId: UUID, force: Bool = false) -> Bool {
        guard closePanel(panelId, force: force) else { return false }
        AppDelegate.shared?.notificationStore?.clearNotifications(
            forTabId: workspaceId,
            surfaceId: panelId
        )
        return true
    }

    @discardableResult
    func createSurfaceForAction(
        kind: DockSurfaceKind,
        inPane paneId: PaneID,
        url: URL? = nil,
        initialRequest: URLRequest? = nil,
        command: String? = nil,
        workingDirectory: String? = nil,
        environment: [String: String] = [:],
        tmuxStartCommand: String? = nil,
        focus: Bool = true,
        preferredProfileID: UUID? = nil,
        bypassInsecureHTTPHostOnce: String? = nil
    ) -> UUID? {
        newSurface(
            kind: kind,
            inPane: paneId,
            url: url,
            initialRequest: initialRequest,
            command: command,
            workingDirectory: workingDirectory,
            environment: environment,
            tmuxStartCommand: tmuxStartCommand,
            focus: focus,
            preferredProfileID: preferredProfileID,
            bypassInsecureHTTPHostOnce: bypassInsecureHTTPHostOnce
        )
    }

    @discardableResult
    func createSplitForAction(
        kind: DockSurfaceKind,
        orientation: SplitOrientation,
        insertFirst: Bool,
        sourcePanelId: UUID?,
        url: URL? = nil,
        command: String? = nil,
        workingDirectory: String? = nil,
        environment: [String: String] = [:],
        tmuxStartCommand: String? = nil,
        initialDividerPosition: CGFloat? = nil,
        focus: Bool = true
    ) -> UUID? {
        newSplit(
            kind: kind,
            orientation: orientation,
            insertFirst: insertFirst,
            sourcePanelId: sourcePanelId,
            url: url,
            command: command,
            workingDirectory: workingDirectory,
            environment: environment,
            tmuxStartCommand: tmuxStartCommand,
            initialDividerPosition: initialDividerPosition,
            focus: focus
        )
    }

    func focusedDockPaneSelection() -> (pane: PaneID?, tab: TabID?) {
        let pane = bonsplitController.focusedPaneId
        return (pane, pane.flatMap { bonsplitController.selectedTab(inPane: $0)?.id })
    }

    func restoreDockPaneSelection(_ selection: (pane: PaneID?, tab: TabID?)?) {
        guard let selection else { return }
        if let pane = selection.pane {
            bonsplitController.focusPane(pane)
        }
        if let tab = selection.tab {
            bonsplitController.selectTab(tab)
        }
    }

    /// Creates a new surface in the currently focused Dock pane (Dock toolbar "+" menu).
    func newInFocusedPane(kind: DockSurfaceKind) {
        ensureLoaded()
        guard let paneId = bonsplitController.focusedPaneId ?? bonsplitController.allPaneIds.first else { return }
        _ = createSurfaceForAction(kind: kind, inPane: paneId, focus: true)
    }

    func collapseToSingleEmptyPane() {
        guard let rootPane = bonsplitController.allPaneIds.first else { return }
        for paneId in bonsplitController.allPaneIds where paneId != rootPane {
            _ = bonsplitController.closePane(paneId)
        }
        bonsplitController.focusPane(rootPane)
    }

    func paneIsRenderedInVisibleDock(_ paneId: PaneID) -> Bool {
        guard isVisibleInUI else { return false }
        guard let zoomedPaneId = bonsplitController.zoomedPaneId else { return true }
        return zoomedPaneId == paneId
    }

    func panelIsSelectedInVisibleDockPane(_ panelId: UUID) -> Bool {
        guard let tabId = surfaceId(forPanelId: panelId),
              let paneId = paneId(forPanelId: panelId) else { return false }
        guard paneIsRenderedInVisibleDock(paneId) else { return false }
        return bonsplitController.selectedTab(inPane: paneId)?.id == tabId
    }

    func panelIsActiveInVisibleDockPane(_ panelId: UUID) -> Bool {
        panelIsSelectedInVisibleDockPane(panelId) && focusedPanelId == panelId
    }

    @discardableResult
    func toggleDockPaneZoom(inPane paneId: PaneID) -> Bool {
        guard bonsplitController.togglePaneZoom(inPane: paneId) else { return false }
        bonsplitController.focusPane(paneId)
        applyVisibilityToAllPanels()
        return true
    }

    func applyVisibilityToAllPanels() {
        forEachPanel { _, panel in applyVisibility(to: panel) }
    }

    func withCoalescedTerminalViewReattach(_ body: () -> Void) {
        terminalViewReattachCoalescingDepth += 1
        defer {
            terminalViewReattachCoalescingDepth -= 1
            if terminalViewReattachCoalescingDepth == 0 {
                let pendingPanelIds = pendingTerminalViewReattachPanelIds
                pendingTerminalViewReattachPanelIds.removeAll()
                for panelId in pendingPanelIds {
                    (panels[panelId] as? TerminalPanel)?.requestViewReattach()
                }
            }
        }
        body()
    }

    func requestTerminalViewReattach(_ terminal: TerminalPanel) {
        if terminalViewReattachCoalescingDepth > 0 {
            pendingTerminalViewReattachPanelIds.insert(terminal.id)
        } else {
            terminal.requestViewReattach()
        }
    }

    func applyFocusedDockSelection() {
        guard let paneId = bonsplitController.focusedPaneId,
              let tabId = bonsplitController.selectedTab(inPane: paneId)?.id else {
            applyVisibilityToAllPanels()
            return
        }
        applyDockSelection(tabId: tabId, inPane: paneId)
    }

    func applyDockSelection(tabId: TabID, inPane pane: PaneID) {
        applyVisibilityToAllPanels()
        guard paneIsRenderedInVisibleDock(pane),
              bonsplitController.focusedPaneId == pane,
              let selectedPanel = panel(for: tabId) else { return }

        let activationIntent = selectedPanel.preferredFocusIntentForActivation()
        selectedPanel.prepareFocusIntentForActivation(activationIntent)
        forEachPanel { panelId, panel in
            if panelId != selectedPanel.id {
                panel.unfocus()
            }
        }
        selectedPanel.focus()
    }

    func splitTabBar(_ controller: BonsplitController, didSelectTab tab: Bonsplit.Tab, inPane pane: PaneID) {
        applyDockSelection(tabId: tab.id, inPane: pane)
    }

    func splitTabBar(_ controller: BonsplitController, didFocusPane pane: PaneID) {
        guard let tab = controller.selectedTab(inPane: pane) else {
            applyVisibilityToAllPanels()
            return
        }
        applyDockSelection(tabId: tab.id, inPane: pane)
    }

    /// Mirrors `Workspace.splitTabBar(_:didSplitPane:…)` so the Dock's split
    /// buttons (Split Right / Split Down) and drag-to-split behave like the main
    /// split area. `splitPane` always creates an EMPTY new pane; without this the
    /// Dock's `autoCloseEmptyPanes` config tears it down immediately, so a split
    /// appeared to do nothing.
    func splitTabBar(
        _ controller: BonsplitController,
        didSplitPane originalPane: PaneID,
        newPane: PaneID,
        orientation: SplitOrientation
    ) {
        // Programmatic splits (config seed, `newSplit`, cross-container transfer)
        // seed their own new-pane tab, so don't auto-create another.
        guard !isProgrammaticDockSplit else { return }

        if !controller.tabs(inPane: newPane).isEmpty {
            // Drag-to-split: an existing tab was dragged to a pane edge. Bonsplit
            // may leave the source pane holding only a placeholder "Empty" tab —
            // replace it with a real terminal so we never show a tabless pane.
            repairPlaceholderOnlyDockPane(originalPane)
            return
        }

        // Split button: the new pane is empty. Seed a terminal in it, matching
        // the main area (which always seeds a terminal on a UI split).
        _ = createSurfaceForAction(kind: .terminal, inPane: newPane, focus: true)
    }

    /// Mirrors `Workspace.splitTabBar(_:didMoveTab:…)`: keep the moved panel
    /// selected/focused in its destination pane and re-render it at the new
    /// geometry when a tab is dragged between Dock panes.
    func splitTabBar(
        _ controller: BonsplitController,
        didMoveTab tab: Bonsplit.Tab,
        fromPane source: PaneID,
        toPane destination: PaneID
    ) {
        applyDockSelection(tabId: tab.id, inPane: destination)
        panel(for: tab.id)?.focus()
    }

    /// Replaces a pane that holds only placeholder (panel-less) tabs with a real
    /// Dock terminal, dropping the placeholders. Used after drag-to-split leaves
    /// the source pane tabless.
    private func repairPlaceholderOnlyDockPane(_ pane: PaneID) {
        let tabs = bonsplitController.tabs(inPane: pane)
        guard !tabs.isEmpty, !tabs.contains(where: { panel(for: $0.id) != nil }) else { return }
        _ = newSurface(kind: .terminal, inPane: pane, focus: false)
        for tab in bonsplitController.tabs(inPane: pane) where panel(for: tab.id) == nil {
            _ = bonsplitController.closeTab(tab.id)
        }
    }

    func applyVisibility(to panel: any Panel) {
        let shouldBeVisible = panelIsSelectedInVisibleDockPane(panel.id)
        let shouldBeActive = panelIsActiveInVisibleDockPane(panel.id)
        if let terminal = panel as? TerminalPanel {
            if shouldBeVisible {
                terminal.hostedView.setVisibleInUI(true)
                terminal.hostedView.setActive(shouldBeActive)
                let needsPortalReattach = TerminalWindowPortalRegistry
                    .updateEntryVisibility(for: terminal.hostedView, visibleInUI: true)
                if needsPortalReattach {
                    requestTerminalViewReattach(terminal)
                }
            } else {
                terminal.unfocus()
                terminal.hostedView.setVisibleInUI(false)
                TerminalWindowPortalRegistry.hideHostedView(terminal.hostedView)
            }
        } else if let browser = panel as? BrowserPanel {
            if !shouldBeVisible {
                browser.unfocus()
                browser.hideBrowserPortalView(source: "dockHidden")
            }
        }
    }
}
