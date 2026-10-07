import SwiftUI

extension ContentView {
    func bmuxShellChatContent() -> ((@escaping () -> Void) -> AnyView)? {
        guard let workspace = tabManager.selectedWorkspace,
              let panel = workspace.focusedTerminalPanel,
              let reader = tabManager.terminalChatReader else { return nil }
        return { onTerminal in
            AnyView(
                TerminalChatWebRenderer(
                    panel: panel, reader: reader, appearance: .fromConfig(GhosttyConfig.load()),
                    onStartConnectedSession: workspace.remoteConfiguration == nil && !workspace.isRemoteTmuxMirror ? { [weak workspace, panelID = panel.id] in
                        guard let workspace else { throw AgentSessionBridgeError.invalidRequest }
                        try await workspace.startConnectedCodex(from: panelID)
                    } : nil,
                    onRequestPanelFocus: { [weak workspace, panelID = panel.id] in workspace?.focusConnectedCodexChat(panelID: panelID) },
                    onTerminal: onTerminal
                ).id(panel.id)
            )
        }
    }
}
