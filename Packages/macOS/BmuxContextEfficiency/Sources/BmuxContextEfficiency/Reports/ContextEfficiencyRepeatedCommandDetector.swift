import Foundation

struct ContextEfficiencyRepeatedCommandDetector: Sendable {
    private let maxSampleCommandExecutionIDs = 20

    func facts(
        for commandExecutions: [ContextEfficiencyCommandExecutionRecord]
    ) -> [ContextEfficiencyRepeatedCommandFact] {
        var commandsByKey: [String: [ContextEfficiencyCommandExecutionRecord]] = [:]
        var normalizedCommandsByKey: [String: String] = [:]
        for command in commandExecutions {
            guard let normalizedCommand = normalizedCommand(from: command.commandSummary) else {
                continue
            }
            let key = groupKey(
                threadID: command.threadID,
                kind: kind(for: command.category),
                category: command.category,
                normalizedCommand: normalizedCommand
            )
            commandsByKey[key, default: []].append(command)
            normalizedCommandsByKey[key] = normalizedCommand
        }
        return commandsByKey.compactMap { key, commands in
            guard commands.count > 1,
                  let first = commands.min(by: { orderedBefore($0, $1) }),
                  let last = commands.max(by: { orderedBefore($0, $1) }),
                  let normalizedCommand = normalizedCommandsByKey[key],
                  let representative = first.commandSummary else {
                return nil
            }
            let kind = kind(for: first.category)
            let fingerprint = fingerprint(for: normalizedCommand)
            return ContextEfficiencyRepeatedCommandFact(
                id: "repeated-command:\(first.threadID):\(kind.rawValue):\(fingerprint)",
                threadID: first.threadID,
                kind: kind,
                category: first.category,
                normalizedExecutable: first.normalizedExecutable,
                representativeCommandSummary: representative,
                normalizedCommandFingerprint: fingerprint,
                occurrenceCount: commands.count,
                sampleCommandExecutionIDs: Array(commands.sorted(by: orderedBefore).map(\.id).prefix(maxSampleCommandExecutionIDs)),
                firstSourceReference: first.toolCallSourceReference,
                lastSourceReference: last.toolCallSourceReference
            )
        }
        .sorted {
            if $0.firstSourceReference.sourcePath != $1.firstSourceReference.sourcePath {
                return $0.firstSourceReference.sourcePath < $1.firstSourceReference.sourcePath
            }
            if $0.firstSourceReference.lineNumber != $1.firstSourceReference.lineNumber {
                return $0.firstSourceReference.lineNumber < $1.firstSourceReference.lineNumber
            }
            return $0.firstSourceReference.byteOffset < $1.firstSourceReference.byteOffset
        }
    }

    private func normalizedCommand(from commandSummary: String?) -> String? {
        guard let commandSummary else {
            return nil
        }
        let normalized = commandSummary
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized.isEmpty ? nil : normalized
    }

    private func kind(for category: ContextEfficiencyCommandCategory) -> ContextEfficiencyCommandRepetitionKind {
        switch category {
        case .sourceSearch:
            return .sourceSearch
        case .fileReading:
            return .fileReading
        default:
            return .command
        }
    }

    private func groupKey(
        threadID: String,
        kind: ContextEfficiencyCommandRepetitionKind,
        category: ContextEfficiencyCommandCategory,
        normalizedCommand: String
    ) -> String {
        [threadID, kind.rawValue, category.rawValue, normalizedCommand].joined(separator: "\u{1f}")
    }

    private func fingerprint(for normalizedCommand: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in normalizedCommand.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "fnv1a64:%016llx", hash)
    }

    private func orderedBefore(
        _ lhs: ContextEfficiencyCommandExecutionRecord,
        _ rhs: ContextEfficiencyCommandExecutionRecord
    ) -> Bool {
        let left = lhs.toolCallSourceReference
        let right = rhs.toolCallSourceReference
        if left.sourcePath != right.sourcePath {
            return left.sourcePath < right.sourcePath
        }
        if left.lineNumber != right.lineNumber {
            return left.lineNumber < right.lineNumber
        }
        return left.byteOffset < right.byteOffset
    }
}
