import AppKit
import SwiftUI
import ProvenanceEngineContracts

private let agentSessionFactualProjectionAutoRefreshNanoseconds: UInt64 = 2_000_000_000

enum AgentSessionFactualProjectionEvidenceRows {
    enum TurnProperty: Equatable {
        case prompt(String)
        case providerTurnID(String)
        case peTurnID(String)
        case peThreadID(String?)
        case status(String)
        case model(String?)
    }

    enum PriorTurnItem: Equatable {
        case detail(ProvenanceFactualSessionProjectionTurnSnapshot)
        case reference(ProvenanceFactualSessionProjectionTurnReference)

        var id: String {
            switch self {
            case .detail(let turnSnapshot):
                turnSnapshot.turn.id
            case .reference(let turn):
                turn.turnID
            }
        }
    }

    static func turnProperties(for turnSnapshot: ProvenanceFactualSessionProjectionTurnSnapshot) -> [TurnProperty] {
        var rows: [TurnProperty] = []
        if let prompt = turnSnapshot.submittedPrompt?.text {
            rows.append(.prompt(prompt))
        }
        rows.append(.providerTurnID(turnSnapshot.turn.providerTurnID))
        rows.append(.peTurnID(turnSnapshot.turn.id))
        rows.append(.peThreadID(turnSnapshot.turn.threadID))
        rows.append(.status(turnSnapshot.turn.status))
        rows.append(.model(turnSnapshot.turn.model))
        return rows
    }

    static func priorTurnItems(for snapshot: ProvenanceFactualSessionProjectionSnapshot) -> [PriorTurnItem] {
        var detailedTurnsByID: [String: ProvenanceFactualSessionProjectionTurnSnapshot] = [:]
        for turn in snapshot.turns {
            detailedTurnsByID[turn.turn.id] = turn
        }
        return snapshot.priorTurns.map { turn in
            if let detail = detailedTurnsByID[turn.turnID] {
                return .detail(detail)
            }
            return .reference(turn)
        }
    }

    static func latestRows<Value>(_ values: [Value], limit: Int) -> [Value] {
        guard limit > 0 else { return [] }
        guard values.count > limit else { return values }
        return Array(values.suffix(limit))
    }

