import BmuxFoundation
import Foundation

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
        iMessageModeEnabled: Bool,
        hiddenPullRequestNumbers: Set<Int> = []
    ) -> String? {
        guard !hidesAllDetails, iMessageModeEnabled else { return nil }
        guard let message = latestSubmittedMessage?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty else {
            return nil
        }
        guard !containsHiddenPullRequestMention(message, hiddenPullRequestNumbers: hiddenPullRequestNumbers) else {
            return nil
        }
        return message
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

    private static func containsHiddenPullRequestMention(
        _ message: String,
        hiddenPullRequestNumbers: Set<Int>
    ) -> Bool {
        guard !hiddenPullRequestNumbers.isEmpty else { return false }
        let pattern = #"https?://github\.com/[^/\s"'<>]+/[^/\s"'<>]+/pull/([0-9]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let nsMessage = message as NSString
        let range = NSRange(location: 0, length: nsMessage.length)
        return regex.matches(in: message, range: range).contains { match in
            guard match.numberOfRanges == 2,
                  let number = Int(nsMessage.substring(with: match.range(at: 1))) else {
                return false
            }
            return hiddenPullRequestNumbers.contains(number)
        }
    }
}
