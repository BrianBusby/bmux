import BmuxWorkBrief
import SwiftUI

/// Built-in briefing destination over bounded local and source-health snapshots.
public struct WorkBriefView: View {
    @State private var model: WorkBriefCoordinator
    private let jump: @MainActor (UUID, UUID) -> Bool
    private let highlight: @MainActor (UUID, UUID, String) -> Bool
    private let openURL: @MainActor (URL) -> Void
    private let onStart: @MainActor (@escaping @MainActor () -> Void) -> Void
    private let onStop: @MainActor () -> Void

    /// Creates a brief with only the initial read and explicit navigation capabilities.
    public init(model: WorkBriefCoordinator,
                jump: @escaping @MainActor (UUID, UUID) -> Bool,
                highlight: @escaping @MainActor (UUID, UUID, String) -> Bool,
                openURL: @escaping @MainActor (URL) -> Void,
                onStart: @escaping @MainActor (@escaping @MainActor () -> Void) -> Void,
                onStop: @escaping @MainActor () -> Void) {
        _model = State(initialValue: model)
        self.jump = jump
        self.highlight = highlight
        self.openURL = openURL
        self.onStart = onStart
        self.onStop = onStop
    }

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
                                items: projection.needsAttention,
                                empty: String(localized: "workBrief.noLocalAttention", defaultValue:
                                    "No verified local requests. External sources are not included yet."))
                        section(String(localized: "workBrief.inProgress", defaultValue: "In progress"),
                                items: projection.inProgress,
                                empty: String(localized: "workBrief.noOpenWorkspaces", defaultValue:
                                    "No open workspaces were found."))
                        unavailableSection(String(localized: "workBrief.waitingOn", defaultValue: "Waiting on"),
                            detail: String(localized: "workBrief.waitingUnavailable", defaultValue:
                                "External blockers have not been checked yet."))
                        unavailableSection(String(localized: "workBrief.recentChanges", defaultValue: "Recent changes"),
                            detail: String(localized: "workBrief.changesUnavailable", defaultValue:
                                "A previous brief is needed to show changes."))
                        unavailableSection(String(localized: "workBrief.ask", defaultValue: "Ask"),
                            detail: String(localized: "workBrief.askUnavailable", defaultValue:
                                "Follow-up questions are not available in this local brief yet."))
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
            onStart { Task { await model.refresh() } }
            Task { await model.refresh() }
        }
        .onDisappear { onStop() }
    }

    private func sourceHealth(_ snapshot: WorkBriefSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "workBrief.sourceHealth", defaultValue: "Source health"))
                .font(.headline)
            Text(localHealthLabel(snapshot.localHealth))
            Text(String(localized: "workBrief.externalPending", defaultValue:
                "Linear, GitHub, and Slack have not been checked for this brief."))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func localHealthLabel(_ health: WorkBriefSourceHealth) -> String {
        switch health.state {
        case .available: String(localized: "workBrief.localCurrent", defaultValue: "Local work checked")
        case .partial: String(localized: "workBrief.localPartial", defaultValue: "Local work is partial; some provenance facts may be missing")
        case .failed: String(localized: "workBrief.localFailed", defaultValue: "Local source refresh failed; showing available workspace presence")
        case .notConfigured: String(localized: "workBrief.localUnavailable", defaultValue: "Local source unavailable")
        }
    }

    private func section(_ title: String, items: [WorkBriefLocalWorkspace], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title2.bold())
            if items.isEmpty { Text(empty).foregroundStyle(.secondary) }
            ForEach(items) { item in
                WorkBriefWorkspaceRow(item: item, jump: jump, highlight: highlight, openURL: openURL)
            }
        }
    }

    private func unavailableSection(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.bold())
            Text(detail).foregroundStyle(.secondary)
        }
    }
}
