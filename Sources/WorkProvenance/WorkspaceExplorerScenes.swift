import SwiftUI

/// Native Explorer windows assembled at the app composition boundary.
@MainActor
struct WorkspaceExplorerScenes: Scene {
    let appDelegate: AppDelegate
    let appearanceMode: String

    var body: some Scene {
        Window(String(localized: "explorer.title", defaultValue: "Explorer"), id: "workspace-explorer") {
            WorkspaceExplorerWindowView(
                loadPresence: { appDelegate.workspaceExplorerPresence() },
                loadHistory: { try await appDelegate.loadWorkspaceExplorerHistory() },
                reopenHistory: { appDelegate.reopenWorkspaceExplorerHistory(stableID: $0) },
                activateWorkspace: { appDelegate.activateWorkspaceExplorerWorkspace(runtimeID: $0) },
                loadSessions: { try await appDelegate.workspaceExplorerSessions(stableID: $0) },
                loadEvidence: { try await appDelegate.workspaceExplorerSessionEvidence(sessionID: $0) },
                loadMoreSessions: { try await appDelegate.workspaceExplorerSessions(stableID: $0, cursor: $1) },
                clearArchive: { try await appDelegate.clearWorkspaceExplorerHistory() },
                liveStatusWorkspaces: { appDelegate.workspaceExplorerLiveWorkspaces() },
                workspaceTabManagers: { appDelegate.workspaceExplorerTabManagers() },
                liveNavigation: appDelegate.workspaceExplorerLiveNavigation
            )
            .bmuxAppearanceColorScheme(appearanceMode)
        }
        .defaultSize(width: 980, height: 700)

#if DEBUG
        Window(String(localized: "explorer.dogfoodWindow", defaultValue: "Explorer History Fixture"),
               id: "workspace-explorer-fixture") {
            WorkspaceExplorerDogfoodWindow()
                .bmuxAppearanceColorScheme(appearanceMode)
        }
        .defaultSize(width: 980, height: 700)
#endif
    }
}
