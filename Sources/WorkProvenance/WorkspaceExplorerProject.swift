import Foundation

/// Project metadata is optional because PE currently supplies only a link identity and title.
struct WorkspaceExplorerProject: Identifiable {
    let id: String
    let name: String
    let owner: String?
    let status: String?
}
