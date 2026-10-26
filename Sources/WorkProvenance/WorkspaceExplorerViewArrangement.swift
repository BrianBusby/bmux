import Foundation

/// Session-scoped arrangement for the root or a focused collection.
struct WorkspaceExplorerViewArrangement {
    private(set) var groupBy: [WorkspaceExplorerDimension] = []
    private(set) var filters: [WorkspaceExplorerDimension: WorkspaceExplorerGroupKey] = [:]
    private(set) var collapsedPaths: Set<String> = []
    var scrollOffset: CGFloat = 0
    var scrollAnchorID: String?
    var selectedWorkspaceID: String?
    private var undoStack: [Snapshot] = []

    var canUndo: Bool { !undoStack.isEmpty }

    mutating func setGroupBy(_ dimensions: [WorkspaceExplorerDimension]) {
        let next = Array(dimensions.uniqued().prefix(3))
        guard next != groupBy else { return }
        saveUndo()
        groupBy = next
    }

    mutating func setFilter(_ dimension: WorkspaceExplorerDimension, value: WorkspaceExplorerGroupKey?) {
        guard filters[dimension] != value else { return }
        saveUndo()
        filters[dimension] = value
    }

    mutating func clearFilters() {
        guard !filters.isEmpty else { return }
        saveUndo()
        filters.removeAll()
    }

    mutating func toggleCollapsed(_ path: String) {
        if !collapsedPaths.insert(path).inserted { collapsedPaths.remove(path) }
    }

    mutating func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        groupBy = snapshot.groupBy
        filters = snapshot.filters
    }

    private mutating func saveUndo() {
        undoStack.append(Snapshot(groupBy: groupBy, filters: filters))
        if undoStack.count > 30 { undoStack.removeFirst() }
    }

    private struct Snapshot {
        let groupBy: [WorkspaceExplorerDimension]
        let filters: [WorkspaceExplorerDimension: WorkspaceExplorerGroupKey]
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
