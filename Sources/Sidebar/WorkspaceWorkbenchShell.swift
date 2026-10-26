import AppKit
import SwiftUI
import BmuxAppKitSupportUI

/// Owns the main workbench's Explorer switch and the live workspace rail projection.
@MainActor
struct WorkspaceWorkbenchShell<LiveSurface: View>: View {
    let tabManager: TabManager
    let appDelegate: AppDelegate?
    let observedWindow: NSWindow?
    let onExplorerVisibilityChange: @MainActor (Bool) -> Void
    @ViewBuilder let liveSurface: () -> LiveSurface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsExplorer = false
    @State private var explorerCoordinator: WorkspaceExplorerCoordinator?
    @State private var visibleWorkspaceIDs: Set<UUID>?
    @State private var railFilters = WorkspaceFilters()
    @State private var isRailFilterPanelPresented = false

    init(tabManager: TabManager, appDelegate: AppDelegate?, observedWindow: NSWindow?,
         onExplorerVisibilityChange: @escaping @MainActor (Bool) -> Void,
         @ViewBuilder liveSurface: @escaping () -> LiveSurface) {
        self.tabManager = tabManager
        self.appDelegate = appDelegate
        self.observedWindow = observedWindow
        self.onExplorerVisibilityChange = onExplorerVisibilityChange
        self.liveSurface = liveSurface
    }

    var body: some View {
        WorkspaceReferenceAppShell(showsRail: !showsExplorer) {
            rail
        } content: {
            if showsExplorer, let appDelegate, let explorerCoordinator {
                WorkspaceExplorerScenes.makeView(appDelegate: appDelegate,
                    model: explorerCoordinator, isEmbedded: true)
                    .transition(.opacity)
            } else {
                liveSurface().transition(.opacity)
            }
        } headerAction: {
            viewSwitchButton
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
            explorerFilters: explorerCoordinator?.activeRailFilters ?? [],
            onRemoveExplorerFilter: removeExplorerFilter,
            onSelect: { tabManager.selectWorkspaceIdForAction($0) },
            onClose: { id in
                if let workspace = tabManager.tabs.first(where: { $0.id == id }) {
                    tabManager.closeWorkspaceWithConfirmation(workspace)
                }
            },
            onOpenLink: { _, url in BrowserExternalLinkOpener().openWebLink(url) },
            onLaunchRepository: { anchorView in
                guard appDelegate?.showRepoAgentLauncherMenu(anchorView: anchorView) == true else {
                    NSSound.beep()
                    return
                }
            },
            onFocusHostChange: { host, scope, isAttached in
                guard let window = observedWindow,
                      let owner = appDelegate?.keyboardFocusCoordinator(for: window)?
                        .workspaceChromeFocusOwner else { return }
                if isAttached { owner.register(host, scope: scope, in: window) }
                else { owner.unregister(host, scope: scope) }
            },
            filters: $railFilters,
            isFilterPanelPresented: $isRailFilterPanelPresented
        )
    }

    private var viewSwitchButton: some View {
        let theme = MatteTheme(colorScheme: colorScheme)
        return MatteButton(hitExpansion: theme.layout.invisibleHitExpansion) {
            if showsExplorer { showWorkspaceView() }
            else { showExplorer() }
        } label: {
            Text(showsExplorer
                ? String(localized: "workspaceRail.workspaceView", defaultValue: "Workspace View")
                : String(localized: "workspaceRail.explorerView", defaultValue: "Explorer"))
                .font(.system(size: 12, weight: .medium))
        }
        .buttonStyle(MatteButtonStyle(theme: theme))
        .accessibilityIdentifier("bmuxShell.explorerToggle")
    }

    private func removeExplorerFilter(_ filter: WorkspaceExplorerRailFilter) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            explorerCoordinator?.removeRailFilter(filter)
        }
    }

    private func showExplorer() {
        guard let appDelegate else { return }
        if explorerCoordinator == nil {
            explorerCoordinator = WorkspaceExplorerScenes.makeCoordinator(appDelegate: appDelegate,
                onActivateWorkspace: { _ in showWorkspaceView() })
        }
        explorerCoordinator?.openAllWorkspacesUnfiltered()
        railFilters = WorkspaceFilters()
        isRailFilterPanelPresented = false
        onExplorerVisibilityChange(true)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
            showsExplorer = true
        }
    }

    private func showWorkspaceView() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24),
                      completionCriteria: .logicallyComplete) {
            showsExplorer = false
        } completion: {
            guard !showsExplorer else { return }
            // Portal-hosted terminals sit above SwiftUI and must wait for Explorer's exit.
            onExplorerVisibilityChange(false)
        }
    }
}
