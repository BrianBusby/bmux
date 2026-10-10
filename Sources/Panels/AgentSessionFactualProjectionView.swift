import AppKit
import SwiftUI
import ProvenanceEngineContracts

private extension Color {
    static let bmuxSurface = Color(red: 0.137, green: 0.141, blue: 0.157)
    static let bmuxRail = Color(red: 0.098, green: 0.102, blue: 0.114)
    static let bmuxCard = Color(red: 0.122, green: 0.125, blue: 0.137)
    static let bmuxCardBorder = Color(red: 0.220, green: 0.224, blue: 0.247)
    static let bmuxCardSelected = Color(red: 0.137, green: 0.180, blue: 0.133)
    static let bmuxCardSelectedBorder = Color(red: 0.227, green: 0.306, blue: 0.220)
    static let bmuxSeparator = Color(red: 0.204, green: 0.212, blue: 0.239)
    static let bmuxSeparatorSubtle = Color(red: 0.247, green: 0.255, blue: 0.286)
    static let bmuxTextPrimary = Color(red: 0.949, green: 0.953, blue: 0.969)
    static let bmuxTextSecondary = Color(red: 0.737, green: 0.753, blue: 0.792)
    static let bmuxTextTertiary = Color(red: 0.635, green: 0.651, blue: 0.698)
    static let bmuxTextMuted = Color(red: 0.522, green: 0.541, blue: 0.596)
    static let bmuxTextDisabled = Color(red: 0.455, green: 0.475, blue: 0.529)
    static let bmuxAccentGreen = Color(red: 0.416, green: 0.620, blue: 0.369)
    static let bmuxAccentYellow = Color(red: 0.620, green: 0.620, blue: 0.416)
    static let bmuxTurnAccent = Color(red: 0.290, green: 0.400, blue: 0.259)
    static let bmuxTabUnderline = Color(red: 0.878, green: 0.878, blue: 0.878)
}

private enum BmuxRadius {
    static let appShell: CGFloat = 12
}

struct AgentSessionFactualProjectionView: View {
    let result: AgentSessionFactualProjectionReadResult
    let isLoading: Bool
    let backgroundColor: Color
    let onRefresh: () -> Void
    var showsAppShell = false
    var fixturePreviewEnabled = false
    var liveChatContent: ((@escaping () -> Void) -> AnyView)?
    var liveTerminalContent: AnyView?
    var onPrimaryTabChange: ((Bool) -> Void)?
    var initialPrimaryTab: AgentSessionFactualProjectionMode = .session
    var stableWorkspaceID: UUID?
    var workspaceLabel: String?
    var sessionTitle: String?
    var sessionDescription: String?

    @State private var selectedPrimaryTabs: [UUID?: AgentSessionFactualProjectionMode] = [:]

    private var selectedPrimaryTab: AgentSessionFactualProjectionMode {
        get { selectedPrimaryTabs[stableWorkspaceID] ?? initialPrimaryTab }
        nonmutating set { selectedPrimaryTabs[stableWorkspaceID] = newValue }
    }

    var body: some View {
        if showsAppShell && fixturePreviewEnabled {
            referenceShell
        } else {
            contentPane
        }
    }

