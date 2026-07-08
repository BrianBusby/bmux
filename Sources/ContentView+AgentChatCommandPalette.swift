import AppKit
import BmuxCommandPalette

extension ContentView {
    func commandPaletteConfigActionID(for commandId: String) -> String? {
        switch commandId {
        case "palette.newTerminalTab":
            return BmuxSurfaceTabBarBuiltInAction.newTerminal.configID
        case "palette.newBrowserTab":
            return BmuxSurfaceTabBarBuiltInAction.newBrowser.configID
        case "palette.newAgentChat":
            return BmuxSurfaceTabBarBuiltInAction.newAgentChat.configID
        case "palette.terminalSplitRight":
            return BmuxSurfaceTabBarBuiltInAction.splitRight.configID
        case "palette.terminalSplitDown":
            return BmuxSurfaceTabBarBuiltInAction.splitDown.configID
        default:
            return nil
        }
    }

    static func commandPaletteNewAgentChatContribution() -> CommandPaletteCommandContribution {
        CommandPaletteCommandContribution(
            commandId: "palette.newAgentChat",
            title: { _ in String(localized: "command.newAgentChat.title", defaultValue: "New agent chat") },
            subtitle: { _ in String(localized: "command.newAgentChat.subtitle", defaultValue: "Agent Chat") },
            keywords: ["create", "new", "agent", "chat", "browser", "codex", "claude"],
            when: { !$0.bool(CommandPaletteContextKeys.browserDisabled) }
        )
    }

    func registerAgentChatCommandPaletteHandler(_ registry: inout CommandPaletteHandlerRegistry) {
        registry.register(commandId: "palette.newAgentChat") {
            guard let appDelegate = AppDelegate.shared else {
                NSSound.beep()
                return
            }
            if !appDelegate.executeConfiguredBmuxAction(
                id: BmuxSurfaceTabBarBuiltInAction.newAgentChat.configID,
                tabManager: tabManager,
                preferredWindow: appDelegate.mainWindow(for: windowId)
            ) {
                NSSound.beep()
            }
        }
    }
}
