/// One bounded provider refresh with explicit health, including partial results.
public struct WorkBriefExternalRefresh: Equatable, Sendable {
    /// Items retained from the most recent successful provider reads.
    public let items: [WorkBriefExternalItem]
    /// Health of the latest attempt.
    public let health: WorkBriefSourceHealth

    /// Creates a provider result.
    /// - Parameters:
    ///   - items: Provider summaries, capped at 100.
    ///   - health: Freshness and completeness of the provider attempt.
    public init(items: [WorkBriefExternalItem], health: WorkBriefSourceHealth) {
        self.items = Array(items.prefix(100))
        self.health = health
    }
}