    static func finalAssistantMessageText(for turnSnapshot: ProvenanceFactualSessionProjectionTurnSnapshot) -> String? {
        turnSnapshot.assistantMessages.reversed().compactMap { message in
            trimmedNonEmpty(message.text)
        }.first
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

struct AgentSessionWorkspaceLink: Identifiable, Equatable {
    let id: String
    let label: String
    let kind: String
    let url: URL?
    let state: String?
    let owner: String?
}

struct AgentSessionWorkspaceChrome: Equatable {
    let title: String
    let repository: String?
    let colorHex: String?
    let status: String?
    let activity: String?
    let links: [AgentSessionWorkspaceLink]
}

struct AgentSessionFactualProjectionModeHost<PrimaryContent: View>: View {
    let showsSwitcher: Bool
    var chatContent: ((_ onTerminal: @escaping () -> Void) -> AnyView)? = nil
    let stableWorkspaceID: UUID?
    let workProvenanceRuntime: WorkProvenanceRuntime?
    let backgroundColor: NSColor
    let workspaceChrome: AgentSessionWorkspaceChrome?
    @ViewBuilder let primaryContent: (_ isVisible: Bool) -> PrimaryContent

    @State private var viewMode: AgentSessionFactualProjectionMode = .terminal
    @State private var factualProjectionResult: AgentSessionFactualProjectionReadResult = .missingSession
    @State private var isLoadingFactualProjection = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            if showsSwitcher {
                viewNavigation
                Divider()
            }
            selectedContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: showsSwitcher) { _, isVisible in
            if !isVisible {
                viewMode = .terminal
            } else {
                scheduleFactualProjectionRefreshIfNeeded()
            }
        }
        .onChange(of: viewMode) { _, _ in
            scheduleFactualProjectionRefreshIfNeeded()
        }
        .onChange(of: stableWorkspaceID) { _, _ in
            scheduleFactualProjectionRefreshIfNeeded()
        }
        .onAppear {
            scheduleFactualProjectionRefreshIfNeeded()
        }
        .task(id: factualProjectionTaskID) {
            guard showsSwitcher,
            viewMode == .focus else { return }
            await refreshFactualProjection()
        }
        .task(id: factualProjectionRefreshLoopTaskID) {
            guard showsSwitcher,
                  viewMode == .focus else { return }
            await runFactualProjectionRefreshLoop()
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        VStack(spacing: 0) {
            if let workspaceChrome {
                AgentSessionWorkspaceHeader(chrome: workspaceChrome)
            }
            ZStack {
                primaryContent(primaryContentIsVisible)
                    .opacity(primaryContentIsVisible ? 1 : 0)
                    .allowsHitTesting(primaryContentIsVisible)
                    .accessibilityHidden(!primaryContentIsVisible)

                if let chatContent, viewMode == .chat {
                    chatContent { viewMode = .terminal }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if showsFocusContent {
                    AgentSessionFactualProjectionView(
                        result: factualProjectionResult,
                        isLoading: isLoadingFactualProjection,
                        backgroundColor: shellContentBackground,
                        onRefresh: {
                            Task { await refreshFactualProjection() }
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        scheduleFactualProjectionRefreshIfNeeded()
                    }
                }
                if showsLearningsContent {
                    AgentSessionLearningsUnavailableView(backgroundColor: shellContentBackground)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private var showsFocusContent: Bool {
        showsSwitcher && viewMode == .focus
    }

    private var showsLearningsContent: Bool {
        showsSwitcher && viewMode == .learnings
    }

    private var primaryContentIsVisible: Bool {
        !showsFocusContent && !showsLearningsContent && viewMode != .chat
    }

    private var viewNavigation: some View {
        HStack(spacing: 24) {
            ForEach(AgentSessionFactualProjectionMode.allCases.filter { $0 != .chat || chatContent != nil }) { mode in
                Button {
                    viewMode = mode
                } label: {
                    VStack(spacing: 8) {
                        Text(mode.title)
                            .font(.system(size: 13, weight: viewMode == mode ? .semibold : .medium))
                            .foregroundStyle(viewMode == mode ? .primary : .secondary)
                        Rectangle()
                            .fill(viewMode == mode ? shellAccent : .clear)
                            .frame(height: 2)
                    }
                    .padding(.top, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(viewMode == mode ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .background(shellRail)
    }

    private var shellRail: Color {
        colorScheme == .dark ? Color(nsColor: NSColor(hex: "#191A1D") ?? .windowBackgroundColor) : Color(nsColor: NSColor(hex: "#F2F0F5") ?? .windowBackgroundColor)
    }

    private var shellAccent: Color {
        colorScheme == .dark ? Color(nsColor: NSColor(hex: "#B9A3FF") ?? .systemPurple) : Color(nsColor: NSColor(hex: "#6542AD") ?? .systemPurple)
    }

    private var shellContentBackground: Color {
        colorScheme == .dark ? Color(nsColor: NSColor(hex: "#222326") ?? backgroundColor) : Color(nsColor: NSColor(hex: "#FCFBFD") ?? backgroundColor)
    }

    private var factualProjectionTaskID: String {
        "\(showsSwitcher):\(viewMode.rawValue):\(stableWorkspaceID?.uuidString ?? "no-workspace")"
    }

    private var factualProjectionRefreshLoopTaskID: String {
        "\(factualProjectionTaskID):loop"
    }

    private func runFactualProjectionRefreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: agentSessionFactualProjectionAutoRefreshNanoseconds)
            guard !Task.isCancelled else { return }
            await refreshFactualProjection(showLoading: false)
        }
    }

    private func refreshFactualProjection(showLoading: Bool = true) async {
        guard !isLoadingFactualProjection else { return }
        if showLoading {
            isLoadingFactualProjection = true
        }
        defer {
            if showLoading {
                isLoadingFactualProjection = false
            }
        }
        guard let stableWorkspaceID,
              let workProvenanceRuntime else {
            factualProjectionResult = .unavailable
            return
        }
        let nextResult = await workProvenanceRuntime.agentSessionFactualProjection(
            stableWorkspaceID: stableWorkspaceID
        )
        if nextResult != factualProjectionResult {
            factualProjectionResult = nextResult
        }
    }

    private func scheduleFactualProjectionRefreshIfNeeded() {
        guard showsSwitcher, viewMode == .focus else { return }
        Task { await refreshFactualProjection() }
    }
}

private struct AgentSessionWorkspaceHeader: View {
    let chrome: AgentSessionWorkspaceChrome
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(nsColor: chrome.colorHex.flatMap {
                    WorkspaceTabColorSettings.displayNSColor(hex: $0, colorScheme: colorScheme)
                } ?? .systemPurple))
                .frame(width: 4, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(chrome.repository ?? chrome.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(verbatim: "·")
                        .foregroundStyle(.tertiary)
                    Text(chrome.title)
                        .font(.system(size: 24, weight: .semibold))
                        .lineLimit(2)
                }
                if let activity = chrome.activity ?? chrome.status {
                    Text(activity)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if !chrome.links.isEmpty {
                HStack(spacing: 8) {
                    ForEach(chrome.links.prefix(3)) { link in
                        if let url = link.url {
                            Link(link.label, destination: url)
                                .font(.system(size: 12, weight: .medium))
                        } else {
                            Text(link.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if chrome.links.count > 3 {
                        Menu {
                            ForEach(Array(chrome.links.dropFirst(3))) { link in
                                if let url = link.url {
                                    Link(link.label, destination: url)
                                } else {
                                    Text(link.label)
                                }
                            }
                        } label: {
                            Label(
                                String(localized: "agentSession.workspace.moreLinks", defaultValue: "More links", comment: "Additional workspace links disclosure"),
                                systemImage: "ellipsis"
                            )
                            .font(.system(size: 12, weight: .medium))
                        }
                        .menuStyle(.borderlessButton)
                    }
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .fixedSize(horizontal: false, vertical: true)
        .background(colorScheme == .dark ? Color(nsColor: NSColor(hex: "#222326") ?? .windowBackgroundColor) : Color(nsColor: NSColor(hex: "#FCFBFD") ?? .windowBackgroundColor))
    }
}

/// Learnings stays honest until a persisted producer and review lifecycle are
/// available. Related-session history is evidence, not curated knowledge.
private struct AgentSessionLearningsUnavailableView: View {
    let backgroundColor: Color

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(String(localized: "agentSession.web.smartSession.learnings", defaultValue: "Learnings"))
                    .font(.system(size: 20, weight: .semibold))
                Text(String(localized: "agentSession.web.smartSession.noLearnings", defaultValue: "Useful next time. Grounded in this time."))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(String(localized: "agentSession.web.smartSession.learningsUnavailable", defaultValue: "Learnings are unavailable for this workspace."))
                        .font(.system(size: 15, weight: .semibold))
                    Text(String(localized: "agentSession.web.smartSession.learningsUnavailable.detail", defaultValue: "No persisted knowledge producer or review lifecycle is connected. This view will not invent records or counts."))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
        }
        .background(backgroundColor)
    }
}

private enum AgentSessionFactualProjectionMode: String, CaseIterable, Identifiable {
    case terminal
    case chat
    case focus
    case learnings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terminal:
            String(localized: "agentSession.viewMode.terminal", defaultValue: "Terminal")
        case .chat:
            String(localized: "agentSession.viewMode.chat", defaultValue: "Chat")
        case .focus:
            String(localized: "agentSession.web.smartSession.focus", defaultValue: "Focus")
        case .learnings:
            String(localized: "agentSession.web.smartSession.learnings", defaultValue: "Learnings")
        }
    }
}

struct AgentSessionFactualProjectionView: View {
    let result: AgentSessionFactualProjectionReadResult
    let isLoading: Bool
    let backgroundColor: Color
    let onRefresh: () -> Void

    @State private var expandedPriorTurnIDs: Set<String> = []
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    content
                }
                .frame(maxWidth: 780, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(String(localized: "agentSession.factual.title", defaultValue: "Focus"))
                .font(.system(size: 24, weight: .semibold))
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer(minLength: 0)
            Button {
                onRefresh()
            } label: {
                Label(
                    String(localized: "agentSession.factual.refresh", defaultValue: "Refresh"),
                    systemImage: "arrow.clockwise"
                )
                .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .safeHelp(String(
                localized: "agentSession.factual.refresh.tooltip",
                defaultValue: "Refresh session facts"
            ))
        }
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
            section(String(localized: "agentSession.factual.latestTurn", defaultValue: "Latest turn")) {
                if let turn = snapshot.latestTurn {
                    AgentSessionFactualProjectionCurrentTurnCardView(turnSnapshot: turn)
                } else {
                    mutedText(String(localized: "agentSession.factual.noTurns", defaultValue: "No turns observed."))
                }
            }

            // Completed turns stay quiet and newest-first. Their source detail
            // remains behind the stable turn-ID disclosure in the row view.
            section(String(localized: "agentSession.factual.priorTurns", defaultValue: "Prior turns")) {
                if snapshot.priorTurns.isEmpty {
                    mutedText(String(localized: "agentSession.factual.noPriorTurns", defaultValue: "No prior turns."))
                } else {
                    ForEach(
                        Array(AgentSessionFactualProjectionEvidenceRows.priorTurnItems(for: snapshot).enumerated()),
                        id: \.element.id
                    ) { offset, item in
                        AgentSessionFactualProjectionPriorTurnCardView(
                            item: item,
                            ordinal: offset + 1,
                            isExpanded: expandedPriorTurnIDs.contains(item.id),
                            onToggle: {
                                togglePriorTurnExpansion(item.id)
                            }
                        )
                    }
                }
            }

            DisclosureGroup(String(localized: "agentSession.factual.identity", defaultValue: "Identity")) {
                VStack(alignment: .leading, spacing: 14) {
                    section(String(localized: "agentSession.factual.identity", defaultValue: "Identity")) {
                        factRow(String(localized: "agentSession.factual.sessionID", defaultValue: "Session ID"), snapshot.session.id)
                        factRow(String(localized: "agentSession.factual.provider", defaultValue: "Provider"), snapshot.session.agentKind)
                        factRow(String(localized: "agentSession.factual.status", defaultValue: "Status"), snapshot.session.status)
                        factRow(String(localized: "agentSession.factual.cwd", defaultValue: "Directory"), snapshot.session.cwd)
                        factRow(String(localized: "agentSession.factual.revision", defaultValue: "Revision"), snapshot.revision.map(String.init))
                    }

                    section(String(localized: "agentSession.factual.threads", defaultValue: "Threads")) {
                        if snapshot.providerThreadIdentities.isEmpty {
                            mutedText(String(localized: "agentSession.factual.noThreads", defaultValue: "No provider threads observed."))
                        } else {
                            ForEach(snapshot.providerThreadIdentities, id: \.threadID) { thread in
                                threadRow(thread)
                            }
                        }
                    }
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(cardBorder, lineWidth: 1)
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

    private func togglePriorTurnExpansion(_ id: String) {
        if expandedPriorTurnIDs.contains(id) {
            expandedPriorTurnIDs.remove(id)
        } else {
            expandedPriorTurnIDs.insert(id)
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
            .padding(24)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(hex: "#25262B") ?? .windowBackgroundColor)
            : Color(nsColor: NSColor(hex: "#F8F7FA") ?? .windowBackgroundColor)
    }

    private var cardBorder: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(hex: "#3B3D48") ?? .separatorColor)
            : Color(nsColor: NSColor(hex: "#D3CEDB") ?? .separatorColor)
    }

    private func nonEmpty(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return String(localized: "agentSession.factual.unknown", defaultValue: "Unknown")
    }
}

private struct AgentSessionFactualProjectionCurrentTurnCardView: View {
    let turnSnapshot: ProvenanceFactualSessionProjectionTurnSnapshot
    @State private var isEvidenceExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(prompt)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(3)
                Spacer(minLength: 8)
                Text(turnSnapshot.turn.status)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let output = AgentSessionFactualProjectionEvidenceRows.finalAssistantMessageText(for: turnSnapshot) {
                Text(output)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let plan = turnSnapshot.currentPlan, !plan.steps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(plan.steps.prefix(5), id: \.id) { step in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: planStepSymbol(step.status))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(planStepColor(step.status))
                                .frame(width: 14)
                            Text(step.text)
                                .font(.system(size: 12))
                                .lineLimit(2)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                evidenceBadge("agentSession.factual.commands", turnSnapshot.completedCommands.count)
                evidenceBadge("agentSession.factual.files", turnSnapshot.fileChangeAttributions.count)
                evidenceBadge("agentSession.factual.reasoning", turnSnapshot.visibleReasoningSummaries.count)
            }

            DisclosureGroup(isExpanded: $isEvidenceExpanded) {
                AgentSessionFactualProjectionTurnDetailView(turnSnapshot: turnSnapshot)
                    .padding(.top, 8)
            } label: {
                Label(
                    String(localized: "agentSession.factual.details", defaultValue: "Details"),
                    systemImage: "chevron.right"
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            }
        }
    }

    private var prompt: String {
        let value = turnSnapshot.submittedPrompt?.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false
            ? value!
            : String(localized: "agentSession.factual.prompt.missing", defaultValue: "No prompt captured")
    }

    private func evidenceBadge(_ key: String, _ count: Int) -> some View {
        let localizedLabel: String = switch key {
        case "agentSession.factual.files":
            String(localized: "agentSession.factual.files", defaultValue: "Files")
        case "agentSession.factual.reasoning":
            String(localized: "agentSession.factual.reasoning", defaultValue: "Reasoning")
        default:
            String(localized: "agentSession.factual.commands", defaultValue: "Commands")
        }
        return Text(String.localizedStringWithFormat(
            localizedLabel + ": %d",
            count
        ))
        .font(.system(size: 10, weight: .medium))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.secondary.opacity(0.12), in: Capsule())
    }

    private func planStepSymbol(_ status: String) -> String {
        let normalized = status.lowercased()
        if normalized.contains("complete") || normalized.contains("done") {
            return "checkmark"
        }
        if normalized.contains("progress") || normalized.contains("running") {
            return "circle.dotted"
        }
        return "circle"
    }

    private func planStepColor(_ status: String) -> Color {
        let normalized = status.lowercased()
        if normalized.contains("complete") || normalized.contains("done") {
            return .green
        }
        if normalized.contains("progress") || normalized.contains("running") {
            return .orange
        }
        return .secondary
    }
}
