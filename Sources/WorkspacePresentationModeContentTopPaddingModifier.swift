import SwiftUI
import BmuxAppKitSupportUI

struct WorkspacePresentationModeContentTopPaddingModifier: ViewModifier {
    @Environment(\.bmuxShellTerminalOnly) private var isEmbeddedTerminal
    @Environment(\.colorScheme) private var colorScheme
    let isFullScreen: Bool
    let titlebarPadding: CGFloat
    let hostingSafeAreaTop: CGFloat

    @AppStorage(WorkspacePresentationModeSettings.modeKey)
    private var workspacePresentationMode = WorkspacePresentationModeSettings.defaultMode.rawValue

    private var isMinimalMode: Bool {
        WorkspacePresentationModeSettings.mode(for: workspacePresentationMode) == .minimal
    }

    func body(content: Content) -> some View {
        content.padding(.top, isEmbeddedTerminal
            ? MatteTheme(colorScheme: colorScheme).layout.embeddedTerminalTopGap
            : ContentView.effectiveTitlebarPadding(
            isMinimalMode: isMinimalMode,
            isFullScreen: isFullScreen,
            titlebarPadding: titlebarPadding,
            hostingSafeAreaTop: hostingSafeAreaTop
        ))
    }
}
