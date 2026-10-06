import Foundation

/// Literal startup options for a newly configured Codex session. Shell scripts,
/// subcommands, expansions, and externally supplied remote endpoints stay ordinary CLI commands.
struct ConnectedCodexLaunchConfiguration: Sendable {
    let arguments: [String]
    let environment: [String: String]
    let hostArguments: [String]
    let hasExplicitModel: Bool

    init() {
        arguments = []
        environment = [:]
        hostArguments = []
        hasExplicitModel = false
    }

    init?(command: String, environment: [String: String]) {
        // A custom PATH can select a different executable from the injected host.
        guard environment["PATH"] == nil,
              let words = Self.literalWords(command), words.first == "codex" else { return nil }
        let definitions = RepoAgentLauncherParameterCatalog().definitions(for: .codex)
        let byFlag = Dictionary(uniqueKeysWithValues: definitions.map { ($0.flag, $0) })
        let aliases = ["-c": "--config", "-m": "--model", "-s": "--sandbox", "-a": "--ask-for-approval"]
        var arguments: [String] = []
        var hostArguments: [String] = []
        var hasExplicitModel = false
        var index = 1
        while index < words.count {
            let parts = words[index].split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let spelling = String(parts[0])
            let flag = aliases[spelling] ?? spelling
            guard let definition = byFlag[flag] else { return nil }
            arguments.append(flag)
            let value: String?
            switch definition.valueKind {
            case .none:
                guard parts.count == 1 else { return nil }
                value = nil
            case .text, .optionalText, .choice:
                if parts.count == 2 {
                    value = String(parts[1])
                } else {
                    index += 1
                    guard index < words.count else { return nil }
                    value = words[index]
                }
            }
            if let value {
                arguments.append(value)
                if flag == "--config" {
                    hostArguments += [flag, value]
                    if value.split(separator: "=", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) == "model" {
                        hasExplicitModel = true
                    }
                }
            }
            if flag == "--model" { hasExplicitModel = true }
            index += 1
        }
        self.arguments = arguments
        self.environment = environment
        self.hostArguments = hostArguments
        self.hasExplicitModel = hasExplicitModel
    }

    private static func literalWords(_ command: String) -> [String]? {
        var words: [String] = []
        var word = ""
        var started = false
        var quote: Character?
        var escaped = false
        for character in command.trimmingCharacters(in: .whitespacesAndNewlines) {
            if escaped {
                if quote == "\"", !"$`\"\\".contains(character) { word.append("\\") }
                word.append(character)
                started = true
                escaped = false
            } else if quote == "'" {
                if character == "'" { quote = nil } else { word.append(character) }
            } else if character == "\\" {
                escaped = true
                started = true
            } else if character == "$" || character == "`" {
                return nil
            } else if let currentQuote = quote {
                if character == currentQuote { quote = nil } else { word.append(character) }
            } else if character == "'" || character == "\"" {
                quote = character
                started = true
            } else if character.isWhitespace {
                if character == "\n" || character == "\r" { return nil }
                if started { words.append(word); word = ""; started = false }
            } else if ";&|<>()*?{}~#".contains(character) {
                return nil
            } else {
                word.append(character)
                started = true
            }
        }
        guard quote == nil, !escaped else { return nil }
        if started { words.append(word) }
        return words
    }
}
