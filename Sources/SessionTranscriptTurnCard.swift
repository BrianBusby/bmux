import Foundation

struct SessionTranscriptTurnCard: Identifiable, Equatable, Sendable {
    let id: String
    let ordinal: Int
    let prompt: String
    let startedAt: Date?
    let finishedAt: Date?
    let duration: TimeInterval?
    let summary: String
    let details: [SessionTranscriptTurn]

    static func cards(from turns: [SessionTranscriptTurn]) -> [SessionTranscriptTurnCard] {
        let groups = groupsByUserPrompt(from: turns)
        return groups.enumerated().map { offset, group in
            let startedAt = turnStartDate(in: group)
            let finishedAt = turnFinishDate(in: group)
            return SessionTranscriptTurnCard(
                id: "turn-\(offset)-\(group.first?.id ?? offset)",
                ordinal: offset + 1,
                prompt: prompt(from: group),
                startedAt: startedAt,
                finishedAt: finishedAt,
                duration: duration(startedAt: startedAt, finishedAt: finishedAt),
                summary: summary(from: group),
                details: group
            )
        }
    }

    private static func groupsByUserPrompt(from turns: [SessionTranscriptTurn]) -> [[SessionTranscriptTurn]] {
        var groups: [[SessionTranscriptTurn]] = []
        var leadingContext: [SessionTranscriptTurn] = []
        var current: [SessionTranscriptTurn] = []

        for turn in turns {
            if turn.role == .user {
                if !current.isEmpty {
                    groups.append(current)
                }
                current = leadingContext + [turn]
                leadingContext.removeAll(keepingCapacity: true)
            } else if current.isEmpty {
                leadingContext.append(turn)
            } else {
                current.append(turn)
            }
        }

        if !current.isEmpty {
            groups.append(current)
        } else if !leadingContext.isEmpty {
            groups.append(leadingContext)
        }
        return groups
    }

    private static func prompt(from turns: [SessionTranscriptTurn]) -> String {
        if let prompt = turns.first(where: { $0.role == .user })?.text {
            return snippet(prompt, limit: 220)
        }
        if let firstText = turns.first?.text {
            return snippet(firstText, limit: 220)
        }
        return String(localized: "sessionIndex.turn.prompt.missing", defaultValue: "No prompt captured")
    }

    private static func summary(from turns: [SessionTranscriptTurn]) -> String {
        let agentText = turns
            .first(where: { $0.role == .assistant })?
            .text
        let toolTurns = turns.filter { $0.role == .tool }
        if let agentText {
            let agentSummary = snippet(agentText, limit: toolTurns.isEmpty ? 240 : 180)
            guard !toolTurns.isEmpty else { return agentSummary }
            return String.localizedStringWithFormat(
                String(
                    localized: "sessionIndex.turn.summary.agentAndTools",
                    defaultValue: "%@ - %@"
                ),
                agentSummary,
                toolSummary(from: toolTurns)
            )
        }
        if !toolTurns.isEmpty {
            return toolSummary(from: toolTurns)
        }
        return String(localized: "sessionIndex.turn.summary.noAgentOutput", defaultValue: "No agent output captured")
    }

    private static func toolSummary(from turns: [SessionTranscriptTurn]) -> String {
        let firstTool = turns.first
            .flatMap { firstLine(from: $0.text) }
            .map { snippet($0, limit: 96) }
        if turns.count == 1, let firstTool {
            return String.localizedStringWithFormat(
                String(localized: "sessionIndex.turn.summary.usedTool", defaultValue: "Used %@"),
                firstTool
            )
        }
        if let firstTool {
            return String.localizedStringWithFormat(
                String(localized: "sessionIndex.turn.summary.usedToolAndMore", defaultValue: "Used %@ and %d more"),
                firstTool,
                turns.count - 1
            )
        }
        return String.localizedStringWithFormat(
            String(localized: "sessionIndex.turn.summary.toolCount", defaultValue: "%d tool events"),
            turns.count
        )
    }

    private static func turnStartDate(in turns: [SessionTranscriptTurn]) -> Date? {
        turns.first(where: { $0.role == .user })?.timestamp
            ?? turns.compactMap(\.timestamp).first
    }

    private static func turnFinishDate(in turns: [SessionTranscriptTurn]) -> Date? {
        turns.reversed().compactMap { $0.finishedAt ?? $0.timestamp }.first
    }

    private static func duration(startedAt: Date?, finishedAt: Date?) -> TimeInterval? {
        guard let startedAt, let finishedAt, finishedAt >= startedAt else { return nil }
        return finishedAt.timeIntervalSince(startedAt)
    }

    private static func firstLine(from text: String) -> String? {
        text.split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func snippet(_ text: String, limit: Int) -> String {
        let collapsed = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard collapsed.count > limit else { return collapsed }
        let end = collapsed.index(collapsed.startIndex, offsetBy: limit)
        return String(collapsed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}
