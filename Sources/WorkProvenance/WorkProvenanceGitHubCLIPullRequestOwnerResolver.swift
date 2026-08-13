import Foundation

/// Resolves GitHub pull-request owners through the local `gh` auth session.
struct WorkProvenanceGitHubCLIPullRequestOwnerResolver: WorkProvenancePullRequestOwnerResolving {
    private let executableURL: URL?
    private let environment: [String: String]

    init(
        executableURL: URL? = Self.defaultExecutableURL(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.executableURL = executableURL
        self.environment = environment
    }

    func owner(for pullRequestURL: String) async -> WorkProvenancePullRequestOwner? {
        guard let executableURL,
              let pullRequest = GitHubPullRequestURL(pullRequestURL) else {
            return nil
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "api",
            "repos/\(pullRequest.owner)/\(pullRequest.repository)/pulls/\(pullRequest.number)",
            "--jq",
            "[.user.login, .user.html_url, .title, .head.ref] | @tsv",
        ]
        process.environment = environment.merging([
            "GH_NO_UPDATE_NOTIFIER": "1",
            "GH_PROMPT_DISABLED": "1",
        ]) { _, new in new }

        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
            let output = standardOutput.fileHandleForReading.readDataToEndOfFile()
            _ = standardError.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            try? standardOutput.fileHandleForReading.close()
            try? standardError.fileHandleForReading.close()
            guard process.terminationStatus == 0 else {
                return nil
            }
            return Self.owner(from: output)
        } catch {
            try? standardOutput.fileHandleForReading.close()
            try? standardError.fileHandleForReading.close()
            return nil
        }
    }

    private static func owner(from output: Data) -> WorkProvenancePullRequestOwner? {
        guard let line = String(data: output, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !line.isEmpty else {
            return nil
        }
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard let login = fields.first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !login.isEmpty else {
            return nil
        }
        let url = normalizedNonEmpty(fields.dropFirst().first.map(String.init))
        let title = fields.count > 2 ? normalizedNonEmpty(String(fields[2])) : nil
        let branch = fields.count > 3 ? normalizedNonEmpty(String(fields[3])) : nil
        return WorkProvenancePullRequestOwner(
            login: login,
            url: url,
            title: title,
            branch: branch
        )
    }

    private static func defaultExecutableURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL? {
        let configuredPath = normalizedNonEmpty(environment["BMUX_GH_PATH"])
        let candidates = [
            configuredPath,
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh",
        ].compactMap { $0 }
        for path in candidates where fileManager.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private static func normalizedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private struct GitHubPullRequestURL {
        let owner: String
        let repository: String
        let number: Int

        init?(_ rawValue: String) {
            guard let url = URL(string: rawValue),
                  let host = url.host?.lowercased(),
                  host == "github.com" || host == "www.github.com" else {
                return nil
            }
            let components = url.pathComponents.filter { $0 != "/" }
            guard components.count >= 4,
                  components[2].lowercased() == "pull",
                  let number = Int(components[3]) else {
                return nil
            }
            self.owner = components[0]
            self.repository = components[1]
            self.number = number
        }
    }
}
