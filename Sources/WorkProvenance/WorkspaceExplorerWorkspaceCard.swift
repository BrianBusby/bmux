import AppKit
import SwiftUI

/// Immutable workspace card facts and actions; no observable store crosses the grid boundary.
struct WorkspaceExplorerWorkspaceCard: View {
    let item: WorkspaceExplorerHistoryItem
    let onOpen: () -> Void
    let onHistory: () -> Void
    let onReopen: () -> Void
    let onFilter: (WorkspaceExplorerDimension, WorkspaceExplorerGroupKey) -> Void

    private var reopenReason: String {
        if case .unavailable(let reason) = item.reopenEligibility {
            return reason.localizedDescription
        }
        return ""
    }

    private var statusLabel: String {
        item.isOpen ? WorkspaceExplorerGroupKey.bmuxStatus(item.liveStatus)
            .displayName(projectsByID: [:]) :
            String(localized: "explorer.closed", defaultValue: "Closed")
    }

    private var statusColor: Color {
        guard item.isOpen else { return .secondary }
        switch item.liveStatus {
        case .error: .red
        case .needsInput: .orange
        case .running: .green
        case .idle, .disconnected, .closedHistorical: .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text(item.title).font(.system(size: 14, weight: .bold)).lineLimit(2)
                        Spacer(minLength: 4)
                        Text(item.isOpen ? String(localized: "explorer.open", defaultValue: "Open") :
                            String(localized: "explorer.closed", defaultValue: "Closed"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    if let branch = item.display?.branch {
                        Text(branch).font(.system(size: 11, design: .monospaced))
                            .lineLimit(1).truncationMode(.middle).help(branch)
                    }
                    HStack(spacing: 5) {
                        Image(systemName: item.liveStatus == .disconnected ? "circle" : "circle.fill")
                            .font(.system(size: 7))
                        Text(statusLabel)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(statusColor)
                    if let activity = item.lastActivityAt {
                        Text(activity, style: .relative).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack(spacing: 6) {
                if let ticket = item.display?.ticketIDs.first {
                    Button(ticket) { onFilter(.ticket, .value(ticket)) }
                        .font(.system(size: 11, design: .monospaced))
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                } else {
                    Text(String(localized: "explorer.noTicket", defaultValue: "No ticket"))
                        .italic().font(.system(size: 11)).foregroundStyle(.secondary)
                }
                if let repository = item.display?.repositoryID {
                    Button(repository) { onFilter(.repository, .value(repository)) }
                        .font(.system(size: 11, design: .monospaced))
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .lineLimit(1)
                }
            }
            if let number = item.display?.pullRequestNumber {
                HStack(spacing: 4) {
                    Text("#\(number)").font(.system(size: 11, design: .monospaced))
                    if let owner = item.display?.pullRequestOwnerLogin {
                        Button(owner) { onFilter(.pullRequestOwner, .value(owner)) }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                    }
                    if let status = item.display?.pullRequestStatus {
                        Text("· " + status)
                    }
                }
                .font(.system(size: 11)).lineLimit(1)
            }
            if item.isOpen {
                if item.archive != nil {
                    Button(String(localized: "explorer.historyShort", defaultValue: "History"), action: onHistory)
                        .buttonStyle(.bordered).controlSize(.small)
                }
            } else if case .eligible = item.reopenEligibility {
                Button(String(localized: "explorer.reopenShort", defaultValue: "Reopen"), action: onReopen)
                    .buttonStyle(.bordered).controlSize(.small)
            } else {
                Text(String(localized: "explorer.reopenUnavailable", defaultValue: "Reopen unavailable"))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .help(reopenReason)
            }
        }
        .padding(.leading, 16).padding(.trailing, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(item.colorHex.flatMap(NSColor.init(hex:)).map(Color.init(nsColor:)) ?? .accentColor)
                .frame(width: 4).padding(.leading, 4).padding(.vertical, 9)
        }
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Color(nsColor: .separatorColor),
                style: StrokeStyle(lineWidth: 1, dash: item.isOpen ? [] : [5, 3])))
    }
}
