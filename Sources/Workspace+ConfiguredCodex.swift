import Foundation
import Bonsplit

extension Workspace {
    @MainActor
    func createConfiguredTerminalSurface(inPane pane: PaneID, shellInput: String) {
        guard let panel = createTerminalSurfaceForAction(inPane: pane, focus: true,
            inheritWorkingDirectoryFallback: true).panel else { return }
        sendConfiguredTerminalInput(shellInput, to: panel,
            workingDirectory: panel.requestedWorkingDirectory ?? currentDirectory)
    }

    /// Configured new-terminal launches share one path after action authorization.
    /// Compound/setup commands and existing terminal input keep their shell behavior.
    @MainActor
    func sendConfiguredTerminalInput(_ text: String, to panel: TerminalPanel,
                                     workingDirectory: String, environment: [String: String] = [:],
                                     allowsConnectedLaunch: Bool = true) {
        let launchEnvironment = startupEnvironmentMergingWorkspaceEnvironment(environment)
        guard allowsConnectedLaunch, remoteConfiguration == nil, !isRemoteTmuxMirror,
              let configuration = ConnectedCodexLaunchConfiguration(command: text, environment: launchEnvironment),
              let runtime = owningTabManager?.terminalChatReader as? any TerminalChatConnecting else {
            sendInputWhenReady(text, to: panel)
            return
        }
        guard panel.presentation.configuredCodexLaunch == nil else { return }
        let workspaceID = id
        let sourceID = panel.id
        let coordinator = ConfiguredCodexLaunchCoordinator(workspace: self, panel: panel,
            runtime: runtime, workingDirectory: workingDirectory, configuration: configuration) { message in
            TerminalNotificationStore.shared.addNotification(tabId: workspaceID, surfaceId: sourceID,
                title: String(localized: "agentSession.chat.connectedNewSession", defaultValue: "New connected Codex session"), subtitle: "",
                body: message)
        }
        panel.presentation.configuredCodexLaunch = coordinator
        panel.presentation.onClose = { [weak coordinator] in coordinator?.close() }
        coordinator.start()
    }
}
