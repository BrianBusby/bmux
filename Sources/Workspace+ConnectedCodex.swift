import BmuxAgentChat
import Bonsplit
import Foundation

extension Workspace {
    /// Selects the terminal panel for a Chat click without transferring the
    /// AppKit first responder away from that WebKit composer.
    @MainActor
    func focusConnectedCodexChat(panelID: UUID) {
        guard let manager = owningTabManager ?? AppDelegate.shared?.tabManagerFor(tabId: id),
              panels[panelID] is TerminalPanel else { return }
        _ = manager.focusWorkspaceSurfaceForAction(
            workspaceId: id,
            surfaceId: panelID,
            focusIntent: .terminal(.chatComposer)
        )
    }

    /// Creates a new terminal with a shared host; never injects a launch command
    /// into an existing shell or replaces an ordinary running agent.
    @MainActor
    func startConnectedCodex(in paneID: PaneID, workingDirectory: String) async throws {
        guard let runtime = owningTabManager?.terminalChatReader as? any TerminalChatConnecting,
              remoteConfiguration == nil, !isRemoteTmuxMirror else { throw CodexControlError.unsupported }
        let surfaceID = UUID()
        let command = try await runtime.prepareConnectedSession(workspaceID: id, surfaceID: surfaceID, workingDirectory: workingDirectory)
        let result = createTerminalSurfaceForAction(inPane: paneID, focus: true, workingDirectory: workingDirectory,
                                                    initialCommand: command, restoredSurfaceId: surfaceID)
        guard let panel = result.panel else {
            await runtime.closeConnectedSession(surfaceID: surfaceID)
            throw CodexControlError.disconnected
        }
        let ownerWorkspaceID = id
        runtime.attachConnectedTerminal(surfaceID: surfaceID) { [weak panel] in
            guard let panel, panel.workspaceId == ownerWorkspaceID, let surface = panel.surface.surface else { return false }
            return !ghostty_surface_process_exited(surface)
        }
        panel.presentation.onClose = { Task { await runtime.closeConnectedSession(surfaceID: surfaceID) } }
    }
}
