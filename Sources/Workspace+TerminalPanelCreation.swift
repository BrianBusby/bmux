import AppKit
import BmuxTerminal
import BmuxTerminalCore
import Foundation

@MainActor
extension Workspace {
    func makeStableTerminalPanel(
        id panelId: UUID = UUID(),
        workspaceId: UUID,
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
    ) -> TerminalPanel {
        TerminalPanel(
            id: panelId,
            workspaceId: workspaceId,
            stableWorkspaceId: stableId,
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
            dependencies: dependencies
        )
    }

    func makeStableManualTerminalSurface(onInput: @escaping @Sendable (Data) -> Void) -> TerminalSurface {
        TerminalSurface(
            tabId: id,
            stableWorkspaceId: stableId,
            context: GHOSTTY_SURFACE_CONTEXT_SPLIT,
            configTemplate: nil,
            manualIO: true,
            manualInputHandler: onInput,
            dependencies: GhosttyApp.terminalSurfaceRuntimeDependencies
        )
    }
}
