import SwiftUI
import BmuxAppKitSupportUI

extension ContentView {
    func bmuxShellChatContent(theme: MatteTheme) -> ((AgentSessionFactualProjectionMode, @escaping () -> Void, @escaping () -> Void) -> AnyView)? {
        guard let workspace = tabManager.selectedWorkspace,
              let panel = workspace.focusedTerminalPanel,
              let reader = tabManager.terminalChatReader else { return nil }
        return { mode, onTerminal, onChat in
            AnyView(
                TerminalChatWebRenderer(
                    panel: panel, reader: reader, appearance: .fromConfig(GhosttyConfig.load()),
                    matteTheme: theme,
                    presentationMode: mode,
                    onStartConnectedSession: workspace.remoteConfiguration == nil && !workspace.isRemoteTmuxMirror ? { [weak workspace, panelID = panel.id] in
                        guard let workspace else { throw AgentSessionBridgeError.invalidRequest }
                        try await workspace.startConnectedCodex(from: panelID)
                    } : nil,
                    onRequestPanelFocus: { [weak workspace, panelID = panel.id] in workspace?.focusConnectedCodexChat(panelID: panelID) },
                    onChat: onChat,
                    onTerminal: onTerminal
                ).id(panel.id)
            )
        }
    }
}
