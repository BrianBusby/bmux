import Foundation

/// Preserves the CLI integration fixture's host-CI allowance without changing child environments.
struct CLIProcessTestTimeout: Sendable {
    private let isCI: Bool

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        isCI = environment["GITHUB_ACTIONS"] == "true" || environment["CI"] == "true"
    }

    func seconds(_ requested: TimeInterval) -> TimeInterval {
        isCI ? max(requested, 20) : requested
    }
}
