import Foundation

/// Reads Linear credentials from the process environment.
struct WorkProvenanceEnvironmentLinearAuthorizationProvider: WorkProvenanceLinearAuthorizationProviding {
    private let environment: [String: String]

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

    func authorizationHeader() async -> String? {
        Self.authorizationHeader(environment: environment)
    }

    static func authorizationHeader(environment: [String: String]) -> String? {
        for key in ["BMUX_LINEAR_AUTHORIZATION", "LINEAR_AUTHORIZATION"] {
            if let value = normalizedNonEmpty(environment[key]) {
                return value
            }
        }
        for key in ["BMUX_LINEAR_API_KEY", "LINEAR_API_KEY", "LINEAR_API_TOKEN"] {
            if let value = normalizedNonEmpty(environment[key]) {
                return value
            }
        }
        for key in ["BMUX_LINEAR_ACCESS_TOKEN", "LINEAR_ACCESS_TOKEN"] {
            if let value = normalizedNonEmpty(environment[key]) {
                return "Bearer \(value)"
            }
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
}
