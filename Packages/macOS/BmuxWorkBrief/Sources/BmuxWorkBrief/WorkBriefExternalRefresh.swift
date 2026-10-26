/// One bounded provider refresh with explicit health, including partial results.
public struct WorkBriefExternalRefresh: Equatable, Sendable {
    /// Items retained from the most recent successful provider reads.
    public let items: [WorkBriefExternalItem]
    /// Health of the latest attempt.
    public let health: WorkBriefSourceHealth

    /// Creates a provider result.
    public init(items: [WorkBriefExternalItem], health: WorkBriefSourceHealth) {
        self.items = Array(items.prefix(100))
        self.health = health
    }
}
