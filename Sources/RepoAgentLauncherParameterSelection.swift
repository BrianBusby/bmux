import Foundation

struct RepoAgentLauncherParameterSelection: Sendable, Hashable {
    let definition: RepoAgentLauncherParameterDefinition
    let value: String?

    var renderedArguments: [String] {
        switch definition.valueKind {
        case .none:
            return [definition.flag]
        case .text, .optionalText, .choice:
            guard let value, !value.isEmpty else { return [definition.flag] }
            return [definition.flag, Self.shellSingleQuote(value)]
        }
    }

    private static func shellSingleQuote(_ value: String) -> String {
        guard !value.isEmpty else { return "''" }
        let safeScalars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_+-=.,:/@%")
        if value.unicodeScalars.allSatisfy({ safeScalars.contains($0) }) {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
