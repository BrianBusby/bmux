import AppKit
import BmuxTerminal
import BmuxTerminalCore

@MainActor
extension TerminalPanel {
    /// Create a new terminal panel with a fresh surface.
    convenience init(
        id: UUID = UUID(),
        workspaceId: UUID,
        stableWorkspaceId: UUID? = nil,
        context: ghostty_surface_context_e = GHOSTTY_SURFACE_CONTEXT_SPLIT,
        configTemplate: BmuxSurfaceConfigTemplate? = nil,
        workingDirectory: String? = nil,
        portOrdinal: Int = 0,
        initialCommand: String? = nil,
        tmuxStartCommand: String? = nil,
        initialInput: String? = nil,
        initialEnvironmentOverrides: [String: String] = [:],
        additionalEnvironment: [String: String] = [:],
        focusPlacement: TerminalSurfaceFocusPlacement = .workspace,
        runtimeSpawnPolicy: TerminalSurfaceRuntimeSpawnPolicy = .immediate,
        dependencies: TerminalSurfaceRuntimeDependencies? = nil
    ) {
        let surface = TerminalSurface(
            id: id,
            tabId: workspaceId,
            stableWorkspaceId: stableWorkspaceId,
            context: context,
            configTemplate: configTemplate,
            workingDirectory: workingDirectory,
            portOrdinal: portOrdinal,
            initialCommand: initialCommand,
            tmuxStartCommand: tmuxStartCommand,
            initialInput: initialInput,
            initialEnvironmentOverrides: initialEnvironmentOverrides,
            additionalEnvironment: additionalEnvironment,
            focusPlacement: focusPlacement,
            runtimeSpawnPolicy: runtimeSpawnPolicy,
            dependencies: dependencies ?? GhosttyApp.terminalSurfaceRuntimeDependencies
        )
        self.init(workspaceId: workspaceId, surface: surface)
        if Self.startsAtOwnedPrompt(
            configTemplate: configTemplate,
            initialCommand: initialCommand,
            tmuxStartCommand: tmuxStartCommand,
            initialInput: initialInput
        ) {
            updateShellActivityState(.promptIdle)
        }
    }

    private static func startsAtOwnedPrompt(
        configTemplate: BmuxSurfaceConfigTemplate?,
        initialCommand: String?,
        tmuxStartCommand: String?,
        initialInput: String?
    ) -> Bool {
        isBlank(initialCommand) &&
            isBlank(tmuxStartCommand) &&
            isBlank(initialInput) &&
            isBlank(configTemplate?.command) &&
            isBlank(configTemplate?.initialInput)
    }

    private static func isBlank(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }
}
