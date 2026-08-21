public import Foundation

extension PullRequestProbeService {
    private struct PullRequestViewPayload: Decodable, Sendable {
        struct Author: Decodable, Sendable {
            let login: String?
            let url: String?
        }

        let number: Int
        let state: String
        let title: String?
        let url: String
        let author: Author?
    }

    /// Resolves metadata for an explicitly mentioned GitHub pull-request URL.
    ///
    /// Branch polling resolves PRs from local git state. Prompt mentions are
    /// already exact PR URLs, so a targeted `gh pr view` keeps private-repo
    /// auth behavior aligned with the shell integration and is easy to fake in
    /// app-level regression tests.
    public nonisolated func fetchPromptMentionPullRequest(
        url: URL,
        expectedNumber: Int
    ) async -> GitHubPullRequestProbeItem? {
        guard Self.githubPullRequestNumber(from: url) == expectedNumber else {
            return nil
        }
        let output = await commandRunner.runStandardOutput(
            directory: FileManager.default.currentDirectoryPath,
            executable: "gh",
            arguments: [
                "pr",
                "view",
                url.absoluteString,
                "--json",
                "number,state,title,url,author",
            ],
            timeout: Self.probeTimeout
        )
        guard let output,
              let data = output.data(using: .utf8),
              let payload = Self.decodeJSON(PullRequestViewPayload.self, from: data),
              payload.number == expectedNumber else {
            return nil
        }
        return GitHubPullRequestProbeItem(
            number: payload.number,
            title: payload.title,
            state: payload.state,
            url: payload.url,
            ownerLogin: payload.author?.login,
            ownerURLString: payload.author?.url,
            updatedAt: nil,
            mergedAt: nil,
            headRefName: nil,
            baseRefName: nil
        )
    }

    nonisolated static func githubPullRequestNumber(from url: URL) -> Int? {
        guard url.scheme == "https" || url.scheme == "http",
              url.host?.caseInsensitiveCompare("github.com") == .orderedSame else {
            return nil
        }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 4,
              components[2] == "pull" else {
            return nil
        }
        return Int(components[3])
    }
}
