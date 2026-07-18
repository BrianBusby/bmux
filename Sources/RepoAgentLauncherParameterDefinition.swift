import Foundation

struct RepoAgentLauncherParameterDefinition: Identifiable, Sendable, Hashable {
    let agent: BmuxConfigAgentKind
    let flag: String
    let comment: String
    let valueKind: RepoAgentLauncherParameterValueKind

    var id: String {
        "\(agent.commandName).\(flag)"
    }
}
