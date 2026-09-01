import Foundation

struct WorkspaceSubmittedPromptMetadata: Equatable, Sendable {
    let message: String
    let sessionID: String?
    let submittedAt: Date

    init(message: String, sessionID: String?, submittedAt: Date) {
        self.message = message
        self.sessionID = Self.normalizedSessionID(sessionID)
        self.submittedAt = submittedAt
    }

    private static func normalizedSessionID(_ value: String?) -> String? {
        guard let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !normalized.isEmpty else {
            return nil
        }
        return normalized
    }
}
