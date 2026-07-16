import AppKit
import SwiftUI

struct MinimalModeSidebarTitlebarControlsOverlay: View {
    let notificationStore: TerminalNotificationStore
    let leadingInset: CGFloat
    let topPadding: CGFloat
    let onToggleSidebar: () -> Void
    let onToggleNotifications: (NSView?) -> Void
    let onToggleVoiceInput: () -> Void
    let onNewTab: () -> Void
    let onFocusHistoryBack: () -> Void
    let onFocusHistoryForward: () -> Void
    let onShowRepoAgentLaunchers: (NSView) -> Void

    @AppStorage(WorkspacePresentationModeSettings.modeKey)
    private var workspacePresentationMode = WorkspacePresentationModeSettings.defaultMode.rawValue

    private var isMinimalMode: Bool {
        WorkspacePresentationModeSettings.mode(for: workspacePresentationMode) == .minimal
    }

    var body: some View {
        if isMinimalMode {
            HiddenTitlebarSidebarControlsView(
                notificationStore: notificationStore,
                onToggleSidebar: onToggleSidebar,
                onToggleNotifications: onToggleNotifications,
                onToggleVoiceInput: onToggleVoiceInput,
                onNewTab: onNewTab,
                onFocusHistoryBack: onFocusHistoryBack,
                onFocusHistoryForward: onFocusHistoryForward,
                onShowRepoAgentLaunchers: onShowRepoAgentLaunchers
            )
            .padding(.leading, leadingInset)
            .padding(.top, topPadding)
        }
    }
}
