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
    static let bmuxLinkGreen = Color(red: 0.478, green: 0.620, blue: 0.416)
    static let bmuxTabSelected = Color(red: 0.471, green: 0.741, blue: 0.980)
    static let bmuxAmberFill = Color(red: 0.137, green: 0.110, blue: 0.039)
    static let bmuxAmberBorder = Color(red: 0.239, green: 0.180, blue: 0.039)
    static let bmuxAmberText = Color(red: 0.784, green: 0.643, blue: 0.290)
    static let bmuxUserMessage = Color(red: 0.118, green: 0.118, blue: 0.118)
    static let bmuxActionRow = Color(red: 0.090, green: 0.090, blue: 0.090)
    static let bmuxComposer = Color(red: 0.094, green: 0.094, blue: 0.094)
    static let bmuxComposerBorder = Color(red: 0.165, green: 0.165, blue: 0.165)
    static let bmuxPillActive = Color(red: 0.145, green: 0.145, blue: 0.145)
    static let bmuxQueueFill = Color(red: 0.118, green: 0.180, blue: 0.110)
}

private enum BmuxRadius {
    static let appShell: CGFloat = 12
}

private let agentSessionFactualProjectionAutoRefreshNanoseconds: UInt64 = 2_000_000_000

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
        }.sorted { turnDate(for: $0) > turnDate(for: $1) }
    }

    static func turnDate(for item: PriorTurnItem) -> Date {
        switch item {
        case .detail(let turnSnapshot):
            turnSnapshot.turn.completedAt ?? turnSnapshot.turn.updatedAt
        case .reference(let turn):
            turn.completedAt ?? turn.updatedAt
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

struct AgentSessionFactualProjectionModeHost<PrimaryContent: View>: View {
    let showsSwitcher: Bool
    var showsModePicker = true
    var startsInSession = false
    var showsAppShell = false
    var fixturePreviewEnabled = false
    var liveChatContent: ((@escaping () -> Void) -> AnyView)?
    var liveTerminalContent: AnyView?
    var onPrimaryTabChange: ((Bool) -> Void)?
    var workspaceLabel: String?
    var sessionTitle: String?
    var sessionDescription: String?
    var chatContent: ((_ onTerminal: @escaping () -> Void) -> AnyView)? = nil
    let stableWorkspaceID: UUID?
    let workProvenanceRuntime: WorkProvenanceRuntime?
    let backgroundColor: NSColor
    @ViewBuilder let primaryContent: (_ isVisible: Bool) -> PrimaryContent

    @State private var viewMode: AgentSessionFactualProjectionMode = .terminal
    @State private var factualProjectionResult: AgentSessionFactualProjectionReadResult = .missingSession
    @State private var isLoadingFactualProjection = false

    var body: some View {
        VStack(spacing: 0) {
            if showsSwitcher && showsModePicker {
                modePicker
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
            if startsInSession {
                viewMode = .session
            }
            scheduleFactualProjectionRefreshIfNeeded()
        }
        .task(id: factualProjectionTaskID) {
            guard showsSwitcher,
            viewMode == .session else { return }
            await refreshFactualProjection()
        }
        .task(id: factualProjectionRefreshLoopTaskID) {
            guard showsSwitcher,
                  viewMode == .session else { return }
            await runFactualProjectionRefreshLoop()
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        ZStack {
            primaryContent(primaryContentIsVisible)
                .opacity(primaryContentIsVisible ? 1 : 0)
                .allowsHitTesting(primaryContentIsVisible)
                .accessibilityHidden(!primaryContentIsVisible)

            if let chatContent, viewMode == .chat {
                chatContent { viewMode = .terminal }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if showsSessionContent {
                AgentSessionFactualProjectionView(
                    result: factualProjectionResult,
                    isLoading: isLoadingFactualProjection,
                    backgroundColor: Color(nsColor: backgroundColor),
                    onRefresh: {
                        Task { await refreshFactualProjection() }
                    },
                    showsAppShell: showsAppShell,
                    fixturePreviewEnabled: fixturePreviewEnabled,
                    liveChatContent: liveChatContent,
                    liveTerminalContent: liveTerminalContent,
                    onPrimaryTabChange: onPrimaryTabChange,
                    workspaceLabel: workspaceLabel,
                    sessionTitle: sessionTitle,
                    sessionDescription: sessionDescription
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    scheduleFactualProjectionRefreshIfNeeded()
                }
            }
        }
    }

    private var showsSessionContent: Bool {
        showsSwitcher && viewMode == .session
    }

    private var primaryContentIsVisible: Bool {
        !showsSessionContent && viewMode != .chat
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            Picker("", selection: $viewMode) {
                ForEach(AgentSessionFactualProjectionMode.allCases.filter { $0 != .chat || chatContent != nil }) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: chatContent == nil ? 180 : 260)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(nsColor: backgroundColor))
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
        guard showsSwitcher, viewMode == .session else { return }
        Task { await refreshFactualProjection() }
    }
}

private enum AgentSessionFactualProjectionMode: String, CaseIterable, Identifiable {
    case terminal
    case chat
    case session

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terminal:
            String(localized: "agentSession.viewMode.terminal", defaultValue: "Terminal")
        case .chat:
            String(localized: "agentSession.viewMode.chat", defaultValue: "Chat")
        case .session:
            String(localized: "agentSession.viewMode.session", defaultValue: "Session")
        }
    }
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
    var workspaceLabel: String?
    var sessionTitle: String?
    var sessionDescription: String?

    @State private var expandedPriorTurnIDs: Set<String> = []
    @State private var selectedPrimaryTab = AgentSessionFactualProjectionMode.session.rawValue

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
            primaryTabs.padding(.top, 16)
            switch selectedPrimaryTab {
            case AgentSessionFactualProjectionMode.session.rawValue:
                sessionContent
            case AgentSessionFactualProjectionMode.chat.rawValue:
                chatContentView
            case AgentSessionFactualProjectionMode.terminal.rawValue:
                terminalContentView
            default:
                emptyMessage(String(localized: "agentSession.factual.unavailable", defaultValue: "Session data unavailable"))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bmuxSurface)
        .foregroundStyle(Color.bmuxTextPrimary)
    }

    private var primaryTabs: some View {
        HStack(spacing: 24) {
            ForEach([
                AgentSessionFactualProjectionMode.session,
                AgentSessionFactualProjectionMode.chat,
                AgentSessionFactualProjectionMode.terminal
            ]) { mode in
                Button(mode.title) {
                    selectedPrimaryTab = mode.rawValue
                    onPrimaryTabChange?(mode == .terminal)
                }
                    .buttonStyle(.plain)
                    .font(.system(size: 13.5, weight: selectedPrimaryTab == mode.rawValue ? .medium : .regular))
                    .foregroundStyle(selectedPrimaryTab == mode.rawValue ? Color.bmuxTabSelected : Color.bmuxTextTertiary)
                    .padding(.bottom, 10)
                    .overlay(alignment: .bottom) { if selectedPrimaryTab == mode.rawValue { Rectangle().fill(Color.bmuxTabSelected).frame(height: 2) } }
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
            if selectedPrimaryTab == AgentSessionFactualProjectionMode.terminal.rawValue,
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
                    selectedPrimaryTab = AgentSessionFactualProjectionMode.terminal.rawValue
                    onPrimaryTabChange?(true)
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
                currentTurnOverview(turn)
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
                let items = AgentSessionFactualProjectionEvidenceRows.priorTurnItems(for: snapshot)
                if items.isEmpty {
                    mutedText(String(localized: "agentSession.factual.noPriorTurns", defaultValue: "No prior turns."))
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                        AgentSessionFactualProjectionPriorTurnCardView(
                            item: item,
                            ordinal: offset + 1,
                            isExpanded: expandedPriorTurnIDs.contains(item.id),
                            onToggle: { togglePriorTurnExpansion(item.id) }
                        )
                    }
                }
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

    private func currentTurnOverview(_ turn: ProvenanceFactualSessionProjectionTurnSnapshot) -> some View {
        let objective = turnObjective(turn)
        let summary = turnAgentSummary(turn)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "agentSession.factual.latestTurn", defaultValue: "Current turn"))
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(Color.bmuxTextTertiary)
                Spacer()
                Text(turnElapsedText(turn))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bmuxTextTertiary)
            }
            Text(summary ?? objective ?? String(localized: "agentSession.factual.noTurns", defaultValue: "No turns observed."))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.bmuxTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let objective {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "agentSession.factual.objective", defaultValue: "Objective"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.bmuxTextTertiary)
                    Text(objective)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Color.bmuxTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if summary == nil {
                Text(String(localized: "agentSession.factual.noAgentSummary", defaultValue: "No agent summary observed."))
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.bmuxTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Text(summary == nil
                     ? String(localized: "agentSession.factual.evidenceSource", defaultValue: "Observed evidence")
                     : String(localized: "agentSession.factual.source", defaultValue: "Agent-reported"))
                    .foregroundStyle(Color.bmuxTextTertiary)
                DisclosureGroup(String(localized: "agentSession.factual.details", defaultValue: "View evidence")) {
                    AgentSessionFactualProjectionTurnDetailView(turnSnapshot: turn)
                        .padding(.top, 6)
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.bmuxLinkGreen)
            }
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.bmuxLinkGreen).frame(width: 2)
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

    private func turnObjective(_ turn: ProvenanceFactualSessionProjectionTurnSnapshot) -> String? {
        let prompt = turn.submittedPrompt?.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return prompt?.isEmpty == false ? prompt : nil
    }

    private func turnAgentSummary(_ turn: ProvenanceFactualSessionProjectionTurnSnapshot) -> String? {
        guard let output = AgentSessionFactualProjectionEvidenceRows.finalAssistantMessageText(for: turn)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty else { return nil }
        guard normalizeTurnText(output) != normalizeTurnText(turnObjective(turn) ?? "") else { return nil }
        return output
    }

    private func normalizeTurnText(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").lowercased()
    }

    private func turnElapsedText(_ turn: ProvenanceFactualSessionProjectionTurnSnapshot) -> String {
        guard let started = turn.turn.startedAt else {
            return String(localized: "agentSession.factual.unknown", defaultValue: "Unknown")
        }
        let end = turn.turn.completedAt ?? turn.turn.updatedAt
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: max(0, end.timeIntervalSince(started)))
            ?? String(localized: "agentSession.factual.unknown", defaultValue: "Unknown")
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
            .padding(.top, 48)
    }

    private func nonEmpty(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return String(localized: "agentSession.factual.unknown", defaultValue: "Unknown")
    }
}
