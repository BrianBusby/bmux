/// A removable constraint carried from Explorer into the live workspace rail.
struct WorkspaceExplorerRailFilter: Identifiable, Equatable {
    enum Kind: Equatable {
        case collection(WorkspaceExplorerCollectionTarget)
        case state(WorkspaceExplorerScope.State)
        case period(WorkspaceExplorerScope.Period)
        case dimension(WorkspaceExplorerDimension, WorkspaceExplorerGroupKey)
    }

    let kind: Kind
    let label: String

    var id: String {
        switch kind {
        case .collection: "collection"
        case .state: "state"
        case .period: "period"
        case .dimension(let dimension, _): "dimension:\(dimension)"
        }
    }
}
