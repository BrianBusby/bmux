import BmuxAgentChat
import Foundation
import Observation

/// Starts only a newly configured terminal, retaining its identity across async host preparation.
@Observable @MainActor
final class ConfiguredCodexLaunchCoordinator {
    private weak var workspace: Workspace?
    private weak var panel: TerminalPanel?
    private let workspaceID: UUID
    private let surfaceID: UUID
    private(set) var isStarting = true
    private(set) var failureMessage: String?
    private let runtime: any TerminalChatConnecting
    private let workingDirectory: String
    private let configuration: ConnectedCodexLaunchConfiguration
    private let onFailure: @MainActor (String) -> Void
    private var startup: Task<Void, Never>?

    init(workspace: Workspace, panel: TerminalPanel, runtime: any TerminalChatConnecting,
         workingDirectory: String, configuration: ConnectedCodexLaunchConfiguration,
         onFailure: @escaping @MainActor (String) -> Void) {
        self.workspaceID = workspace.id
        self.surfaceID = panel.id
        self.workspace = workspace
        self.panel = panel
        self.runtime = runtime
        self.workingDirectory = workingDirectory
        self.configuration = configuration
        self.onFailure = onFailure
    }

    func start() {
        guard startup == nil, panel != nil else { return }
        startup = Task { [weak self] in
            guard let self else { return }
            defer { isStarting = false }
            do {
                let command = try await runtime.prepareConnectedSession(workspaceID: workspaceID,
                    surfaceID: surfaceID, workingDirectory: workingDirectory, configuration: configuration)
                guard !Task.isCancelled, let workspace = self.workspace, let source = self.panel,
                      workspace.id == workspaceID, source.workspaceId == workspaceID,
                      workspace.panels[source.id] as? TerminalPanel === source,
                      workspace.paneId(forPanelId: source.id) != nil else {
                    await runtime.closeConnectedSession(surfaceID: surfaceID)
                    return
                }
                // Workspace eager loading may already have started this owned placeholder.
                // Respawn installs the connected command in a new PTY while preserving
                // the logical surface, tab position, selection, and canvas membership.
                guard let connected = workspace.respawnTerminalSurface(panelId: source.id,
                    command: command, workingDirectory: workingDirectory, focus: false, waitAfterCommand: true,
                    allowTextBoxFocusDefault: false) else {
                    await runtime.closeConnectedSession(surfaceID: surfaceID)
                    reportFailure(CodexControlError.disconnected)
                    return
                }
                self.panel = connected
                connected.presentation.chatRenderer = source.presentation.chatRenderer
                connected.presentation.configuredCodexLaunch = self
                connected.presentation.onClose = { [weak self] in self?.close() }
                source.presentation.onClose = nil
                runtime.attachConnectedTerminal(surfaceID: surfaceID) { [weak connected, workspaceID = self.workspaceID] in
                    guard let connected, connected.workspaceId == workspaceID,
                          let surface = connected.surface.surface else { return false }
                    return !ghostty_surface_process_exited(surface)
                }
                connected.surface.requestBackgroundSurfaceStartIfNeeded()
            } catch {
                await runtime.closeConnectedSession(surfaceID: surfaceID)
                guard !Task.isCancelled, let workspace = self.workspace, let panel = self.panel,
                      workspace.panels[panel.id] as? TerminalPanel === panel,
                      panel.workspaceId == workspaceID else { return }
                reportFailure(error)
            }
        }
    }

    func retry() {
        guard !isStarting, failureMessage != nil else { return }
        startup = nil
        failureMessage = nil
        isStarting = true
        start()
    }

    private func reportFailure(_ error: Error) {
        let message = (error as? ManagedCodexRuntimeError)?.errorDescription
            ?? String(localized: "agentSession.chat.configuredStartFailed", defaultValue: "Could not connect to Codex. Retry the launch.")
        failureMessage = message
        onFailure(message)
    }

    func close() {
        startup?.cancel()
        Task { await runtime.closeConnectedSession(surfaceID: surfaceID) }
    }
}
