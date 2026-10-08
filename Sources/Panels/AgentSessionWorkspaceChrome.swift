import Foundation

struct AgentSessionWorkspaceChrome: Equatable {
    let title: String
    let repository: String?
    let colorHex: String?
    let status: String?
    let activity: String?
    let links: [AgentSessionWorkspaceLink]
}
