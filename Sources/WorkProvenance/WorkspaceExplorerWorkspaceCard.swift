import AppKit
import SwiftUI

/// Presents Explorer actions inside the same workspace card used by the native tab rail.
struct WorkspaceExplorerWorkspaceCard: View {
    let item: WorkspaceExplorerHistoryItem
    let isActive: Bool
    let isReopened: Bool
    let metadataPending: Bool
    let hiddenDimensions: Set<WorkspaceExplorerDimension>
    let onOpen: () -> Void
    let onHistory: () -> Void
    let onReopen: () -> Void
    let onFilter: (WorkspaceExplorerDimension, WorkspaceExplorerGroupKey) -> Void
    let onInteractionChanged: (Bool) -> Void

    private var card: WorkspaceReferenceCardSnapshot {
        WorkspaceReferenceCardSnapshot(explorerItem: item, hiddenDimensions: hiddenDimensions)
    }

    private var statusLabel: String {
        item.isOpen ? WorkspaceExplorerGroupKey.bmuxStatus(item.liveStatus)
            .displayName(projectsByID: [:]) :
            String(localized: "explorer.closed", defaultValue: "Closed")
    }

    private var reopenReason: String {
        if case .unavailable(let reason) = item.reopenEligibility {
            return reason.localizedDescription
        }
        return ""
    }

    var body: some View {
        WorkspaceReferenceCardView(
            card: card,
            repositoryName: hiddenDimensions.contains(.repository) ? nil : item.display?.repositoryID,
            isSelected: isActive && item.isOpen,
            canCloseWorkspace: false,
            showsCloseControl: false,
            onSelect: onOpen,
            onClose: {},
            onOpenLink: { NSWorkspace.shared.open($0) },
            footer: footer,
            onInteractionChanged: onInteractionChanged
        )
        .contextMenu {
            if !hiddenDimensions.contains(.ticket),
               let ticket = item.display?.ticketIDs.first,
               item.display?.ticketIDs.count == 1 {
                Button(ticket) { onFilter(.ticket, .value(ticket)) }
            }
            if !hiddenDimensions.contains(.repository), let repository = item.display?.repositoryID {
                Button(repository) { onFilter(.repository, .value(repository)) }
            }
            if !hiddenDimensions.contains(.pullRequestOwner),
               let owner = item.display?.pullRequestOwnerLogin {
                Button(owner) { onFilter(.pullRequestOwner, .value(owner)) }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 7) {
            if metadataPending {
                Text(String(localized: "explorer.workspaceDetailsLoading", defaultValue:
                    "Workspace details loading…"))
                    .font(.system(size: 11)).italic().foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                if isReopened {
                    Text(String(localized: "explorer.reopenedTag", defaultValue: "REOPENED ✓"))
                        .foregroundStyle(.green)
                } else if isActive && item.isOpen {
                    Text(String(localized: "explorer.activeTag", defaultValue: "ACTIVE"))
                        .foregroundStyle(Color.accentColor)
                } else if !item.isOpen && !hiddenDimensions.contains(.workspaceState) &&
                            !hiddenDimensions.contains(.bmuxStatus) {
                    Text(String(localized: "explorer.closedTag", defaultValue: "CLOSED"))
                        .foregroundStyle(.secondary)
                }
                if !hiddenDimensions.contains(.bmuxStatus) &&
                    (item.isOpen || !hiddenDimensions.contains(.workspaceState)) {
                    Text(statusLabel).foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 10, weight: .semibold))
            HStack(spacing: 4) {
                if let last = item.lastActivityAt {
                    Text(String(localized: "explorer.lastActive", defaultValue: "Last active"))
                    Text(last, style: .relative)
                }
                if let closed = item.closedAt {
                    Text("·")
                    Text(String(localized: "explorer.closedAt", defaultValue: "Closed at"))
                    Text(closed, format: .dateTime.hour().minute())
                } else if let created = item.createdAt {
                    Text("·")
                    Text(String(localized: "explorer.created", defaultValue: "created"))
                    Text(created, style: .relative)
                }
            }
            .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            if let recorded = item.lastRecordedStatus, !item.isOpen,
               !hiddenDimensions.contains(.bmuxStatus) {
                Text(String(format: String(localized: "explorer.lastRecordedStatus",
                    defaultValue: "Last recorded: %@"),
                    WorkspaceExplorerGroupKey.bmuxStatus(recorded).displayName(projectsByID: [:])))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if item.isOpen {
                if item.archive != nil {
                    Button(String(localized: "explorer.historyShort", defaultValue: "History"), action: onHistory)
                        .buttonStyle(.bordered).controlSize(.small)
                }
            } else if !isReopened {
                if case .eligible = item.reopenEligibility {
                    Button(String(localized: "explorer.reopenShort", defaultValue: "Reopen"), action: onReopen)
                        .buttonStyle(.bordered).controlSize(.small)
                } else {
                    Text(String(localized: "explorer.reopenUnavailable", defaultValue: "Reopen unavailable"))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .help(reopenReason)
                }
            }
        }
    }
}
