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
    private static let wrappedLinkedTitleLines = 3

    static func titleLineLimit(wrapsWorkspaceTitles: Bool) -> Int {
        wrapsWorkspaceTitles ? wrappedWorkspaceTitleLines : 1
    }

    static func linkedTitleLineLimit(wrapsWorkspaceTitles: Bool) -> Int {
        wrapsWorkspaceTitles ? wrappedLinkedTitleLines : 1
    }

    static func conversationMessage(
        latestSubmittedMessage: String?,
        latestConversationMessage _: String?,
        hidesAllDetails: Bool,
        iMessageModeEnabled: Bool,
        displayedTitle: String? = nil,
        hiddenPullRequestNumbers: Set<Int> = []
    ) -> String? {
        guard !hidesAllDetails, iMessageModeEnabled else { return nil }
        guard let message = normalizedDisplayText(latestSubmittedMessage) else {
            return nil
        }
        guard !displayTextsMatch(message, displayedTitle) else { return nil }
        guard !containsPullRequestMention(message, matchingAny: hiddenPullRequestNumbers) else {
            return nil
        }
        return message
    }

    static func nonDuplicateProgressLabel(
        _ label: String?,
        latestSubmittedMessage: String?,
        workspaceTitle: String?
    ) -> String? {
        guard let label = normalizedDisplayText(label) else { return nil }
        if displayTextsMatch(label, latestSubmittedMessage) {
            return nil
        }
        if displayTextsMatch(label, workspaceTitle) {
            return nil
        }
        return label
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

    static func containsPullRequestMention(
        _ message: String,
        matchingAny pullRequestNumbers: Set<Int>
    ) -> Bool {
        guard !pullRequestNumbers.isEmpty else { return false }
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
            return pullRequestNumbers.contains(number)
        }
    }

    private static func displayTextsMatch(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs = normalizedDisplayText(lhs),
              let rhs = normalizedDisplayText(rhs) else {
            return false
        }
        return lhs == rhs
    }

    private static func normalizedDisplayText(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}
