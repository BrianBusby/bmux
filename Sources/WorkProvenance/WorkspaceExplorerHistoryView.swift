import AppKit
import ProvenanceEngineContracts
import SwiftUI

/// Read-only retained sessions for one logical workspace.
struct WorkspaceExplorerHistoryView: View {
    let item: WorkspaceExplorerHistoryItem
    let page: ProvenanceWorkspaceSessionPageResponse?
    let period: WorkspaceExplorerScope.Period
    let loadFailed: Bool
    let onOpenLive: () -> Void
    let onReopen: () -> Void
    @State private var showsAllSessions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(item.title).font(.system(size: 18, weight: .bold))
            HStack {
                Text(item.isOpen ? String(localized: "explorer.open", defaultValue: "Open") :
                    String(localized: "explorer.closed", defaultValue: "Closed"))
                Spacer()
                if item.isOpen {
                    Button(String(localized: "explorer.openLive", defaultValue: "Open live workspace"),
                        action: onOpenLive)
                } else if case .eligible = item.reopenEligibility {
                    Button(String(localized: "explorer.reopen", defaultValue: "Reopen workspace"),
                        action: onReopen)
                }
            }
            .font(.system(size: 12))
            Text(String(localized: "explorer.readOnlyNotice", defaultValue:
                "Read-only. No terminal connection, approvals, or prompts. Session count is separate from the workspace count."))
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            if let page {
                Button(showsAllSessions ? String(localized: "explorer.selectedPeriod", defaultValue: "Selected period") :
                    String(localized: "explorer.showAllSessions", defaultValue: "Show all retained sessions")) {
                    showsAllSessions.toggle()
                }
                ForEach(visibleSessions) { summary in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(summary.id).font(.system(size: 12, design: .monospaced)).lineLimit(1)
                        Text(summary.session.agentKind + " · " + summary.session.status)
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        if let activity = summary.lastActivityAt {
                            Text(activity, style: .date).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 10))
                }
                if visibleSessions.isEmpty {
                    Text(String(localized: "explorer.noSessions", defaultValue:
                        "No retained sessions with activity in this period. Capture may be incomplete."))
                        .foregroundStyle(.secondary)
                }
                if page.partialCoverage {
                    Text(String(localized: "explorer.partialCoverage", defaultValue:
                        "Retained session coverage may be incomplete."))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            } else if loadFailed {
                Text(String(localized: "explorer.sessionsUnavailable", defaultValue:
                    "Retained sessions could not be loaded."))
                    .foregroundStyle(.secondary)
            } else {
                ProgressView(String(localized: "explorer.loadingSessions", defaultValue: "Loading retained sessions…"))
            }
        }
    }

    private var visibleSessions: [ProvenanceWorkspaceSessionSummary] {
        guard let page else { return [] }
        guard !showsAllSessions && period != .anyTime else { return page.sessions }
        return page.sessions.filter { summary in
            guard let activity = summary.lastActivityAt else { return false }
            let sample = WorkspaceExplorerWorkspace(id: item.id, title: item.title,
                projectIDs: [], repository: nil, tickets: [], ticketStatus: nil,
                pullRequestOwner: nil, pullRequestStatus: nil, hasPullRequest: false,
                lastActivityAt: activity, isClosed: !item.isOpen,
                liveStatus: .disconnected, arrangedStatus: .disconnected)
            return WorkspaceExplorerScope(state: .all, period: period)
                .includes(sample, now: .now, calendar: .current)
        }
    }
}
