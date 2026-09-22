import SwiftUI

private struct BmuxShellTerminalOnlyKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var bmuxShellTerminalOnly: Bool {
        get { self[BmuxShellTerminalOnlyKey.self] }
        set { self[BmuxShellTerminalOnlyKey.self] = newValue }
    }
}

extension TerminalPanelView {
    var terminalBody: some View {
        AgentSessionFactualProjectionModeHost(
            showsSwitcher: !bmuxShellTerminalOnly && (showsFactualSessionSwitcher || terminalChatReader != nil),
            chatContent: terminalChatReader.map { reader in
                { onTerminal in AnyView(TerminalChatWebRenderer(
                    panel: panel, reader: reader, appearance: appearance,
                    onStartConnectedSession: onStartConnectedSession,
                    onRequestPanelFocus: onRequestTerminalChatFocus,
                    onTerminal: onTerminal
                ).onDisappear { panel.isChatPresentationActive = false }) }
            },
            stableWorkspaceID: stableWorkspaceId,
            workProvenanceRuntime: workProvenanceRuntime,
            backgroundColor: appearance.contentBackgroundColor
        ) { isVisibleForMode in
            terminalSurfaceBody(isVisibleForMode: isVisibleForMode)
        }
    }

}
