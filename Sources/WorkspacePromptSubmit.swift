import BMUXAgentLaunch
import BmuxSidebar
import Bonsplit
import Foundation

enum IMessageModeSettings {
    static let key = "app.iMessageMode"
    static let defaultValue = false

    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: key) == nil {
            return defaultValue
        }
        return defaults.bool(forKey: key)
    }
}

/// Per-workspace-group behavior knobs for sidebar iMessage mode.
///
/// - `sortInsideGroups` (default true): when iMessage mode floats workspaces
///   by latest unread, members within a group sort by unread while the group
///   section position stays put.
/// - `floatGroups` (default false): when true, the group section itself
///   reorders by its most-recent unread member.
///
/// Both knobs are persisted to UserDefaults via the keys below and mirrored
/// in `~/.config/bmux/bmux.json` under `sidebar.imessageMode.*`. The sort
/// path treats the current build as passthrough until the broader iMessage
/// sort logic exists; the knobs land here so user-set values survive the
/// upgrade that activates the behavior.
enum IMessageModeGroupSortSettings {
    static let sortInsideGroupsKey = "app.iMessageMode.sortInsideGroups"
    static let floatGroupsKey = "app.iMessageMode.floatGroups"
    static let sortInsideGroupsDefault = true
    static let floatGroupsDefault = false

    static func sortInsideGroups(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: sortInsideGroupsKey) == nil {
            return sortInsideGroupsDefault
        }
        return defaults.bool(forKey: sortInsideGroupsKey)
    }

    static func floatGroups(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: floatGroupsKey) == nil {
            return floatGroupsDefault
        }
        return defaults.bool(forKey: floatGroupsKey)
    }

    static func setSortInsideGroups(_ value: Bool, defaults: UserDefaults = .standard) {
        if value == sortInsideGroupsDefault {
            defaults.removeObject(forKey: sortInsideGroupsKey)
        } else {
            defaults.set(value, forKey: sortInsideGroupsKey)
        }
    }

    static func setFloatGroups(_ value: Bool, defaults: UserDefaults = .standard) {
        if value == floatGroupsDefault {
            defaults.removeObject(forKey: floatGroupsKey)
        } else {
            defaults.set(value, forKey: floatGroupsKey)
        }
    }
}

extension WorkstreamEvent {
    var submittedPromptMessage: String? {
        guard hookEventName == .userPromptSubmit else { return nil }
        let contextMessage = context?.lastUserMessage.flatMap(Self.normalizedPromptText)
        return Self.messageText(fromJSON: toolInputJSON, keys: Self.promptMessageKeys)
            ?? contextMessage
            ?? Self.messageText(fromJSON: extraFieldsJSON, keys: Self.promptMessageKeys)
    }

    var assistantFinalMessage: String? {
        guard hookEventName == .stop else { return nil }
        let contextMessage = context?.assistantPreamble.flatMap(Self.normalizedPromptText)
        return contextMessage
            ?? Self.messageText(fromJSON: extraFieldsJSON, keys: Self.assistantMessageKeys)
            ?? Self.messageText(fromJSON: toolInputJSON, keys: Self.assistantMessageKeys)
    }

    private static let promptMessageKeys = ["prompt", "text", "message", "body"]
    private static let assistantMessageKeys = [
        "last_assistant_message",
        "lastAssistantMessage",
        "assistantPreamble",
        "assistant_preamble",
        "last_agent_message",
        "lastAgentMessage",
    ]

    private static func messageText(fromJSON jsonString: String?, keys: [String]) -> String? {
        guard let jsonString else { return nil }
        guard let data = jsonString.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        else {
            return normalizedPromptText(jsonString)
        }

        if let string = value as? String {
            return normalizedPromptText(string)
        }
        guard let dict = value as? [String: Any] else { return nil }
        return messageText(from: dict, keys: keys)
    }

    private static func messageText(from dict: [String: Any], keys: [String]) -> String? {
        if let direct = firstMessageString(in: dict, keys: keys) {
            return direct
        }
        for key in ["notification", "data"] {
            if let nested = dict[key] as? [String: Any],
               let nestedMessage = firstMessageString(in: nested, keys: keys) {
                return nestedMessage
            }
        }
        return nil
    }

