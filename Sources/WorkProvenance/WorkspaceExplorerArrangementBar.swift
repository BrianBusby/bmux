import SwiftUI

/// Grouping and filtering controls for one Explorer level.
struct WorkspaceExplorerArrangementBar: View {
    let groupBy: [WorkspaceExplorerDimension]
    let filters: [WorkspaceExplorerDimension: WorkspaceExplorerGroupKey]
    let availableDimensions: [WorkspaceExplorerDimension]
    let projectsByID: [String: WorkspaceExplorerProject]
    let repositoryNamesByID: [String: String]
    let canUndo: Bool
    let onGroupBy: ([WorkspaceExplorerDimension]) -> Void
    let onFilter: (WorkspaceExplorerDimension, WorkspaceExplorerGroupKey?) -> Void
    let onClear: () -> Void
    let onUndo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Text(String(localized: "explorer.groupBy", defaultValue: "Group by:"))
                    .foregroundStyle(.secondary)
                ForEach(groupBy, id: \.self) { dimension in
                    let index = groupBy.firstIndex(of: dimension) ?? 0
                    HStack(spacing: 2) {
                        Button {
                            move(index, by: -1)
                        } label: { Image(systemName: "chevron.left") }
                        .disabled(index == 0)
                        .accessibilityLabel(String(format: String(localized: "explorer.moveEarlier", defaultValue:
                            "Move %@ earlier"), dimension.displayName))
                        Text(dimension.displayName)
                        Button {
                            move(index, by: 1)
                        } label: { Image(systemName: "chevron.right") }
                        .disabled(index == groupBy.count - 1)
                        .accessibilityLabel(String(format: String(localized: "explorer.moveLater", defaultValue:
                            "Move %@ later"), dimension.displayName))
                        Button {
                            onGroupBy(groupBy.filter { $0 != dimension })
                        } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(String(format: String(localized: "explorer.removeGroup", defaultValue:
                            "Remove %@ grouping"), dimension.displayName))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 7).padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.16), in: Capsule())
                }
                if groupBy.count < 3 {
                    Menu {
                        ForEach(availableDimensions.filter { !groupBy.contains($0) }, id: \.self) { dimension in
                            Button(dimension.displayName) { onGroupBy(groupBy + [dimension]) }
                        }
                    } label: {
                        Text(String(localized: "explorer.addDimension", defaultValue: "+ Dimension"))
                    }
                }
                Spacer()
                Button(String(localized: "explorer.undoView", defaultValue: "Undo view change"), action: onUndo)
                    .disabled(!canUndo)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    Text(String(localized: "explorer.filter", defaultValue: "Filter:"))
                        .foregroundStyle(.secondary)
                    Button(String(localized: "explorer.status.needsInput", defaultValue: "Needs input")) {
                        let value: WorkspaceExplorerGroupKey = .bmuxStatus(.needsInput)
                        onFilter(.bmuxStatus, filters[.bmuxStatus] == value ? nil : value)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    ForEach(availableDimensions + (availableDimensions.contains(.bmuxStatus) ? [] : [.bmuxStatus]),
                        id: \.self) { dimension in
                        if let key = filters[dimension] {
                            Button(dimension.displayName + ": " + key.displayName(projectsByID: projectsByID,
                                repositoryNamesByID: dimension == .repository ? repositoryNamesByID : [:]) + " ×") {
                                onFilter(dimension, nil)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    if !filters.isEmpty {
                        Button(String(localized: "explorer.clearFilters", defaultValue: "Clear filters"), action: onClear)
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .font(.system(size: 12))
    }

    private func move(_ index: Int, by offset: Int) {
        let destination = index + offset
        guard groupBy.indices.contains(destination) else { return }
        var next = groupBy
        next.swapAt(index, destination)
        onGroupBy(next)
    }
}
