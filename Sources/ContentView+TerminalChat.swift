import SwiftUI
import BmuxFoundation
import BmuxAppKitSupportUI

extension ContentView {
    func bmuxShellChatContent(theme: MatteTheme) -> ((AgentSessionFactualProjectionMode, @escaping () -> Void, @escaping () -> Void) -> AnyView)? {
        guard let workspace = tabManager.selectedWorkspace,
              let panel = workspace.focusedTerminalPanel,
              let reader = tabManager.terminalChatReader else { return nil }
        let config = GhosttyConfig.load(globalFontMagnificationPercent: GlobalFontMagnification.storedPercent)
        return { mode, onTerminal, onChat in
            AnyView(
                TerminalChatWebRenderer(
                    panel: panel, reader: reader, appearance: .fromConfig(config),
                    fontFamily: config.fontFamily, fontSize: config.fontSize,
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
