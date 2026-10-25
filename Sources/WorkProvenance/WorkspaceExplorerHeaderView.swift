import SwiftUI

/// Explorer navigation, scope, and view-switch controls.
@MainActor
struct WorkspaceExplorerHeaderView: View {
    let model: WorkspaceExplorerCoordinator
    let cardGeometry: Namespace.ID
    let isEmbedded: Bool
    let onShowWorkspaceView: @MainActor () -> Void
    @Binding var confirmsClearHistory: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: WorkspaceExplorerCoordinator, cardGeometry: Namespace.ID,
         isEmbedded: Bool, onShowWorkspaceView: @escaping @MainActor () -> Void,
         confirmsClearHistory: Binding<Bool>) {
        self.model = model
        self.cardGeometry = cardGeometry
        self.isEmbedded = isEmbedded
        self.onShowWorkspaceView = onShowWorkspaceView
        _confirmsClearHistory = confirmsClearHistory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if model.collectionTarget != nil {
                    Button(String(localized: "explorer.allProjects", defaultValue: "All projects")) {
                        model.showOverview()
                    }
                    Text("›").foregroundStyle(.secondary)
                }
                if let target = model.collectionTarget {
                    if model.historyID != nil {
                        Button(target.title(projects: model.presentedCatalog?.projects ?? [])) { model.backFromHistory() }
                        Text("›").foregroundStyle(.secondary)
                    } else {
                        Text(target.title(projects: model.presentedCatalog?.projects ?? []))
                            .matchedGeometryEffect(id: "title:\(target.titleIdentity)", in: cardGeometry)
                    }
                } else {
                    Text(String(localized: "explorer.title", defaultValue: "Explorer"))
                }
                if let id = model.historyID,
                   let item = model.presentedCatalog?.items.first(where: { $0.id == id }) {
                    Text(item.title)
                    Text(String(localized: "explorer.readOnlyTag", defaultValue: "READ-ONLY HISTORY"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(model.scope.summary)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                if isEmbedded {
                    Button(String(localized: "workspaceRail.workspaceView", defaultValue: "Workspace View")) {
                        onShowWorkspaceView()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .accessibilityIdentifier("bmuxShell.workspaceView")
                }
                Button {
                    Task { await model.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel(String(localized: "explorer.refresh", defaultValue: "Refresh Explorer"))
                Menu {
                    Button(String(localized: "explorer.clearHistory", defaultValue: "Clear Explorer history")) {
                        confirmsClearHistory = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(String(localized: "explorer.moreActions", defaultValue: "Explorer actions"))
            }
            .font(.system(size: 18, weight: .bold))
            if model.historyID == nil {
                WorkspaceExplorerScopeControls(scope: model.scope,
                    onState: { model.setScopeState($0, animated: !reduceMotion) },
                    onPeriod: { model.setScopePeriod($0, animated: !reduceMotion) })
            }
        }
        .padding(16)
    }
}
