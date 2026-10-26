import BmuxWorkBrief
import SwiftUI

/// Built-in briefing destination over bounded local and source-health snapshots.
public struct WorkBriefView: View {
    @State private var model: WorkBriefCoordinator
    private let previousBrief: WorkBriefBaseline?
    private let jump: @MainActor (UUID, UUID) -> Bool
    private let highlight: @MainActor (UUID, UUID, String) -> Bool
    private let openURL: @MainActor (URL) -> Void
    private let onStart: @MainActor (@escaping @MainActor () -> Void) -> Void
    private let onStop: @MainActor () -> Void

    /// Creates a brief with only the initial read and explicit navigation capabilities.
    /// - Parameters:
    ///   - model: The domain coordinator supplying bounded snapshots.
    ///   - jump: A host-validated workspace selection action.
    ///   - highlight: A host-validated surface highlight action.
    ///   - openURL: A source URL action invoked only on a user click.
    ///   - onStart: Begins source monitoring while the view is visible.
    ///   - onStop: Ends source monitoring when the view disappears.
    public init(model: WorkBriefCoordinator, previousBrief: WorkBriefBaseline? = nil,
                jump: @escaping @MainActor (UUID, UUID) -> Bool,
                highlight: @escaping @MainActor (UUID, UUID, String) -> Bool,
                openURL: @escaping @MainActor (URL) -> Void,
                onStart: @escaping @MainActor (@escaping @MainActor () -> Void) -> Void,
                onStop: @escaping @MainActor () -> Void) {
        _model = State(initialValue: model)
        self.previousBrief = previousBrief
        self.jump = jump
        self.highlight = highlight
        self.openURL = openURL
        self.onStart = onStart
        self.onStop = onStop
    }

    /// Renders source health, local work, and explicit unavailable sections.
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(String(localized: "workBrief.title", defaultValue: "Work Brief"))
                    .font(.largeTitle.bold())
                Spacer()
                Button(String(localized: "workBrief.refresh", defaultValue: "Refresh")) {
                    Task { await model.refresh() }
                }
                .disabled(model.isLoading)
            }
            .padding()
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let snapshot = model.snapshot {
                        sourceHealth(snapshot)
                        let projection = WorkBriefProjection(snapshot: snapshot)
                        section(String(localized: "workBrief.needsAttention", defaultValue: "Needs attention"),
                                local: projection.needsAttention, external: projection.externalNeedsAttention,
                                projection: projection, snapshot: snapshot,
                                empty: String(localized: "workBrief.noAttention", defaultValue:
                                    "No verified requests in the available source facts."))
                        section(String(localized: "workBrief.inProgress", defaultValue: "In progress"),
                                local: projection.inProgress, external: projection.externalInProgress,
                                projection: projection, snapshot: snapshot,
                                empty: String(localized: "workBrief.noInProgress", defaultValue:
                                    "No active work was found in the available source facts."))
                        section(String(localized: "workBrief.waitingOn", defaultValue: "Waiting on"),
                                local: projection.waitingOn, external: projection.externalWaitingOn,
                                projection: projection, snapshot: snapshot,
                                empty: String(localized: "workBrief.waitingUnavailable", defaultValue:
                                    "No verified waiting relationships are available yet."))
                        WorkBriefRecentChangesView(snapshot: snapshot, previousBrief: previousBrief,
                            jump: jump, highlight: highlight, openURL: openURL)
                        WorkBriefAskView(snapshot: snapshot, jump: jump, highlight: highlight,
                                         openURL: openURL)
                    } else if model.isLoading {
                        ProgressView(String(localized: "workBrief.loading", defaultValue: "Checking work…"))
                    } else {
                        Text(String(localized: "workBrief.unavailable", defaultValue: "Work Brief is unavailable. Try refreshing."))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 600, minHeight: 460)
        .onAppear {
            onStart { Task { await model.refresh(forceExternal: false) } }
            Task { await model.refresh() }
        }
        .onDisappear { onStop() }
    }

    private func sourceHealth(_ snapshot: WorkBriefSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "workBrief.sourceHealth", defaultValue: "Source health"))
                .font(.headline)
            Text(localHealthLabel(snapshot.localHealth))
            healthRow(WorkBriefSource.linear.displayName, health: snapshot.linearHealth)
            healthRow(WorkBriefSource.github.displayName, health: snapshot.githubHealth)
            Text(String(localized: "workBrief.slackNotConfigured", defaultValue:
                "Slack is not configured for this brief."))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func localHealthLabel(_ health: WorkBriefSourceHealth) -> String {
        return switch health.state {
        case .available: String(localized: "workBrief.localCurrent", defaultValue: "Local work checked")
        case .partial: String(localized: "workBrief.localPartial", defaultValue: "Local work is partial; some provenance facts may be missing")
        case .failed: String(localized: "workBrief.localFailed", defaultValue: "Local source refresh failed; showing available workspace presence")
        case .notConfigured: String(localized: "workBrief.localUnavailable", defaultValue: "Local source unavailable")
        }
    }

    private func healthRow(_ source: String, health: WorkBriefSourceHealth) -> some View {
        HStack(spacing: 4) {
            Text(source + " · " + healthLabel(health))
            if let checkedAt = health.checkedAt {
                Text(checkedAt, style: .relative)
            }
        }
    }

    private func healthLabel(_ health: WorkBriefSourceHealth) -> String {
        if health.reasonCode == "unauthorized" {
            return String(localized: "workBrief.sourceAuthenticationFailed", defaultValue:
                "Authentication failed; reconnect this source")
        }
        return switch health.state {
        case .available: String(localized: "workBrief.sourceAvailable", defaultValue: "Checked")
        case .partial: String(localized: "workBrief.sourcePartial", defaultValue: "Partial; some facts may be missing")
        case .failed: String(localized: "workBrief.sourceFailed", defaultValue: "Refresh failed; showing prior facts")
        case .notConfigured: String(localized: "workBrief.sourceNotConfigured", defaultValue: "Not configured")
        }
    }

    private func section(_ title: String, local: [WorkBriefLocalWorkspace],
                         external: [WorkBriefExternalItem], projection: WorkBriefProjection,
                         snapshot: WorkBriefSnapshot, empty: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title2.bold())
            if local.isEmpty && external.isEmpty { Text(empty).foregroundStyle(.secondary) }
            ForEach(local) { item in
                WorkBriefWorkspaceRow(item: item, jump: jump, highlight: highlight, openURL: openURL)
            }
            ForEach(external) { item in
                let ids = Set(projection.relatedWorkspaceIDs[item.id] ?? [])
                WorkBriefExternalRow(item: item,
                    relatedWorkspaces: snapshot.localWorkspaces.filter { ids.contains($0.id) },
                    relationshipEvidenceByWorkspaceID:
                        projection.relationshipEvidenceByExternalID[item.id] ?? [:],
                    health: item.source == .linear ? snapshot.linearHealth : snapshot.githubHealth,
                    hasConflict: projection.conflictingExternalIDs.contains(item.id),
                    jump: jump, openURL: openURL)
            }
        }
    }

}
