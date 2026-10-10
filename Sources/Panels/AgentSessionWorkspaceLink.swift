import Foundation

struct AgentSessionWorkspaceLink: Identifiable, Equatable {
    let id: String
    let label: String
    let kind: String
    let url: URL?
    let state: String?
    let owner: String?
}
