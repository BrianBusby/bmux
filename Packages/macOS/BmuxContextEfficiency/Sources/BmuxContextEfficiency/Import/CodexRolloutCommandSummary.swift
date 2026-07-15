import Foundation

struct CodexRolloutCommandSummary: Sendable {
    private let maxCommandCharacters: Int

    init(maxCommandCharacters: Int = 180) {
        self.maxCommandCharacters = max(16, maxCommandCharacters)
    }

    func summary(from arguments: Any?) -> (command: String?, byteCount: Int64) {
        if let arguments = arguments as? String {
            return (commandSummary(from: arguments), Int64(arguments.lengthOfBytes(using: .utf8)))
        }
        if let arguments = arguments as? [String: Any] {
            let command = commandValue(in: arguments).flatMap(summarizedCommand)
            let byteCount = (try? JSONSerialization.data(withJSONObject: arguments).count).map(Int64.init) ?? 0
            return (command, byteCount)
        }
        return (nil, 0)
    }

    private func commandSummary(from arguments: String) -> String? {
        let trimmed = arguments.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        if let data = trimmed.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let command = commandValue(in: object).flatMap(summarizedCommand) {
            return command
        }
        return summarizedCommand(trimmed)
    }

    private func commandValue(in object: [String: Any]) -> String? {
        for key in ["cmd", "command", "script"] {
            if let value = object[key] as? String {
                return value
            }
        }
        return nil
    }

    private func summarizedCommand(_ command: String) -> String? {
        let collapsed = command
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else {
            return nil
        }
        guard collapsed.count > maxCommandCharacters else {
            return collapsed
        }
        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: maxCommandCharacters - 3)
        return String(collapsed[..<endIndex]) + "..."
    }
}