    private static func firstMessageString(in dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let value = dict[key] as? String,
                  let normalized = normalizedPromptText(value) else { continue }
            return normalized
        }
        return nil
    }

    private static func normalizedPromptText(_ value: String) -> String? {
        let normalized = value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

extension TabManager {
    private enum ConversationMessageKind {
        case promptSubmission
        case assistantFinal
    }

    @discardableResult
    func handlePromptSubmit(
        workspaceId: UUID,
        message: String?,
        surfaceId: UUID? = nil,
        iMessageModeEnabled: Bool = IMessageModeSettings.isEnabled()
    ) -> (messageRecorded: Bool, reordered: Bool, index: Int)? {
        handleConversationMessage(
            workspaceId: workspaceId,
            message: message,
            surfaceId: surfaceId,
            iMessageModeEnabled: iMessageModeEnabled,
            kind: .promptSubmission,
            reorderWithoutMessage: true
        )
    }

    @discardableResult
    func handleAssistantFinalMessage(
        workspaceId: UUID,
        message: String?,
        surfaceId: UUID? = nil,
        iMessageModeEnabled: Bool = IMessageModeSettings.isEnabled()
    ) -> (messageRecorded: Bool, reordered: Bool, index: Int)? {
        handleConversationMessage(
            workspaceId: workspaceId,
            message: message,
            surfaceId: surfaceId,
            iMessageModeEnabled: iMessageModeEnabled,
            kind: .assistantFinal,
            reorderWithoutMessage: false
        )
    }

    private func handleConversationMessage(
        workspaceId: UUID,
        message: String?,
        surfaceId: UUID? = nil,
        iMessageModeEnabled: Bool,
        kind: ConversationMessageKind,
        reorderWithoutMessage: Bool
    ) -> (messageRecorded: Bool, reordered: Bool, index: Int)? {
        guard let originalIndex = tabs.firstIndex(where: { $0.id == workspaceId }) else {
            return nil
        }

        let workspace = tabs[originalIndex]
        let hasMessage = Workspace.conversationMessagePreview(from: message) != nil
        let messageRecorded: Bool
        switch kind {
        case .promptSubmission:
            _ = workspace.recordPromptNavigationBookmark(surfaceId: surfaceId, message: message)
            _ = workspace.recordSubmittedPullRequestMention(message, surfaceId: surfaceId)
            messageRecorded = workspace.recordSubmittedMessage(message)
            if messageRecorded {
                BmuxEventBus.shared.publishWorkspacePromptSubmitted(
                    workspaceId: workspaceId,
                    message: message,
                    preview: Workspace.conversationMessagePreview(from: message)
                )
            }
        case .assistantFinal:
            _ = workspace.recordSubmittedPullRequestMention(message, surfaceId: surfaceId)
            guard iMessageModeEnabled else {
                return (false, false, originalIndex)
            }
            messageRecorded = workspace.recordConversationMessage(message)
        }
        guard iMessageModeEnabled else {
            return (messageRecorded, false, originalIndex)
        }
        guard messageRecorded || reorderWithoutMessage || hasMessage else {
            return (messageRecorded, false, originalIndex)
        }
        moveTabToTop(workspaceId)
        let newIndex = tabs.firstIndex(where: { $0.id == workspaceId }) ?? originalIndex
        return (messageRecorded, newIndex != originalIndex, newIndex)
    }
}

extension Workspace {
    static func conversationMessagePreview(from message: String?, maxLength: Int = 240) -> String? {
        guard let message else { return nil }
        let collapsed = message
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        guard collapsed.count > maxLength else { return collapsed }
        return "\(collapsed.prefix(maxLength))..."
    }

    @discardableResult
    func recordSubmittedPullRequestMention(_ message: String?, surfaceId: UUID?) -> Bool {
        guard let panelId = promptMentionPanelId(from: surfaceId) ?? focusedPanelId else {
            return false
        }
        let recordedBranchIntent = recordSubmittedBranchIntent(message)
        if let mention = Self.submittedPromptPullRequestMention(from: message) {
            recordSubmittedPullRequestIntent(number: mention.number)
            updatePanelPullRequest(
                panelId: panelId,
                number: mention.number,
                label: "PR",
                url: mention.url,
                status: .open,
                bindToCurrentBranch: false,
                source: .promptMention
            )
            return true
        }
        guard let number = Self.submittedPromptPullRequestNumber(from: message) else {
            return recordedBranchIntent
        }
        recordSubmittedPullRequestIntent(number: number)
        guard let existing = existingPullRequestForPromptMention(number: number, panelId: panelId) else {
            return true
        }
        updatePanelPullRequest(
            panelId: panelId,
            number: existing.number,
            title: existing.title,
            label: existing.label,
            url: existing.url,
            ownerLogin: existing.ownerLogin,
            ownerURL: existing.ownerURL,
            status: existing.status,
            isStale: false,
            bindToCurrentBranch: false,
            source: .promptMention
        )
        return true
    }

    @discardableResult
    func recordPromptNavigationBookmark(surfaceId: UUID?, message: String? = nil) -> Bool {
        guard let terminalPanel = promptNavigationTerminalPanel(from: surfaceId) else {
            return false
        }
        return terminalPanel.recordPromptNavigationBookmark(message: message)
    }

    private func promptNavigationTerminalPanel(from surfaceId: UUID?) -> TerminalPanel? {
        if let panelId = promptMentionPanelId(from: surfaceId),
           let terminalPanel = panels[panelId] as? TerminalPanel {
            return terminalPanel
        }
        return focusedTerminalPanel
    }

    private func promptMentionPanelId(from surfaceId: UUID?) -> UUID? {
        guard let surfaceId else { return nil }
        if panels[surfaceId] != nil {
            return surfaceId
        }
        return panelIdFromSurfaceId(TabID(uuid: surfaceId))
    }

    private func existingPullRequestForPromptMention(number: Int, panelId: UUID) -> SidebarPullRequestState? {
        if let panelPullRequest = panelPullRequests[panelId],
           panelPullRequest.number == number {
            return panelPullRequest
        }
        if let pullRequest,
           pullRequest.number == number {
            return pullRequest
        }
        return sidebarPullRequestsInDisplayOrder().first { $0.number == number }
    }

    private func recordSubmittedPullRequestIntent(number: Int) {
        workspacePromptPullRequestIntentNumbers.insert(number)
    }

    @discardableResult
    private func recordSubmittedBranchIntent(_ message: String?) -> Bool {
        guard let branch = Self.submittedPromptBranchMention(from: message) else {
            return false
        }
        workspacePromptBranchIntentNames.insert(branch.normalizedSidebarBranchName)
        return true
    }

    static func submittedPromptPullRequestMention(
        from message: String?,
        matchingNumber expectedNumber: Int? = nil
    ) -> (number: Int, url: URL)? {
        guard let message else { return nil }
        let pattern = #"https?://github\.com/([^/\s"'<>]+)/([^/\s"'<>]+)/pull/([0-9]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsMessage = message as NSString
        let range = NSRange(location: 0, length: nsMessage.length)
        for match in regex.matches(in: message, range: range) {
            guard match.numberOfRanges == 4,
                  let number = Int(nsMessage.substring(with: match.range(at: 3))),
                  expectedNumber == nil || expectedNumber == number else {
                continue
            }
            let owner = nsMessage.substring(with: match.range(at: 1))
            let repo = nsMessage.substring(with: match.range(at: 2))
            guard let url = URL(string: "https://github.com/\(owner)/\(repo)/pull/\(number)") else {
                continue
            }
            return (number, url)
        }
        return nil
    }

    static func submittedPromptPullRequestNumber(
        from message: String?,
        matchingNumber expectedNumber: Int? = nil
    ) -> Int? {
        guard let message else { return nil }
        let pattern = #"(?i)(?:https?://github\.com/[^/\s"'<>]+/[^/\s"'<>]+/pull/|(?:\bPR\b|\bpull request\b|\bpull\b)\s*#?\s*)([0-9]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let nsMessage = message as NSString
        let range = NSRange(location: 0, length: nsMessage.length)
        for match in regex.matches(in: message, range: range) {
            guard match.numberOfRanges == 2,
                  let number = Int(nsMessage.substring(with: match.range(at: 1))),
                  expectedNumber == nil || expectedNumber == number else {
                continue
            }
            return number
        }
        return nil
    }

    static func submittedPromptBranchMention(from message: String?) -> String? {
        guard let message else { return nil }
        let pattern = #"(?i)\bbranch\s+([A-Za-z0-9][A-Za-z0-9._/\-]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let nsMessage = message as NSString
        let range = NSRange(location: 0, length: nsMessage.length)
        for match in regex.matches(in: message, range: range) {
            guard match.numberOfRanges == 2 else { continue }
            let branch = nsMessage.substring(with: match.range(at: 1)).normalizedSidebarBranchName
            guard !branch.isEmpty else { continue }
            return branch
        }
        return nil
    }
}
