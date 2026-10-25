import AppKit
import SwiftUI

/// Owns the main workbench's Explorer switch and the live workspace rail projection.
@MainActor
struct WorkspaceWorkbenchShell<LiveSurface: View>: View {
    let tabManager: TabManager
    let observedWindow: NSWindow?
    let onExplorerVisibilityChange: @MainActor (Bool) -> Void
    @ViewBuilder let liveSurface: () -> LiveSurface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsExplorer = false
    @State private var explorerCoordinator: WorkspaceExplorerCoordinator?
    @State private var visibleWorkspaceIDs: Set<UUID>?
    @State private var railFilters = WorkspaceFilters()
    @State private var isRailFilterPanelPresented = false

    init(tabManager: TabManager, observedWindow: NSWindow?,
         onExplorerVisibilityChange: @escaping @MainActor (Bool) -> Void,
         @ViewBuilder liveSurface: @escaping () -> LiveSurface) {
        self.tabManager = tabManager
        self.observedWindow = observedWindow
        self.onExplorerVisibilityChange = onExplorerVisibilityChange
        self.liveSurface = liveSurface
    }

    var body: some View {
        WorkspaceReferenceAppShell(showsRail: !showsExplorer) {
            rail
        } content: {
            if showsExplorer, let appDelegate = AppDelegate.shared, let explorerCoordinator {
                WorkspaceExplorerScenes.makeView(appDelegate: appDelegate,
                    model: explorerCoordinator, isEmbedded: true,
                    onShowWorkspaceView: showWorkspaceView)
                    .transition(.opacity)
            } else {
                liveSurface().transition(.opacity)
            }
        }
        .onChange(of: explorerCoordinator?.visibleLiveWorkspaceIDs) { _, ids in
            visibleWorkspaceIDs = ids.map(Set.init)
        }
        .onDisappear {
            explorerCoordinator?.stopLiveStatusMonitoring()
        }
    }

    private var rail: some View {
        WorkspaceReferenceRail(
            workspaces: visibleWorkspaceIDs.map { visible in
                tabManager.tabs.filter { visible.contains($0.id) }
            } ?? tabManager.tabs,
            projectCard: { workspace in
                let provenance = tabManager.workProvenanceRuntime?.workspaceDisplayCurrentStateSnapshot(for: workspace)
                let title = tabManager.sidebarWorkspaceTitleResolution(for: workspace,
                    provenanceDisplaySnapshot: provenance).title
                return WorkspaceReferenceCardSnapshot(workspace: workspace, provenance: provenance,
                    workspaceTitle: title)
            },
            selectedWorkspaceID: tabManager.selectedTabId,
            selectedWorkspaceTitle: tabManager.selectedWorkspace?.title,
            canCloseWorkspace: tabManager.tabs.count > 1,
            onShowExplorer: showExplorer,
            onSelect: { tabManager.selectWorkspaceIdForAction($0) },
            onClose: { id in
                if let workspace = tabManager.tabs.first(where: { $0.id == id }) {
                    tabManager.closeWorkspaceWithConfirmation(workspace)
                }
            },
            onOpenLink: { _, url in BrowserExternalLinkOpener().openWebLink(url) },
            onLaunchRepository: { anchorView in
                guard AppDelegate.shared?.showRepoAgentLauncherMenu(anchorView: anchorView) == true else {
                    NSSound.beep()
                    return
                }
            },
            onFocusHostChange: { host, scope, isAttached in
                guard let window = observedWindow,
                      let owner = AppDelegate.shared?.keyboardFocusCoordinator(for: window)?
                        .workspaceChromeFocusOwner else { return }
                if isAttached { owner.register(host, scope: scope, in: window) }
                else { owner.unregister(host, scope: scope) }
            },
            filters: $railFilters,
            isFilterPanelPresented: $isRailFilterPanelPresented
        )
    }

    private func showExplorer() {
        guard let appDelegate = AppDelegate.shared else { return }
        if explorerCoordinator == nil {
            explorerCoordinator = WorkspaceExplorerScenes.makeCoordinator(appDelegate: appDelegate,
                onActivateWorkspace: { _ in showWorkspaceView() })
        }
        railFilters = WorkspaceFilters()
        isRailFilterPanelPresented = false
        onExplorerVisibilityChange(true)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
            showsExplorer = true
        }
    }

    private func showWorkspaceView() {
        onExplorerVisibilityChange(false)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
            showsExplorer = false
        }
    }
}
