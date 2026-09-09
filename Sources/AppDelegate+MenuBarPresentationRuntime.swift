import AppKit
import Foundation

extension AppDelegate {
    func startMenuBarPresentationRuntime() {
        appRuntimeServices?.startMenuBarPresentationLifecycle(
            actions: menuBarPresentationRuntimeUIActions()
        )
    }

    func toggleGlobalSearchPaletteFromGlobalHotkey() {
        guard appRuntimeServices?.toggleGlobalSearchPaletteFromMenuBarRuntime() == true else {
            NSSound.beep()
            return
        }
    }

    private func menuBarPresentationRuntimeUIActions() -> MenuBarPresentationRuntimeUIActions {
        MenuBarPresentationRuntimeUIActions(
            makeMenuBarExtraController: { [weak delegate = self] in
                let store = TerminalNotificationStore.shared
                return MenuBarExtraController(
                    notificationStore: store,
                    onShowGlobalSearch: { button, onDismiss in
                        GlobalSearchCoordinator.shared.togglePalette(anchor: button, onDismiss: onDismiss)
                    },
                    onShowMainWindow: { [weak delegate] in
                        delegate?.showMainWindowFromMenuBar()
                    },
                    onShowNotifications: { [weak delegate] in
                        delegate?.showNotificationsPopoverFromMenuBar()
                    },
                    onOpenNotification: { [weak delegate] notification in
                        _ = delegate?.openTerminalNotification(notification)
                    },
                    onJumpToLatestUnread: { [weak delegate] in
                        delegate?.jumpToLatestUnread()
                    },
                    onOpenTaskManager: {
                        TaskManagerWindowController.shared.show()
                    },
                    onToggleSleepyMode: {
                        SleepyModeController.shared.toggle()
                    },
                    onCheckForUpdates: { [weak delegate] in
                        delegate?.checkForUpdates(nil)
                    },
                    onOpenPreferences: { [weak delegate] in
                        delegate?.openPreferencesWindow(debugSource: "menuBarExtra")
                    },
                    onQuitApp: {
                        NSApp.terminate(nil)
                    }
                )
            }
        )
    }
}
