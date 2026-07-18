import Foundation

enum RepoAgentLauncherParameterValueKind: Sendable, Hashable {
    case none
    case text(placeholder: String)
    case optionalText(placeholder: String)
    case choice([RepoAgentLauncherParameterOption])
}
