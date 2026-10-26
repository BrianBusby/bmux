import Foundation

/// Bounded facts shown by one Work Brief refresh.
public struct WorkBriefSnapshot: Equatable, Sendable {
    /// Current local work, capped by the producer.
    public let localWorkspaces: [WorkBriefLocalWorkspace]
    /// PE and bmux local-source freshness.
    public let localHealth: WorkBriefSourceHealth
    /// Linear freshness.
    public let linearHealth: WorkBriefSourceHealth
    /// GitHub freshness.
    public let githubHealth: WorkBriefSourceHealth
    /// Slack freshness.
    public let slackHealth: WorkBriefSourceHealth

    /// Creates an immutable bounded brief.
    public init(localWorkspaces: [WorkBriefLocalWorkspace], localHealth: WorkBriefSourceHealth,
                linearHealth: WorkBriefSourceHealth, githubHealth: WorkBriefSourceHealth,
                slackHealth: WorkBriefSourceHealth) {
        self.localWorkspaces = Array(localWorkspaces.prefix(100))
        self.localHealth = localHealth
        self.linearHealth = linearHealth
        self.githubHealth = githubHealth
        self.slackHealth = slackHealth
    }
}
