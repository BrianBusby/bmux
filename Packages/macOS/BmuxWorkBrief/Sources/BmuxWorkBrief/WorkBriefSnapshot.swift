import Foundation

/// Bounded facts shown by one Work Brief refresh.
public struct WorkBriefSnapshot: Equatable, Sendable {
    /// Current local work, capped by the producer.
    public let localWorkspaces: [WorkBriefLocalWorkspace]
    /// Provider facts, capped independently of source page sizes.
    public let externalItems: [WorkBriefExternalItem]
    /// PE and bmux local-source freshness.
    public let localHealth: WorkBriefSourceHealth
    /// Linear freshness.
    public let linearHealth: WorkBriefSourceHealth
    /// GitHub freshness.
    public let githubHealth: WorkBriefSourceHealth
    /// Slack freshness.
    public let slackHealth: WorkBriefSourceHealth

    /// Creates an immutable bounded brief.
    /// - Parameters:
    ///   - localWorkspaces: Open local workspaces, capped at 100.
    ///   - externalItems: Bounded provider summaries, capped at 200.
    ///   - localHealth: Freshness and completeness of bmux and PE local facts.
    ///   - linearHealth: Freshness of Linear facts.
    ///   - githubHealth: Freshness of GitHub facts.
    ///   - slackHealth: Freshness of opted-in Slack facts.
    public init(localWorkspaces: [WorkBriefLocalWorkspace], externalItems: [WorkBriefExternalItem] = [],
                localHealth: WorkBriefSourceHealth,
                linearHealth: WorkBriefSourceHealth, githubHealth: WorkBriefSourceHealth,
                slackHealth: WorkBriefSourceHealth) {
        self.localWorkspaces = Array(localWorkspaces.prefix(100))
        self.externalItems = Array(externalItems.prefix(200))
        self.localHealth = localHealth
        self.linearHealth = linearHealth
        self.githubHealth = githubHealth
        self.slackHealth = slackHealth
    }
}