    private var referenceShell: some View {
        ZStack {
            Color.bmuxSurface.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        Text("bmux").font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(Color.bmuxTextPrimary)
                        Text("✳").font(.system(size: 18)).foregroundStyle(Color.bmuxTurnAccent)
                        Text("CompanyCam").foregroundStyle(Color.bmuxTextTertiary)
                    }
                    Spacer()
                    Text("Design concept · illustrative data")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.bmuxTextDisabled)
                }
                .padding(.horizontal, 24)
                .frame(height: 44)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.bmuxSeparator).frame(height: 1) }

                HStack(spacing: 0) {
                    workspaceRail
                    contentPane
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: BmuxRadius.appShell))
            .overlay(RoundedRectangle(cornerRadius: BmuxRadius.appShell).stroke(Color.bmuxSeparator, lineWidth: 1))
            .padding(18)
        }
    }

    private var workspaceRail: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("WORKSPACES").font(.system(size: 11, weight: .medium)).tracking(1.2).foregroundStyle(Color.bmuxTextMuted)
                Spacer()
                Text("3").foregroundStyle(Color.bmuxTextDisabled)
            }
            ScrollView {
                VStack(spacing: 8) {
                    workspaceCard(repo: "companycam-mobile", title: "One-off checklist flow", status: "Waiting for review", selected: true, links: ["INP-2228 · Build local draft checkbox row and retry-safe save", "PR #11279 · Update one-off checklist mobile flow · Open", "2.0: One off Advanced checklists creation (needed for Assistant + Walkthrough)"])
                    workspaceCard(repo: "companycam-mobile", title: "Reorder checklist fields", status: "Working · related to this session", selected: false, links: ["INP-2341 · Reorder one-off checklist fields with a single-field move", "INP-2228 · Build local draft checkbox row and retry-safe save", "PR #11279 · Update one-off checklist mobile flow · Open", "2.0: One off Advanced checklists creation (needed for Assistant + Walkthrough)"])
                    workspaceCard(repo: "Company-Cam-API", title: "Rename & duplicate checklists", status: "Merged", selected: false, links: ["INP-2331 · Let the assistant rename a whole checklist", "INP-2332 · Let the assistant duplicate a whole checklist"])
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(width: 340)
        .background(Color.bmuxRail)
        .overlay(alignment: .trailing) { Rectangle().fill(Color.bmuxSeparator).frame(width: 1) }
    }

    private func workspaceCard(repo: String, title: String, status: String, selected: Bool, links: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(repo).font(.system(size: 11)).foregroundStyle(Color.bmuxTextTertiary)
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.bmuxTextPrimary)
            Label(status, systemImage: status == "Merged" ? "checkmark" : "clock")
                .font(.system(size: 12)).foregroundStyle(status == "Merged" ? Color.bmuxAccentGreen : Color.bmuxAccentYellow)
            Divider().overlay(Color.bmuxSeparatorSubtle)
            ForEach(links, id: \.self) { link in
                Label(link, systemImage: link.hasPrefix("PR") ? "arrow.triangle.pull" : link.contains("2.0:") ? "folder" : "ticket")
                    .font(.system(size: 11.5)).foregroundStyle(Color.bmuxTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("PR owner · BrianBusby").font(.system(size: 11)).foregroundStyle(Color.bmuxTextTertiary)
        }
        .padding(12)
        .background(selected ? Color.bmuxCardSelected : Color.bmuxCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Color.bmuxCardSelectedBorder : Color.bmuxCardBorder, lineWidth: 1))
    }

    private var contentPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(workspaceLabel ?? String(localized: "agentSession.factual.workspaceUnavailable", defaultValue: "Workspace unavailable"))
                .font(.system(size: 12)).foregroundStyle(Color.bmuxTextTertiary)
            Text(sessionTitle ?? String(localized: "agentSession.factual.sessionUnavailable", defaultValue: "Session unavailable"))
                .font(.system(size: 26, weight: .bold)).foregroundStyle(Color.bmuxTextPrimary).padding(.top, 4)
            if let sessionDescription, !sessionDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(sessionDescription)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.bmuxTextTertiary)
                    .padding(.top, 4)
            }
            primaryTabs.padding(.top, 16)
            switch selectedPrimaryTab {
            case .session:
                sessionContent
            case .chat:
                chatContentView
            case .terminal:
                terminalContentView
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bmuxSurface)
        .foregroundStyle(Color.bmuxTextPrimary)
        .onChange(of: selectedPrimaryTab, initial: true) { _, tab in
            onPrimaryTabChange?(tab == .terminal)
        }
    }

    private var primaryTabs: some View {
        HStack(spacing: 24) {
            ForEach(AgentSessionFactualProjectionMode.allCases) { mode in
                Button(mode.title) {
                    selectedPrimaryTab = mode
                }
                    .buttonStyle(.plain)
                    .font(.system(size: 13.5, weight: selectedPrimaryTab == mode ? .medium : .regular))
                    .foregroundStyle(selectedPrimaryTab == mode ? Color.bmuxTextPrimary : Color.bmuxTextTertiary)
                    .padding(.bottom, 10)
                    .overlay(alignment: .bottom) { if selectedPrimaryTab == mode { Rectangle().fill(Color.bmuxTabUnderline).frame(height: 2) } }
            }
            Spacer()
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.bmuxSeparatorSubtle).frame(height: 1) }
    }

    private var sessionContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content.padding(.top, 20)
            }
        }
    }

    private var terminalContentView: some View {
        Group {
            if selectedPrimaryTab == .terminal,
               let liveTerminalContent {
                liveTerminalContent
                    .id("bmux-shell-terminal")
            } else {
                Color.clear
            }
        }
    }

    private var chatContentView: some View {
        Group {
            if let liveChatContent {
                liveChatContent {
                    selectedPrimaryTab = .terminal
                }
                .id("bmux-shell-chat")
            } else {
                emptyMessage(String(
                    localized: "agentSession.chat.chatUnavailable",
                    defaultValue: "Conversation unavailable"
                ))
            }
        }
    }

    private var nativeContent: some View {
        return VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "agentSession.factual.nativeUnavailable.title", defaultValue: "Provider-native session unavailable"))
                .font(.system(size: 18, weight: .bold))
            Text(String(localized: "agentSession.factual.nativeUnavailable.message", defaultValue: "This provider does not expose a native session surface in this build."))
                .foregroundStyle(Color.bmuxTextTertiary)
        }
        .padding(.top, 22)
    }

    @ViewBuilder
    private var content: some View {
        switch result {
        case .available(let snapshot):
            availableContent(snapshot)
        case .missingSession:
            emptyMessage(String(
                localized: "agentSession.factual.noSession",
                defaultValue: "No PE coding-agent session has been linked to this workspace yet."
            ))
        case .unavailable:
            emptyMessage(String(
                localized: "agentSession.factual.unavailable",
                defaultValue: "Provenance Engine is unavailable for this build."
            ))
        case .noSupportedCodingAgentDetected:
            emptyMessage(String(
                localized: "agentSession.factual.noSupportedAgent",
                defaultValue: "No supported coding agent has been detected in this workspace."
            ))
        case .agentDetectedAwaitingFirstPrompt:
            emptyMessage(String(
                localized: "agentSession.factual.awaitingFirstPrompt",
                defaultValue: "Coding agent detected. Waiting for the first prompt."
            ))
        case .promptObservedAssociationPending:
            emptyMessage(String(
                localized: "agentSession.factual.associationPending",
                defaultValue: "Prompt observed. Linking the coding-agent session."
            ))
        case .associationEstablishedProjectionPending:
            emptyMessage(String(
                localized: "agentSession.factual.projectionPending",
                defaultValue: "Session linked. Building factual session data."
            ))
        case .ingestionFailed:
            emptyMessage(String(
                localized: "agentSession.factual.ingestionFailed",
                defaultValue: "Session evidence ingestion failed."
            ))
        case .identityReconciliationFailed:
            emptyMessage(String(
                localized: "agentSession.factual.identityReconciliationFailed",
                defaultValue: "Could not reconcile the coding-agent session identity."
            ))
        case .projectionFailed:
            emptyMessage(String(
                localized: "agentSession.factual.projectionFailed",
                defaultValue: "Could not read factual session data."
            ))
        case .unsupportedOrUnassociatedSession:
            emptyMessage(String(
                localized: "agentSession.factual.unsupportedOrUnassociated",
                defaultValue: "This workspace does not have an associated supported coding-agent session."
            ))
        case .notFound:
            emptyMessage(String(
                localized: "agentSession.factual.notFound",
                defaultValue: "No factual session projection was found for the linked PE session."
            ))
        case .failed:
            emptyMessage(String(
                localized: "agentSession.factual.failed",
                defaultValue: "Could not read factual session data."
            ))
        }
    }

    private func availableContent(_ snapshot: ProvenanceFactualSessionProjectionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let turn = snapshot.latestTurn {
                AgentSessionCurrentTurnOverview(turn: turn)
                overviewDisclosure(
                    title: String(localized: "agentSession.factual.plan", defaultValue: "Plan & progress"),
                    detail: turn.currentPlan.map { planSummary($0) } ?? String(localized: "agentSession.factual.noPlan", defaultValue: "No plan data observed."),
                    isAvailable: turn.currentPlan != nil
                ) {
                    if let plan = turn.currentPlan {
                        planRows(plan)
                    }
                }
                overviewDisclosure(
                    title: String(localized: "agentSession.factual.checksAndChanges", defaultValue: "Checks & changes"),
                    detail: checksAndChangesSummary(turn),
                    isAvailable: !turn.completedCommands.isEmpty || !turn.fileChangeAttributions.isEmpty
                ) {
                    AgentSessionFactualProjectionTurnDetailView(turnSnapshot: turn, showsIdentity: false)
                }
                if !turn.visibleReasoningSummaries.isEmpty {
                    overviewDisclosure(
                        title: String(localized: "agentSession.factual.blockersAndApproach", defaultValue: "Blockers & approach changes"),
                        detail: String.localizedStringWithFormat(
                            String(localized: "agentSession.factual.reasoningCount", defaultValue: "%d change(s)"),
                            turn.visibleReasoningSummaries.count
                        ),
                        isAvailable: true
                    ) {
                        reasoningRows(turn.visibleReasoningSummaries)
                    }
                }
            } else {
                mutedText(String(localized: "agentSession.factual.noTurns", defaultValue: "No turns observed."))
            }

            section(String(localized: "agentSession.factual.priorTurns", defaultValue: "Previous turns")) {
                ExpandedTurnHistoryView(items: AgentSessionFactualProjectionEvidenceRows.priorTurnItems(for: snapshot))
                    .id(snapshot.session.id)
            }

            DisclosureGroup(String(localized: "agentSession.factual.identity", defaultValue: "Session details")) {
                VStack(alignment: .leading, spacing: 8) {
                    factRow(String(localized: "agentSession.factual.sessionID", defaultValue: "Session ID"), snapshot.session.id)
                    factRow(String(localized: "agentSession.factual.provider", defaultValue: "Provider"), snapshot.session.agentKind)
                    factRow(String(localized: "agentSession.factual.status", defaultValue: "Status"), snapshot.session.status)
                    factRow(String(localized: "agentSession.factual.cwd", defaultValue: "Directory"), snapshot.session.cwd)
                    factRow(String(localized: "agentSession.factual.revision", defaultValue: "Revision"), snapshot.revision.map(String.init))
                    if !snapshot.providerThreadIdentities.isEmpty {
                        ForEach(snapshot.providerThreadIdentities, id: \.threadID) { thread in
                            threadRow(thread)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.bmuxTextSecondary)
        }
    }

    private func overviewDisclosure<Content: View>(title: String, detail: String, isAvailable: Bool, @ViewBuilder content: () -> Content) -> some View {
        let contentView = content()
        return DisclosureGroup {
            if isAvailable {
                contentView.padding(.top, 8)
            } else {
                mutedText(detail).padding(.top, 8)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: title == String(localized: "agentSession.factual.plan", defaultValue: "Plan & progress") ? "checklist" : "checkmark.circle")
                    .foregroundStyle(Color.bmuxTextSecondary)
                Text(title).foregroundStyle(Color.bmuxTextPrimary)
                Spacer()
                Text(detail).foregroundStyle(Color.bmuxTextTertiary)
            }
            .font(.system(size: 13.5))
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.bmuxSeparatorSubtle).frame(height: 1) }
    }

    private func planSummary(_ plan: ProvenanceCodingAgentPlanUpdateRecord) -> String {
        let completed = plan.steps.filter { $0.status.lowercased().contains("complete") }.count
        return String.localizedStringWithFormat(
            String(localized: "agentSession.factual.planProgress", defaultValue: "%d of %d steps complete"),
            completed,
            plan.steps.count
        )
    }

    private func checksAndChangesSummary(_ turn: ProvenanceFactualSessionProjectionTurnSnapshot) -> String {
        String.localizedStringWithFormat(
            String(localized: "agentSession.factual.checksSummary", defaultValue: "%d commands · %d files"),
            turn.completedCommands.count,
            turn.fileChangeAttributions.count
        )
    }

    private func planRows(_ plan: ProvenanceCodingAgentPlanUpdateRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(plan.steps.prefix(8), id: \.id) { step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: step.status.lowercased().contains("complete") ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(step.status.lowercased().contains("complete") ? Color.bmuxAccentGreen : Color.bmuxTextTertiary)
                    Text(step.text)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.bmuxTextSecondary)
                        .lineLimit(2)
                }
            }
        }
    }

    private func reasoningRows(_ summaries: [ProvenanceCodingAgentReasoningSummaryRecord]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(summaries, id: \.id) { summary in
                Text(summary.text)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bmuxTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
            Divider()
        }
    }

    private func threadRow(_ thread: ProvenanceFactualSessionProjectionProviderThreadIdentity) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            factRow(String(localized: "agentSession.factual.providerThreadID", defaultValue: "Provider thread ID"), thread.providerThreadID)
            factRow(String(localized: "agentSession.factual.peThreadID", defaultValue: "PE thread ID"), thread.threadID)
            HStack(spacing: 8) {
                badge(thread.provider)
                badge(thread.confidence.rawValue)
                if let worktreeID = thread.worktreeID {
                    badge(worktreeID)
                }
            }
        }
    }

    private func factRow(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)
            Text(nonEmpty(value))
                .font(.system(size: 12))
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }

    private func badge(_ text: String) -> some View {
        Text(nonEmpty(text))
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.12), in: Capsule())
    }

    private func mutedText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
    }

    private func emptyMessage(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.top, 48)
    }

    private func nonEmpty(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return String(localized: "agentSession.factual.unknown", defaultValue: "Unknown")
    }
}
