import Foundation

extension TabManager {
    /// Local explicit-command terminals retain their output; remote exits keep their existing recovery owner.
    func shouldKeepLocalCommandOpenAfterChildExit(tabId: UUID, surfaceId: UUID) -> Bool {
        guard let workspace = tabs.first(where: { $0.id == tabId }),
              !workspace.shouldDemoteWorkspaceAfterChildExit(surfaceId: surfaceId),
              !workspace.shouldKeepPersistentRemoteSurfaceOpenAfterChildExit(surfaceId),
              let panel = workspace.terminalPanel(for: surfaceId) else { return false }
        return panel.surface.waitsAfterCommand
    }

    /// Close a panel because its child process exited (e.g. the user hit Ctrl+D).
    ///
    /// This should never prompt: the process is already gone, and Ghostty emits the
    /// `SHOW_CHILD_EXITED` action specifically so the host app can decide what to do.
    func closePanelAfterChildExited(tabId: UUID, surfaceId: UUID) {
        guard let tab = tabs.first(where: { $0.id == tabId }) else { return }
        if shouldKeepLocalCommandOpenAfterChildExit(tabId: tabId, surfaceId: surfaceId) {
#if DEBUG
            bmuxDebugLog("surface.exit.preserve tab=\(tabId.uuidString.prefix(5)) surface=\(surfaceId.uuidString.prefix(5)) reason=waitAfterCommand")
#endif
            return
        }
        if tab.panels[surfaceId] == nil { tab.closeDockPanelAndClearNotifications(surfaceId, force: true); return }
        let keepsPersistentRemoteSurfaceOpen =
            tab.shouldKeepPersistentRemoteSurfaceOpenAfterChildExit(surfaceId)
        if !keepsPersistentRemoteSurfaceOpen,
           tab.shouldDemoteWorkspaceAfterChildExit(surfaceId: surfaceId) {
            let relayPort: Int?
            if tab.remoteConfiguration?.transport == .ssh {
                relayPort = tab.remoteConfiguration?.relayPort
            } else {
                relayPort = nil
            }
            tab.markRemoteTerminalSessionEnded(
                surfaceId: surfaceId,
                relayPort: relayPort,
                allowUntracked: !tab.isRemoteTerminalSurface(surfaceId)
            )
        }
        let handlesRemoteExitThroughWorkspace =
            tab.panels.count <= 1 && tab.shouldDemoteWorkspaceAfterChildExit(surfaceId: surfaceId)

#if DEBUG
        bmuxDebugLog(
            "surface.close.childExited tab=\(tabId.uuidString.prefix(5)) " +
            "surface=\(surfaceId.uuidString.prefix(5)) panels=\(tab.panels.count) workspaces=\(tabs.count) " +
            "remoteWorkspace=\(tab.isRemoteWorkspace ? 1 : 0) keepRemote=\(handlesRemoteExitThroughWorkspace ? 1 : 0) " +
            "keepPersistentRemote=\(keepsPersistentRemoteSurfaceOpen ? 1 : 0)"
        )
#endif

        // A persistent SSH workspace must never silently replace a failed remote attach with
        // a local login shell. Keep the exited surface visible so the user can see the error
        // and retry instead of making a detached remote workspace look local after relaunch.
        if keepsPersistentRemoteSurfaceOpen {
            tab.markPersistentRemotePTYAttachFailed(surfaceId: surfaceId)
            return
        }

        // Route the last remote child exit through Workspace close handling so remote teardown
        // and replacement-panel logic run before TabManager considers removing the workspace.
        if handlesRemoteExitThroughWorkspace {
            closeRuntimeSurface(tabId: tabId, surfaceId: surfaceId)
            return
        }

        // Child-exit on the last panel should collapse the workspace, matching explicit close
        // semantics (and close the window when it was the last workspace).
        if tab.panels.count <= 1 {
            if tabs.count <= 1 {
                if let app = AppDelegate.shared {
                    app.notificationStore?.clearNotifications(forTabId: tabId)
                    app.closeMainWindowContainingTabId(tabId, recordHistory: false)
                } else {
                    // Headless/test fallback when no AppDelegate window context exists.
                    closeRuntimeSurface(tabId: tabId, surfaceId: surfaceId)
                }
            } else {
                closeWorkspace(tab, recordHistory: false)
            }
            return
        }

        closeRuntimeSurface(tabId: tabId, surfaceId: surfaceId)
    }

}
