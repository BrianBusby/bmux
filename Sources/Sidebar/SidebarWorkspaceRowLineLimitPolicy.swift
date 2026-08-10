import BmuxFoundation

struct SidebarWorkspaceRowLineLimitPolicy {
    struct Subtitle: Equatable {
        let text: String
        let lineLimit: Int
    }

    private static let compactNotificationSubtitleLines = 2
    private static let conversationSubtitleLines = 3
    private static let wrappedWorkspaceTitleLines = 3

    static func titleLineLimit(wrapsWorkspaceTitles: Bool) -> Int {
        wrapsWorkspaceTitles ? wrappedWorkspaceTitleLines : 1
    }

    static func conversationMessage(
        latestSubmittedMessage: String?,
        latestConversationMessage _: String?,
        hidesAllDetails: Bool,
        iMessageModeEnabled: Bool
    ) -> String? {
        guard !hidesAllDetails, iMessageModeEnabled else { return nil }
        return latestSubmittedMessage?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    static func subtitle(notificationText: String?, conversationMessage: String?) -> Subtitle? {
        if let notificationText {
            return Subtitle(text: notificationText, lineLimit: compactNotificationSubtitleLines)
        }
        guard let conversationMessage = conversationMessage?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty else {
            return nil
        }
        return Subtitle(text: conversationMessage, lineLimit: conversationSubtitleLines)
    }
}
