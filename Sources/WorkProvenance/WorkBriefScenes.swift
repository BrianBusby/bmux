import BmuxWorkBrief
import BmuxWorkBriefUI
import BmuxWorkBriefSources
import BmuxGit
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
        let settings = appDelegate.settingsRuntime
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 8
        let http = URLSessionWorkBriefHTTPClient(session: URLSession(configuration: configuration))
        let linear = LinearWorkBriefSource(authorization: {
            guard let settings else { return nil }
            return await WorkProvenanceSettingsLinearAuthorizationProvider(
                keychainStore: settings.keychainStore, jsonStore: settings.jsonStore,
                catalog: settings.catalog).authorizationHeader()
        }, http: http)
        let github = GitHubWorkBriefSource(
            authorization: { await PullRequestProbeService().authorizationHeaderForReadOnlyAPI() },
            scopes: {
                guard let settings else { return [] }
                return settings.jsonStore.snapshotValue(
                    for: settings.catalog.integrations.workBriefGitHubScopes)
                    .compactMap(GitHubWorkBriefScope.init)
            }, http: http)
        let external = WorkBriefExternalLoader(linear: linear, github: github)
        let model = WorkBriefCoordinator(initialSnapshot: initial) { forceExternal in
            await appDelegate.loadWorkBrief(external: external, forceExternal: forceExternal)
        }
        let baselineStore = WorkBriefBaselineStore()
        let previous = baselineStore.load(at: Date())
        return makeBoundView(appDelegate: appDelegate, model: model,
                             baselineStore: baselineStore, previousBrief: previous)
    }

    private static func makeBoundView(appDelegate: AppDelegate,
                                      model: WorkBriefCoordinator,
                                      baselineStore: WorkBriefBaselineStore,
                                      previousBrief: WorkBriefBaseline?) -> WorkBriefView {
        let workspaceMonitor = WorkspaceExplorerWorkspaceChangeMonitor(
            tabManagers: { appDelegate.workspaceExplorerTabManagers() })
        let statusMonitor = WorkspaceExplorerLiveStatusMonitor(
            workspaces: { Array(appDelegate.workspaceExplorerLiveWorkspaces().prefix(100)) })
        return WorkBriefView(model: model, previousBrief: previousBrief,
            jump: { appDelegate.workBriefJump(stableID: $0, runtimeID: $1) },
            highlight: { appDelegate.workBriefHighlight(stableID: $0, runtimeID: $1, surfaceID: $2) },
            openURL: { url in _ = BrowserExternalLinkOpener().openWebLink(url) },
            onStart: { refresh in
                let observeStatus: @MainActor (String, WorkspaceExplorerStatus) -> Void = { id, status in
                    guard let id = UUID(uuidString: id) else { return }
                    model.observeLocalStatus(id: id, status: WorkBriefLocalAdapter.status(status))
                }
                workspaceMonitor.start {
                    statusMonitor.start(onChange: observeStatus)
                    refresh()
                }
                statusMonitor.start(onChange: observeStatus)
            },
            onStop: {
                workspaceMonitor.stop()
                statusMonitor.stop()
                if model.hasLoaded, let snapshot = model.snapshot {
                    baselineStore.save(snapshot: snapshot, previous: previousBrief, at: Date())
                }
            })
    }
}
