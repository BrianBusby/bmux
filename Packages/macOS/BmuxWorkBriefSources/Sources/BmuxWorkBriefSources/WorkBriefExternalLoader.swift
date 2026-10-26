import BmuxWorkBrief
import Foundation

/// Coalesces local-change refreshes so provider APIs are not queried for every PE update.
public actor WorkBriefExternalLoader {
    private let linear: LinearWorkBriefSource
    private let github: GitHubWorkBriefSource
    private var lastAttemptAt: Date?
    private var cached: (WorkBriefExternalRefresh, WorkBriefExternalRefresh)?

    /// Creates a bounded reader over the two configured sources.
    public init(linear: LinearWorkBriefSource, github: GitHubWorkBriefSource) {
        self.linear = linear
        self.github = github
    }

    /// Returns recent facts for automatic local changes; explicit refresh always checks providers.
    public func refresh(at now: Date, force: Bool) async ->
        (WorkBriefExternalRefresh, WorkBriefExternalRefresh) {
        if !force, let lastAttemptAt, (0..<60).contains(now.timeIntervalSince(lastAttemptAt)),
           let cached { return cached }
        lastAttemptAt = now
        async let linearFacts = linear.refresh(at: now)
        async let githubFacts = github.refresh(at: now)
        let result = await (linearFacts, githubFacts)
        cached = result
        return result
    }
}
