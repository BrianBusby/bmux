import Foundation

/// Display-only interpretation; raw evidence is never rewritten.
struct ExpandedTurnRequest: Equatable {
    struct Reply: Decodable, Equatable {
        let question: String
        let answer: String
    }

    let objective: String?
    let prompt: String?
    let identical: Bool
    let replies: [Reply]?
    var hasObjective: Bool { objective?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
    var hasPrompt: Bool { prompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }

    init(objective: String?, prompt: String?) {
        self.objective = objective
        self.prompt = prompt
        identical = objective != nil && prompt != nil
            && objective?.trimmingCharacters(in: .whitespacesAndNewlines).utf8.elementsEqual(
                (prompt ?? "").trimmingCharacters(in: .whitespacesAndNewlines).utf8
            ) == true
        replies = Self.parse(objective)
    }

    static func visibleSummary(_ summary: String?, finalOutput: String?) -> String? {
        guard let summary else { return nil }
        let comparison = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !comparison.isEmpty else { return nil }
        if let finalOutput, finalOutput.trimmingCharacters(in: .whitespacesAndNewlines).range(of: comparison, options: .literal) != nil {
            return nil
        }
        return summary
    }

    private static func parse(_ raw: String?) -> [Reply]? {
        guard let raw, raw.utf8.count <= 65_536 else { return nil }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let opening = "<send_user_message_question_reply>"
        let closing = "</send_user_message_question_reply>"
        guard text.hasPrefix(opening), text.hasSuffix(closing),
              text.count >= opening.count + closing.count else { return nil }
        let payload = text.dropFirst(opening.count).dropLast(closing.count)
        guard let values = try? JSONDecoder().decode([Reply].self, from: Data(payload.utf8)),
              !values.isEmpty,
              values.allSatisfy({ !$0.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return nil }
        return values
    }
}
