import BmuxWorkBrief
import BmuxWorkBriefUI
import SwiftUI

/// Native Work Brief window assembled at the app boundary.
@MainActor
struct WorkBriefScenes: Scene {
    let appDelegate: AppDelegate
    let appearanceMode: String

    var body: some Scene {
        Window(String(localized: "workBrief.title", defaultValue: "Work Brief"), id: "work-brief") {
            Self.makeView(appDelegate: appDelegate)
                .bmuxAppearanceColorScheme(appearanceMode)
        }
        .defaultSize(width: 800, height: 720)
    }

    private static func makeView(appDelegate: AppDelegate) -> WorkBriefView {
        let initial = WorkBriefLocalAdapter().snapshot(appDelegate.workspaceExplorerPresence())
        let model = WorkBriefCoordinator(initialSnapshot: initial) {
            await appDelegate.loadWorkBrief()
        }
        return makeBoundView(appDelegate: appDelegate, model: model)
    }

    private static func makeBoundView(appDelegate: AppDelegate,
                                      model: WorkBriefCoordinator) -> WorkBriefView {
        let workspaceMonitor = WorkspaceExplorerWorkspaceChangeMonitor(
            tabManagers: { appDelegate.workspaceExplorerTabManagers() })
        let statusMonitor = WorkspaceExplorerLiveStatusMonitor(
            workspaces: { appDelegate.workspaceExplorerLiveWorkspaces() })
        return WorkBriefView(model: model,
            jump: { appDelegate.workBriefJump(stableID: $0, runtimeID: $1) },
            highlight: { appDelegate.workBriefHighlight(stableID: $0, runtimeID: $1, surfaceID: $2) },
            openURL: { url in _ = BrowserExternalLinkOpener().openWebLink(url) },
            onStart: { refresh in
                workspaceMonitor.start(onChange: refresh)
                statusMonitor.start { _, _ in refresh() }
            },
            onStop: {
                workspaceMonitor.stop()
                statusMonitor.stop()
            })
    }
}
