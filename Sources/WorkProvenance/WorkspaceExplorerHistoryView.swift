import AppKit
import ProvenanceEngineContracts
import SwiftUI

/// Read-only retained sessions for one logical workspace.
struct WorkspaceExplorerHistoryView: View {
    let item: WorkspaceExplorerHistoryItem
    let repositoryNamesByID: [String: String]
    let page: ProvenanceWorkspaceSessionPageResponse?
    let period: WorkspaceExplorerScope.Period
    let now: Date
    let loadFailed: Bool
    let evidenceBySessionID: [String: WorkspaceExplorerSessionEvidence]
    let evidenceLoadingIDs: Set<String>
    let evidenceFailedIDs: Set<String>
    let onOpenLive: () -> Void
    let onReopen: () -> Void
    let onLoadEvidence: (String) -> Void
    let onLoadMore: () -> Void
    @State private var showsAllSessions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(item.colorHex.flatMap(NSColor.init(hex:)).map(Color.init(nsColor:)) ?? .accentColor)
                    .frame(width: 4, height: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.system(size: 18, weight: .bold))
                    if let last = item.lastActivityAt {
                        Text(String(localized: "explorer.lastActive", defaultValue: "Last active") + " " +
                            last.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }
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
                } else {
                    Button(String(localized: "explorer.reopenUnavailable", defaultValue: "Reopen unavailable")) {}
                        .disabled(true)
                        .help(reopenReason)
                }
            }
            .font(.system(size: 12))
            if let closed = item.closedAt {
                Text(String(localized: "explorer.closedAt", defaultValue: "Closed at") + " " +
                    closed.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if let recorded = item.lastRecordedStatus {
                Text(String(format: String(localized: "explorer.lastRecordedStatus",
                    defaultValue: "Last recorded: %@"),
                    WorkspaceExplorerGroupKey.bmuxStatus(recorded).displayName(projectsByID: [:])))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if let display = item.archive?.displayAtClose ?? item.display {
                HStack(spacing: 8) {
                    Text(display.repositoryID.map { repositoryNamesByID[$0] ?? $0 } ??
                        String(localized: "explorer.unknownRepository", defaultValue: "Unknown repository"))
                    if let branch = display.branch { Text(branch).help(branch) }
                    if let ticket = display.ticketIDs.first { Text(ticket) }
                    if let number = display.pullRequestNumber { Text("#\(number)") }
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary).lineLimit(1)
            }
            if item.archive != nil {
                Text(String(localized: "explorer.lastKnownMetadata", defaultValue:
                    "Last-known values recorded at close, not re-fetched."))
                    .font(.system(size: 11)).italic().foregroundStyle(.secondary)
            }
            if item.archive?.coverageCode == "close_snapshot_recovery" {
                Text(String(localized: "explorer.recoveredCloseSnapshot", defaultValue:
                    "Recovered from a saved close snapshot. Creation time and project details may be unavailable."))
                    .font(.system(size: 11)).italic().foregroundStyle(.secondary)
            }
            Text(page == nil ? String(localized: "explorer.readOnlyNotice", defaultValue:
                "Read-only. No terminal connection, approvals, or prompts. Session count is separate from the workspace count.") :
                String(format: String(localized: "explorer.readOnlySessionNotice", defaultValue:
                    "Read-only. No terminal connection, approvals, or prompts. Showing %d sessions with activity %@; session count is separate from the workspace count."),
                    visibleSessions.count, periodDescription))
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            if let page {
                Button(showsAllSessions ? String(localized: "explorer.selectedPeriod", defaultValue: "Selected period") :
                    String(format: page.nextCursor == nil ?
                        String(localized: "explorer.showAllSessionsCount", defaultValue: "Show all retained sessions (%d)") :
                        String(localized: "explorer.showLoadedSessionsCount", defaultValue: "Show all loaded sessions (%d)"),
                        page.sessions.count)) {
                    showsAllSessions.toggle()
                }
                ForEach(visibleSessions) { summary in sessionCard(summary) }
                if page.nextCursor != nil {
                    Button(String(localized: "explorer.loadMoreSessions", defaultValue: "Load more retained sessions"),
                        action: onLoadMore)
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

    private var reopenReason: String {
        if case .unavailable(let reason) = item.reopenEligibility {
            return reason.localizedDescription
        }
        return ""
    }

    private var periodDescription: String {
        switch period {
        case .anyTime: String(localized: "explorer.anyTime", defaultValue: "Any time")
        case .last24Hours: String(localized: "explorer.last24Hours", defaultValue: "Last 24 hours")
        case .today: String(localized: "explorer.today", defaultValue: "Today")
        case .last7Days: String(localized: "explorer.last7Days", defaultValue: "Last 7 days")
        }
    }

    private var periodStart: Date? {
        switch period {
        case .anyTime: nil
        case .last24Hours: now.addingTimeInterval(-24 * 60 * 60)
        case .today: Calendar.current.startOfDay(for: now)
        case .last7Days: now.addingTimeInterval(-7 * 24 * 60 * 60)
        }
    }

    private func isInPeriod(_ summary: ProvenanceWorkspaceSessionSummary) -> Bool {
        guard let activity = summary.lastActivityAt else { return period == .anyTime }
        let sample = WorkspaceExplorerWorkspace(id: item.id, title: item.title,
            projectIDs: [], repository: nil, tickets: [], ticketStatus: nil,
            pullRequestOwner: nil, pullRequestStatus: nil, hasPullRequest: false,
            lastActivityAt: activity, isClosed: !item.isOpen,
            liveStatus: .disconnected, arrangedStatus: .disconnected)
        return WorkspaceExplorerScope(state: .all, period: period)
            .includes(sample, now: now, calendar: .current)
    }

    private func sessionCard(_ summary: ProvenanceWorkspaceSessionSummary) -> some View {
        let evidence = evidenceBySessionID[summary.id]
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(summary.id).font(.system(size: 12, design: .monospaced)).lineLimit(1)
                Spacer()
                Text(summary.session.status).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Text(summary.session.agentKind).font(.system(size: 11)).foregroundStyle(.secondary)
            if !isInPeriod(summary) {
                Text(String(localized: "explorer.outsidePeriod", defaultValue: "OUTSIDE SELECTED PERIOD"))
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
            } else if let start = summary.session.startedAt,
                      let periodStart, start < periodStart {
                Text(String(localized: "explorer.startedBeforePeriod", defaultValue:
                    "STARTED BEFORE THIS PERIOD"))
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                if let start = summary.session.startedAt {
                    Text(start, format: .dateTime.month().day().hour().minute())
                }
                if let activity = summary.lastActivityAt {
                    Text("→")
                    Text(String(localized: "explorer.lastActivity", defaultValue: "Last activity"))
                    Text(activity, format: .dateTime.month().day().hour().minute())
                }
            }.font(.system(size: 11)).foregroundStyle(.secondary)
            if let evidence {
                if let outcome = evidence.outcome.outcome {
                    Text(outcome.completionState).font(.system(size: 12, weight: .semibold))
                    ForEach(outcome.objectives.prefix(3), id: \.id) { objective in
                        Text(objective.text).font(.system(size: 12))
                    }
                    if !outcome.changedArtifacts.isEmpty {
                        Text(String(localized: "explorer.artifacts", defaultValue: "Artifacts"))
                            .font(.system(size: 11, weight: .semibold))
                        ForEach(outcome.changedArtifacts.prefix(8), id: \.id) { artifact in
                            Text(artifact.artifact.path).font(.system(size: 11, design: .monospaced))
                                .lineLimit(1).help(artifact.artifact.path)
                        }
                    }
                }
                if let snapshot = evidence.projection.snapshot {
                    ForEach(snapshot.turns, id: \.turn.id) { turn in
                        VStack(alignment: .leading, spacing: 3) {
                            if let prompt = turn.submittedPrompt {
                                Text(prompt.text).font(.system(size: 12)).lineLimit(3)
                                Text(prompt.submittedAt, format: .dateTime.month().day().hour().minute())
                                    .font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            ForEach(turn.assistantMessages.prefix(2), id: \.id) { message in
                                Text(message.text).font(.system(size: 12)).lineLimit(4)
                                Text(message.completedAt, format: .dateTime.month().day().hour().minute())
                                    .font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.leading, 8)
                        .overlay(alignment: .leading) { Rectangle().fill(Color.accentColor).frame(width: 2) }
                    }
                }
                Text(String(localized: "explorer.coverageTranscript", defaultValue:
                    "Captured evidence only — terminal scrollback may not be retained."))
                    .font(.system(size: 11)).italic().foregroundStyle(.secondary)
            } else if evidenceLoadingIDs.contains(summary.id) {
                ProgressView().controlSize(.small)
            } else if evidenceFailedIDs.contains(summary.id) {
                Button(String(localized: "explorer.retry", defaultValue: "Retry")) { onLoadEvidence(summary.id) }
            } else {
                Button(String(localized: "explorer.viewSessionDetail", defaultValue: "View session detail")) {
                    onLoadEvidence(summary.id)
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .opacity(isInPeriod(summary) ? 1 : 0.6)
    }

    private var visibleSessions: [ProvenanceWorkspaceSessionSummary] {
        guard let page else { return [] }
        guard !showsAllSessions && period != .anyTime else { return page.sessions }
        return page.sessions.filter(isInPeriod)
    }
}
