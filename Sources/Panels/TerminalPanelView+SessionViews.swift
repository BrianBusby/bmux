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
    @ViewBuilder var terminalBody: some View {
        if let launch = panel.presentation.configuredCodexLaunch, let failure = launch.failureMessage {
            VStack(spacing: 12) {
                Text(failure).multilineTextAlignment(.center)
                Button(String(localized: "agentSession.chat.retryManagedLaunch", defaultValue: "Retry Codex launch")) { launch.retry() }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            AgentSessionFactualProjectionModeHost(
                showsSwitcher: !bmuxShellTerminalOnly && (showsFactualSessionSwitcher || terminalChatReader != nil),
                chatContent: terminalChatReader.map { reader in
                    { onTerminal in AnyView(TerminalChatWebRenderer(
                        panel: panel, reader: reader, appearance: appearance,
                        onStartConnectedSession: onStartConnectedSession,
                        onRequestPanelFocus: onRequestTerminalChatFocus,
                        onTerminal: onTerminal
                    )) }
                },
                stableWorkspaceID: stableWorkspaceId,
                workProvenanceRuntime: workProvenanceRuntime,
                backgroundColor: appearance.contentBackgroundColor
            ) { isVisibleForMode in
                if panel.presentation.configuredCodexLaunch?.isStarting == true {
                    ProgressView(String(localized: "agentSession.chat.chatLoading", defaultValue: "Loading conversation"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    terminalSurfaceBody(isVisibleForMode: isVisibleForMode)
                }
            }
        }
    }

}
