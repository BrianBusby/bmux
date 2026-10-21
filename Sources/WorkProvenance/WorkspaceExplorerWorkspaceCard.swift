import AppKit
import SwiftUI

/// Immutable workspace card facts and actions; no observable store crosses the grid boundary.
struct WorkspaceExplorerWorkspaceCard: View {
    let item: WorkspaceExplorerHistoryItem
    let isActive: Bool
    let isReopened: Bool
    let metadataPending: Bool
    let onOpen: () -> Void
    let onHistory: () -> Void
    let onReopen: () -> Void
    let onFilter: (WorkspaceExplorerDimension, WorkspaceExplorerGroupKey) -> Void
    @State private var isHovered = false
    @FocusState private var hasKeyboardFocus: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

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

    private var statusBackground: Color {
        guard item.isOpen else { return Color(nsColor: .controlColor) }
        return switch item.liveStatus {
        case .error: Color.red.opacity(0.14)
        case .needsInput: Color.orange.opacity(0.18)
        case .running: Color.green.opacity(0.14)
        case .idle, .disconnected, .closedHistorical: Color(nsColor: .controlColor)
        }
    }

    private var statusColor: Color {
        guard item.isOpen else { return Color.secondary }
        return switch item.liveStatus {
        case .error: Color.red
        case .needsInput: Color.orange
        case .running: Color.green
        case .idle, .disconnected, .closedHistorical: Color.secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text(item.title).font(.system(size: 14, weight: .bold)).lineLimit(2)
                        Spacer(minLength: 4)
                        if isReopened {
                            Text(String(localized: "explorer.reopenedTag", defaultValue: "REOPENED ✓"))
                                .font(.system(size: 10, weight: .bold)).foregroundStyle(.primary)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.green.opacity(0.18), in: Capsule())
                        } else if isActive && item.isOpen {
                            Text(String(localized: "explorer.activeTag", defaultValue: "ACTIVE"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                        } else if !item.isOpen {
                            Text(String(localized: "explorer.closedTag", defaultValue: "CLOSED"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let branch = item.display?.branch {
                        Text(branch).font(.system(size: 11, design: .monospaced))
                            .lineLimit(1).truncationMode(.middle).help(branch)
                    }
                    HStack(spacing: 5) {
                        Image(systemName: item.liveStatus == .disconnected ? "circle" : "circle.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(statusColor)
                        Text(statusLabel)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(statusBackground, in: Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($hasKeyboardFocus)
            if metadataPending {
                Text(String(localized: "explorer.workspaceDetailsLoading", defaultValue:
                    "Workspace details loading…"))
                    .font(.system(size: 11)).italic().foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    let tickets = item.display?.ticketIDs ?? []
                    if tickets.count == 1, let ticket = tickets.first {
                        Button(ticket) { onFilter(.ticket, .value(ticket)) }
                            .font(.system(size: 11, design: .monospaced))
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                    } else {
                        Text(tickets.isEmpty ? String(localized: "explorer.noTicket", defaultValue: "No ticket") :
                            String(localized: "explorer.multipleTickets", defaultValue: "Multiple tickets"))
                            .italic().font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    if let repository = item.display?.repositoryID {
                        Button(repository) { onFilter(.repository, .value(repository)) }
                            .font(.system(size: 11, design: .monospaced))
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .lineLimit(1)
                    } else {
                        Text(String(localized: "explorer.unknownRepository", defaultValue: "Unknown repository"))
                            .italic().font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                if let number = item.display?.pullRequestNumber {
                    HStack(spacing: 4) {
                        Text("#\(number)").font(.system(size: 11, design: .monospaced))
                        if let owner = item.display?.pullRequestOwnerLogin {
                            Button(owner) { onFilter(.pullRequestOwner, .value(owner)) }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                        } else {
                            Text(String(localized: "explorer.unknownPROwner", defaultValue: "Unknown PR owner"))
                                .italic().foregroundStyle(.secondary)
                        }
                        if let status = item.display?.pullRequestStatus {
                            Text("· " + status)
                        }
                    }
                    .font(.system(size: 11)).lineLimit(1)
                } else {
                    Text(String(localized: "explorer.noPR", defaultValue: "No PR"))
                        .font(.system(size: 11)).italic().foregroundStyle(.secondary)
                }
            }
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
            if let recorded = item.lastRecordedStatus, !item.isOpen {
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
            } else if isReopened {
                EmptyView()
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
        .background(isActive && item.isOpen ? Color.accentColor.opacity(0.1) :
            Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: onOpen)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(item.colorHex.flatMap(NSColor.init(hex:)).map(Color.init(nsColor:)) ?? .accentColor)
                .frame(width: 4).padding(.leading, 4).padding(.vertical, 9)
                .allowsHitTesting(false)
        }
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(isActive && item.isOpen ? Color.accentColor :
                Color(nsColor: .separatorColor),
                style: StrokeStyle(lineWidth: isActive && item.isOpen ? 2 : 1,
                    dash: item.isOpen ? [] : [5, 3])))
            .allowsHitTesting(false)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(hasKeyboardFocus ? Color.accentColor : .clear, lineWidth: 2)
            .padding(-2).allowsHitTesting(false))
        .shadow(color: .black.opacity(colorScheme == .dark ? (isHovered ? 0.5 : 0.45) :
            (isHovered ? 0.15 : 0.07)), radius: isHovered ? 10 : 4, y: isHovered ? 4 : 2)
        .offset(y: isHovered && !reduceMotion ? -1 : 0)
        .onHover { isHovered = $0 }
    }
}
