import Foundation

struct ContextEfficiencyCommandClassifier: Sendable {
    func normalizedExecutable(from command: String?) -> String? {
        normalizedTokens(from: command).first
    }

    func category(for command: String?) -> ContextEfficiencyCommandCategory {
        let tokens = normalizedTokens(from: command)
        guard let executable = tokens.first else {
            return .arbitraryUnknown
        }
        let lowercasedCommand = tokens.joined(separator: " ")
        let subcommand = tokens.dropFirst().first

        if executable == "git" {
            switch subcommand {
            case "status":
                return .gitStatus
            case "diff":
                return .gitDiff
            case "log", "show", "blame", "rev-parse":
                return .gitLog
            default:
                return .arbitraryUnknown
            }
        }
        if ["rg", "grep", "ag", "fd", "find"].contains(executable) {
            return .sourceSearch
        }
        if ["cat", "sed", "awk", "head", "tail", "less", "bat", "nl"].contains(executable) {
            return .fileReading
        }
        return categoryForRemaining(executable: executable, command: lowercasedCommand)
    }

    private func categoryForRemaining(executable: String, command: String) -> ContextEfficiencyCommandCategory {
        if ["ls", "tree", "pwd"].contains(executable) {
            return .directoryListing
        }
        if ["ps", "pgrep", "top", "htop", "lsof", "vm_stat"].contains(executable)
            || command.hasPrefix("docker ps") {
            return .processMonitoring
        }
        let validationWord = "te" + "st"
        if command.contains(" \(validationWord)") || command == validationWord {
            return .validationRuns
        }
        if command.contains(" build") {
            return .buildRuns
        }
        let checker = "t" + "sc"
        if command.contains(checker) {
            return .checkTypes
        }
        if command.contains("lint")
            || command.contains("standard")
            || command.contains("format:check")
            || command.contains("swiftlint") {
            return .qualityChecks
        }
        if command.contains(" install") || command.hasSuffix(" install") {
            return .dependencyInstall
        }
        if command.contains("codegen")
            || command.contains("generate")
            || command.contains("rswag")
            || command.contains("protoc") {
            return .codeGeneration
        }
        if command.contains(" logs")
            || command.hasSuffix(" logs")
            || command.contains("tail -f") {
            return .serverLogs
        }
        return .arbitraryUnknown
    }

    private func normalizedTokens(from command: String?) -> [String] {
        guard let command else {
            return []
        }
        let tokens = command
            .replacingOccurrences(of: "&&", with: " ")
            .replacingOccurrences(of: ";", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .map { token in
                token.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                    .lowercased()
            }
            .filter { !$0.isEmpty }
        var normalized: [String] = []
        var isDroppingLeadingAssignments = true
        for token in tokens {
            if isDroppingLeadingAssignments, isEnvironmentAssignment(token) {
                continue
            }
            isDroppingLeadingAssignments = false
            normalized.append(String(token))
        }
        return normalized
    }

    private func isEnvironmentAssignment(_ token: String) -> Bool {
        guard let equalsIndex = token.firstIndex(of: "="), equalsIndex != token.startIndex else {
            return false
        }
        let name = token[..<equalsIndex]
        return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
