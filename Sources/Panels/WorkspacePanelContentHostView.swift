import SwiftUI
import BmuxAppKitSupportUI
import Bonsplit

struct WorkspacePanelContentHostView: View {
    let workspace: Workspace
    let panel: any Panel
    let paneId: PaneID
    let isFocused: Bool
    let isSelectedInPane: Bool
    let isVisibleInUI: Bool
    let portalPriority: Int
    let isSplit: Bool
    let appearance: PanelAppearance
    let windowAppearance: WindowAppearanceSnapshot
    let customSidebarTabManager: TabManager?
    let hasUnreadNotification: Bool
    let onFocus: () -> Void
    let onRequestPanelFocus: () -> Void
    let onResumeAgentHibernation: () -> Void
    let onAutoResumeAgentHibernation: () -> Void
    let onTriggerFlash: () -> Void

    var body: some View {
        PanelContentView(
            panel: panel,
            workspaceId: workspace.id,
            stableWorkspaceId: workspace.stableId,
            paneId: paneId,
            isFocused: isFocused,
            isSelectedInPane: isSelectedInPane,
            isVisibleInUI: isVisibleInUI,
            portalPriority: portalPriority,
            isSplit: isSplit,
            appearance: appearance,
            windowAppearance: windowAppearance,
            customSidebarTabManager: customSidebarTabManager,
            workspaceChrome: workspaceChrome,
            hasUnreadNotification: hasUnreadNotification,
            terminalAgentContext: WorkspaceContentView.terminalAgentContext(panel: panel, workspace: workspace),
            onStartConnectedSession: workspace.remoteConfiguration == nil && !workspace.isRemoteTmuxMirror ? { [weak workspace, panelID = panel.id] in
                guard let workspace else { throw AgentSessionBridgeError.invalidRequest }
                try await workspace.startConnectedCodex(from: panelID)
            } : nil,
            terminalChatReader: workspace.owningTabManager?.terminalChatReader,
            workProvenanceRuntime: workspace.owningTabManager?.workProvenanceRuntime,
            onFocus: onFocus,
            onRequestPanelFocus: onRequestPanelFocus,
            onRequestTerminalChatFocus: { [weak workspace, panelID = panel.id] in
                workspace?.focusConnectedCodexChat(panelID: panelID)
            },
            onResumeAgentHibernation: onResumeAgentHibernation,
            onAutoResumeAgentHibernation: onAutoResumeAgentHibernation,
            onTriggerFlash: onTriggerFlash
        )
    }

    private var workspaceChrome: AgentSessionWorkspaceChrome {
        let display = workspace.owningTabManager?.workProvenanceRuntime?.workspaceDisplayCurrentStateSnapshot(for: workspace)
        let repository = URL(fileURLWithPath: workspace.currentDirectory, isDirectory: true)
            .lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var links: [AgentSessionWorkspaceLink] = []
        if let pullRequest = display?.pullRequest {
            links.append(AgentSessionWorkspaceLink(
                id: "pr-\(pullRequest.number)",
                label: pullRequest.status.map { "PR #\(pullRequest.number) · \($0)" } ?? "PR #\(pullRequest.number)",
                kind: "pullRequest", url: pullRequest.url, state: pullRequest.status, owner: pullRequest.ownerLogin
            ))
            if let owner = pullRequest.ownerLogin, let ownerURL = pullRequest.ownerURL {
                links.append(AgentSessionWorkspaceLink(
                    id: "pr-owner-\(pullRequest.number)",
                    label: owner,
                    kind: "pullRequestOwner", url: ownerURL, state: nil, owner: owner
                ))
            }
        }
        for ticket in display?.ticketLinks ?? [] {
            links.append(AgentSessionWorkspaceLink(
                id: "ticket-\(ticket.id)",
                label: ticket.title.map { "\(ticket.id): \($0)" } ?? ticket.id,
                kind: "ticket", url: ticket.url, state: nil, owner: ticket.ownerName
            ))
            if let owner = ticket.ownerName, let ownerURL = ticket.ownerURL {
                links.append(AgentSessionWorkspaceLink(
                    id: "ticket-owner-\(ticket.id)",
                    label: owner,
                    kind: "ticketOwner", url: ownerURL, state: nil, owner: owner
                ))
            }
        }
        for project in display?.projectLinks ?? [] {
            links.append(AgentSessionWorkspaceLink(
                id: "project-\(project.id)", label: project.title ?? project.id,
                kind: "project", url: project.url, state: nil, owner: nil
            ))
        }
        return AgentSessionWorkspaceChrome(
            title: workspace.owningTabManager?.resolvedWorkspaceDisplayTitle(for: workspace) ?? workspace.title,
            repository: repository.isEmpty ? nil : repository,
            colorHex: workspace.customColor,
            status: workspace.progress?.label,
            // Header activity is a concise source-backed state summary. The
            // submitted prompt remains conversation data and must not be
            // duplicated as a second link-bearing activity line.
            activity: display?.currentWorkSummary ?? workspace.progress?.label,
            links: links
        )
    }
}
