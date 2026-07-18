struct ContextEfficiencyCommandCategoryCounter: Sendable {
    private let classifier: ContextEfficiencyCommandClassifier

    init(classifier: ContextEfficiencyCommandClassifier = ContextEfficiencyCommandClassifier()) {
        self.classifier = classifier
    }

    func counts(for commandExecutions: [ContextEfficiencyCommandExecutionRecord]) -> [ContextEfficiencyCommandCategoryCount] {
        counts(for: commandExecutions.map(\.category))
    }

    func counts(for toolCalls: [ContextEfficiencyToolCallRecord]) -> [ContextEfficiencyCommandCategoryCount] {
        counts(for: toolCalls.map { classifier.category(for: $0.commandSummary) })
    }

    private func counts(for categories: [ContextEfficiencyCommandCategory]) -> [ContextEfficiencyCommandCategoryCount] {
        var countsByCategory: [ContextEfficiencyCommandCategory: Int] = [:]
        for category in categories {
            countsByCategory[category, default: 0] += 1
        }
        return countsByCategory
            .map { ContextEfficiencyCommandCategoryCount(category: $0.key, commandCount: $0.value) }
            .sorted { $0.category.rawValue < $1.category.rawValue }
    }
}
