import Foundation

/// Unique logical workspaces in one result or group.
struct WorkspaceExplorerCounts: Equatable {
    let workspaces: Int
    let open: Int
    let closed: Int
    let closedKnown: Bool

    init(_ workspaces: [WorkspaceExplorerWorkspace], closedKnown: Bool) {
        let unique = Dictionary(workspaces.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.open = unique.values.filter { !$0.isClosed }.count
        self.closed = unique.values.filter(\.isClosed).count
        self.workspaces = unique.count
        self.closedKnown = closedKnown
    }
}
