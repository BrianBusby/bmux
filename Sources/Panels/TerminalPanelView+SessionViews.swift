import SwiftUI

extension TerminalPanelView {
    var terminalBody: some View {
        AgentSessionFactualProjectionModeHost(
            showsSwitcher: showsFactualSessionSwitcher || terminalChatReader != nil,
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
            backgroundColor: appearance.contentBackgroundColor,
            workspaceChrome: workspaceChrome
        ) { isVisibleForMode in
            terminalSurfaceBody(isVisibleForMode: isVisibleForMode)
        }
    }

}
