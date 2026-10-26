import SwiftUI

/// Explorer scope and actions, with a single return action in detail views.
@MainActor
struct WorkspaceExplorerHeaderView: View {
    let model: WorkspaceExplorerCoordinator
    @Binding var confirmsClearHistory: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            if model.historyID != nil {
                Button {
                    model.backFromHistory()
                } label: {
                    Label(model.collectionTarget?.title(projects: model.presentedCatalog?.projects ?? []) ??
                        String(localized: "explorer.allWorkspaces", defaultValue: "All workspaces"),
                        systemImage: "arrow.left")
                }
                .buttonStyle(.borderless)
            } else if model.collectionTarget != nil {
                Button {
                    model.showAllWorkspaces()
                } label: {
                    Label(String(localized: "explorer.allWorkspaces", defaultValue: "All workspaces"),
                        systemImage: "arrow.left")
                }
                .buttonStyle(.borderless)
            }
            if model.historyID == nil {
                WorkspaceExplorerScopeControls(scope: model.scope,
                    onState: { model.setScopeState($0, animated: !reduceMotion) },
                    onPeriod: { model.setScopePeriod($0, animated: !reduceMotion) })
            }
            Spacer(minLength: 0)
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
        .padding(16)
    }
}
