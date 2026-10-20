import Foundation

/// Distinguishes a real project ID from the two Explorer fallback collections.
enum WorkspaceExplorerCollectionTarget: Equatable {
    case all
    case unassigned
    case project(String)
}
