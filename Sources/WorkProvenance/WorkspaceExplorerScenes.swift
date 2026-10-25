import SwiftUI

/// Native Explorer windows assembled at the app composition boundary.
@MainActor
struct WorkspaceExplorerScenes: Scene {
    let appDelegate: AppDelegate
    let appearanceMode: String

    static func makeCoordinator(appDelegate: AppDelegate,
                                liveNavigation: WorkspaceExplorerLiveNavigation? = nil,
                                onActivateWorkspace: (@MainActor (UUID) -> Void)? = nil) -> WorkspaceExplorerCoordinator {
        WorkspaceExplorerCoordinator(
            loadHistory: { try await appDelegate.loadWorkspaceExplorerHistory() },
            loadPresence: { appDelegate.workspaceExplorerPresence() },
            reopenHistory: { appDelegate.reopenWorkspaceExplorerHistory(stableID: $0) },
            activateWorkspace: { id in
                appDelegate.activateWorkspaceExplorerWorkspace(runtimeID: id)
                onActivateWorkspace?(id)
            },
            onOpenLive: { item, target, title in
                liveNavigation?.opened(item: item, target: target, from: title,
                    loadSessions: { try await appDelegate.workspaceExplorerSessions(stableID: $0) })
            },
            loadSessions: { try await appDelegate.workspaceExplorerSessions(stableID: $0) },
            loadEvidence: { try await appDelegate.workspaceExplorerSessionEvidence(sessionID: $0) },
            loadMoreSessions: { try await appDelegate.workspaceExplorerSessions(stableID: $0, cursor: $1) },
            clearArchive: { try await appDelegate.clearWorkspaceExplorerHistory() },
            liveStatusMonitor: WorkspaceExplorerLiveStatusMonitor(
                workspaces: { appDelegate.workspaceExplorerLiveWorkspaces() }),
            workspaceChangeMonitor: WorkspaceExplorerWorkspaceChangeMonitor(
                tabManagers: { appDelegate.workspaceExplorerTabManagers() })
        )
    }

    static func makeView(appDelegate: AppDelegate,
                         model: WorkspaceExplorerCoordinator? = nil,
                         isEmbedded: Bool = false,
                         onActivateWorkspace: (@MainActor (UUID) -> Void)? = nil,
                         onShowWorkspaceView: @escaping @MainActor () -> Void = {}) -> WorkspaceExplorerWindowView {
        WorkspaceExplorerWindowView(
            model: model ?? makeCoordinator(appDelegate: appDelegate,
                liveNavigation: isEmbedded ? nil : appDelegate.workspaceExplorerLiveNavigation,
                onActivateWorkspace: onActivateWorkspace),
            provenanceStartupFailed: { appDelegate.workProvenanceRuntime?.startupErrorDescription != nil },
            restartApp: { try HostSettingsActions.relaunchApp() },
            liveNavigation: isEmbedded ? nil : appDelegate.workspaceExplorerLiveNavigation,
            isEmbedded: isEmbedded,
            onShowWorkspaceView: onShowWorkspaceView
        )
    }

    var body: some Scene {
        Window(String(localized: "explorer.title", defaultValue: "Explorer"), id: "workspace-explorer") {
            Self.makeView(appDelegate: appDelegate)
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
