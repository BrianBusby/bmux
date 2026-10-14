import AppKit
import BmuxTerminal
import BmuxWorkspaces
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

@MainActor
final class ConfigSnapshotTabManager: TabManager {
    private var injectedConfig: BmuxSurfaceConfigTemplate?
    var capturedConfigTemplate: BmuxSurfaceConfigTemplate?

    func installInjectedConfig(fontSize: Float) {
        var config = BmuxSurfaceConfigTemplate()
        config.fontSize = fontSize
        config.workingDirectory = "/tmp/bmux-workspace-snapshot"
        config.command = "echo snapshot"
        config.environmentVariables = ["BMUX_INHERITED_ENV": "1"]
        injectedConfig = config
    }

    override func inheritedTerminalFontPointsForNewWorkspace(workspace: Workspace?) -> Float? {
        injectedConfig?.fontSize ?? super.inheritedTerminalFontPointsForNewWorkspace(workspace: workspace)
    }

    // Keep the unsafe legacy candidate available: creation must use the font-only
    // lineage seam above and must not copy command, directory or environment from here.
    override func inheritedTerminalConfigForNewWorkspace(
        workspace: Workspace?
    ) -> BmuxSurfaceConfigTemplate? {
        injectedConfig ?? super.inheritedTerminalConfigForNewWorkspace(workspace: workspace)
    }

    override func makeWorkspaceForCreation(
        title: String,
        workingDirectory: String?,
        portOrdinal: Int,
        configTemplate: BmuxSurfaceConfigTemplate?,
        initialSurface: NewWorkspaceInitialSurface,
        initialTerminalCommand: String?,
        initialTerminalInput: String?,
        initialTerminalEnvironment: [String: String],
        initialBrowserURL: URL?,
        initialBrowserOmnibarVisible: Bool,
        initialBrowserTransparentBackground: Bool,
        workspaceEnvironment: [String: String],
        allowTextBoxFocusDefault: Bool
    ) -> Workspace {
        capturedConfigTemplate = configTemplate
        return super.makeWorkspaceForCreation(
            title: title,
            workingDirectory: workingDirectory,
            portOrdinal: portOrdinal,
            configTemplate: configTemplate,
            initialSurface: initialSurface,
            initialTerminalCommand: initialTerminalCommand,
            initialTerminalInput: initialTerminalInput,
            initialTerminalEnvironment: initialTerminalEnvironment,
            initialBrowserURL: initialBrowserURL,
            initialBrowserOmnibarVisible: initialBrowserOmnibarVisible,
            initialBrowserTransparentBackground: initialBrowserTransparentBackground,
            workspaceEnvironment: workspaceEnvironment,
            allowTextBoxFocusDefault: allowTextBoxFocusDefault
        )
    }
}
