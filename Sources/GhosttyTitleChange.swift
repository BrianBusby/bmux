import Foundation

/// Typed payload for `.ghosttyDidSetTitle` notifications.
struct GhosttyTitleChange: Equatable, Sendable {
    let tabId: UUID
    let surfaceId: UUID
    let title: String

    init(tabId: UUID, surfaceId: UUID, title: String) {
        self.tabId = tabId
        self.surfaceId = surfaceId
        self.title = title
    }

    init?(notification: Notification) {
        guard let tabId = notification.userInfo?[GhosttyNotificationKey.tabId] as? UUID,
              let surfaceId = notification.userInfo?[GhosttyNotificationKey.surfaceId] as? UUID,
              let title = notification.userInfo?[GhosttyNotificationKey.title] as? String else {
            return nil
        }
        self.init(tabId: tabId, surfaceId: surfaceId, title: title)
    }

    var userInfo: [String: Any] {
        [
            GhosttyNotificationKey.tabId: tabId,
            GhosttyNotificationKey.surfaceId: surfaceId,
            GhosttyNotificationKey.title: title,
        ]
    }
}

struct TerminalProcessTitleSanitizer: Sendable {
    func sanitizedTitle(_ title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let firstCharacter = trimmed.first,
              firstCharacter.unicodeScalars.count == 1,
              let firstScalar = firstCharacter.unicodeScalars.first,
              Self.isKnownAgentSpinnerScalar(firstScalar) else {
            return trimmed
        }

        let afterSpinner = trimmed.index(after: trimmed.startIndex)
        guard afterSpinner < trimmed.endIndex else { return nil }
        guard trimmed[afterSpinner].isWhitespace else { return trimmed }

        let titleWithoutSpinner = String(trimmed[afterSpinner...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return titleWithoutSpinner.isEmpty ? nil : titleWithoutSpinner
    }

    private static func isKnownAgentSpinnerScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x2800...0x28FF, // Codex-style braille spinner frames.
             0x2722...0x273F: // Claude-style star spinner frames.
            return true
        default:
            return false
        }
    }
}
