import Foundation

extension TabManager {
    /// Applies a user-facing workspace rename. Empty input is rejected instead
    /// of being interpreted as a clear-name request.
    @discardableResult
    func renameWorkspaceTitle(
        tabId: UUID,
        title: String,
        propagateToRemoteTmux: Bool = true
    ) -> Workspace.CustomTitleApplyOutcome {
        applyWorkspaceTitleEdit(
            tabId: tabId,
            title: title,
            emptyTitleClears: false,
            propagateToRemoteTmux: propagateToRemoteTmux
        )
    }

    /// Commits a user-facing workspace title draft. Empty input clears the
    /// custom title, matching palette/modal rename behavior.
    @discardableResult
    func commitWorkspaceTitleEdit(
        tabId: UUID,
        title: String,
        propagateToRemoteTmux: Bool = true
    ) -> Workspace.CustomTitleApplyOutcome {
        applyWorkspaceTitleEdit(
            tabId: tabId,
            title: title,
            emptyTitleClears: true,
            propagateToRemoteTmux: propagateToRemoteTmux
        )
    }

    /// Clears a user-facing workspace title through the shared action path.
    @discardableResult
    func clearWorkspaceTitleForAction(
        tabId: UUID,
        propagateToRemoteTmux: Bool = true
    ) -> Workspace.CustomTitleApplyOutcome {
        applyWorkspaceTitleEdit(
            tabId: tabId,
            title: nil,
            emptyTitleClears: true,
            propagateToRemoteTmux: propagateToRemoteTmux
        )
    }

    /// Shared user-input path for workspace title mutation. Entry points choose
    /// whether an empty draft clears or rejects, but normalization, mutation,
    /// event emission, and remote tmux propagation stay here.
    @discardableResult
    func applyWorkspaceTitleEdit(
        tabId: UUID,
        title: String?,
        emptyTitleClears: Bool,
        propagateToRemoteTmux: Bool = true
    ) -> Workspace.CustomTitleApplyOutcome {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            if emptyTitleClears {
                return applyCustomTitle(
                    tabId: tabId,
                    title: nil,
                    source: .user,
                    propagateToRemoteTmux: propagateToRemoteTmux
                )
            }
            return .rejected(.emptyTitle)
        }
        return applyCustomTitle(
            tabId: tabId,
            title: trimmed,
            source: .user,
            propagateToRemoteTmux: propagateToRemoteTmux
        )
    }

    /// Sets, replaces, or clears a workspace custom title. Returns whether the
    /// write landed (auto writes are rejected over user-set titles; see
    /// ``Workspace/setCustomTitle(_:source:)``).
    @discardableResult
    func setCustomTitle(
        tabId: UUID,
        title: String?,
        source: Workspace.CustomTitleSource = .user,
        propagateToRemoteTmux: Bool = true
    ) -> Bool {
        applyCustomTitle(
            tabId: tabId,
            title: title,
            source: source,
            propagateToRemoteTmux: propagateToRemoteTmux
        ).applied
    }

    @discardableResult
    func applyCustomTitle(
        tabId: UUID,
        title: String?,
        source: Workspace.CustomTitleSource = .user,
        propagateToRemoteTmux: Bool = true
    ) -> Workspace.CustomTitleApplyOutcome {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else {
            return .rejected(.targetMissing)
        }
        let previousDisplayTitle = resolvedWorkspaceDisplayTitle(for: tabs[index])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let outcome = tabs[index].applyCustomTitle(title, source: source)
        let applied = outcome.applied
        if applied, selectedTabId == tabId {
            updateWindowTitle(for: tabs[index])
        }
        let currentDisplayTitle = resolvedWorkspaceDisplayTitle(for: tabs[index])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if applied, currentDisplayTitle != previousDisplayTitle {
            NotificationCenter.default.post(
                name: .workspaceTitleDidChange,
                object: self,
                userInfo: [GhosttyNotificationKey.tabId: tabId]
            )
        }
        // A remote tmux mirror workspace rename propagates to `rename-session`,
        // but only when the write landed (an auto write rejected over a
        // user-set title must not desync the remote session name).
        if applied, propagateToRemoteTmux, tabs[index].isRemoteTmuxMirror {
            AppDelegate.shared?.remoteTmuxController.handleMirrorWorkspaceRenamed(
                workspaceId: tabId,
                title: title
            )
        }
        return outcome
    }

    func clearCustomTitle(tabId: UUID) {
        clearWorkspaceTitleForAction(tabId: tabId)
    }

    /// Whether a `.workspaceTitleDidChange` notification should refresh cached
    /// title chrome (content-header text / toolbar command label). Surface-sourced
    /// posts follow the coalescing split; direct workspace-title changes always
    /// refresh for the selected workspace (#7365).
    func shouldRefreshTitleChrome(for notification: Notification) -> Bool {
        shouldRefreshTitleChrome(
            tabId: notification.userInfo?[GhosttyNotificationKey.tabId] as? UUID,
            surfaceSourced: notification.userInfo?[GhosttyNotificationKey.surfaceId] != nil
        )
    }

    /// Sendable-values core of ``shouldRefreshTitleChrome(for:)`` for observers
    /// that hop actors before deciding: extract `tabId`/`surfaceSourced` where the
    /// notification is delivered, so the non-Sendable `Notification` never crosses
    /// a `Task` boundary.
    func shouldRefreshTitleChrome(tabId: UUID?, surfaceSourced: Bool) -> Bool {
        guard let tabId, tabId == selectedTabId else { return false }
        return !(surfaceSourced && shouldScheduleRawTitleRefresh(forWorkspaceId: tabId))
    }
}
