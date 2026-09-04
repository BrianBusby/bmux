import BMUXAgentLaunch
import Foundation

extension WorkstreamEvent {
    var submittedPromptSessionID: String? {
        Self.normalizedSubmittedPromptSessionID(sessionId, source: source)
    }

    private static func normalizedSubmittedPromptSessionID(_ id: String, source: String) -> String? {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return nil }
        let normalizedSource = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedSource == "codex" || normalizedSource == "claude" else { return trimmedID }
        let sourcePrefix = "\(normalizedSource)-"
        guard trimmedID.lowercased().hasPrefix(sourcePrefix) else { return trimmedID }
        let normalizedID = String(trimmedID.dropFirst(sourcePrefix.count))
        return normalizedID.isEmpty ? nil : normalizedID
    }
}
