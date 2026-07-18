/// Count of derived command executions in one normalized command category.
public struct ContextEfficiencyCommandCategoryCount: Codable, Equatable, Sendable {
    /// Classified command family.
    public var category: ContextEfficiencyCommandCategory
    /// Number of command executions classified into the category.
    public var commandCount: Int

    /// Creates a command-category count row.
    ///
    /// - Parameters:
    ///   - category: Classified command family.
    ///   - commandCount: Number of command executions classified into the category.
    public init(category: ContextEfficiencyCommandCategory, commandCount: Int) {
        self.category = category
        self.commandCount = commandCount
    }
}
