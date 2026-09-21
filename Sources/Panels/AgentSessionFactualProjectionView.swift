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
    static let bmuxTabUnderline = Color(red: 0.878, green: 0.878, blue: 0.878)
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

struct AgentSessionFactualProjectionModeHost<PrimaryContent: View>: View {
    let showsSwitcher: Bool
    var showsModePicker = true
    var startsInSession = false
    var showsAppShell = false
    var fixturePreviewEnabled = false
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
    var liveTerminalContent: AnyView?
    var onPrimaryTabChange: ((Bool) -> Void)?
    var workspaceLabel: String?
    var sessionTitle: String?
    var sessionDescription: String?

    @State private var expandedPriorTurnIDs: Set<String> = []
    @State private var selectedPrimaryTab = "Session"
    @State private var selectedSecondaryTab = "Overview"
    @State private var expandedDisclosureRows: Set<String> = []
    @State private var composerText = ""

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
                        Text("bmux").font(.system(size: 21, weight: .bold, design: .rounded))
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
            Text(sessionDescription ?? String(localized: "agentSession.factual.sessionDescriptionUnavailable", defaultValue: "No session description is available."))
                .font(.system(size: 13.5)).foregroundStyle(Color.bmuxTextTertiary).padding(.top, 4)
            primaryTabs.padding(.top, 16)
            if selectedPrimaryTab == "Session" { sessionContent } else if selectedPrimaryTab == "Terminal" { terminalContentView } else { nativeContent }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bmuxSurface)
        .foregroundStyle(Color.bmuxTextPrimary)
    }

    private var primaryTabs: some View {
        HStack(spacing: 24) {
            ForEach(["Session", "Terminal", "Native"], id: \.self) { tab in
                Button(tab) {
                    selectedPrimaryTab = tab
                    onPrimaryTabChange?(tab == "Terminal")
                }
                    .buttonStyle(.plain)
                    .font(.system(size: 13.5, weight: selectedPrimaryTab == tab ? .medium : .regular))
                    .foregroundStyle(selectedPrimaryTab == tab ? Color.bmuxTextPrimary : Color.bmuxTextTertiary)
                    .padding(.bottom, 10)
                    .overlay(alignment: .bottom) { if selectedPrimaryTab == tab { Rectangle().fill(Color.bmuxTabUnderline).frame(height: 2) } }
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
            if selectedPrimaryTab == "Terminal", let liveTerminalContent {
                liveTerminalContent
                    .id("bmux-shell-terminal")
            } else {
                Color.clear
            }
        }
    }

    private var secondaryTabs: some View {
        HStack(spacing: 4) {
            ForEach(["Overview", "Related work  2", "Findings  2"], id: \.self) { tab in
                Button(tab) { selectedSecondaryTab = tab }
                    .buttonStyle(.plain).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selectedSecondaryTab == tab ? Color.bmuxTextSecondary : Color.bmuxTextTertiary)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(selectedSecondaryTab == tab ? Color.bmuxPillActive : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var currentTurn: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.bmuxTurnAccent).frame(width: 2)
            VStack(alignment: .leading, spacing: 6) {
                HStack { Text("CURRENT TURN").font(.system(size: 10, weight: .medium)).tracking(1.4); Spacer(); Text("Codex · 28m 36s") }
                    .foregroundStyle(Color.bmuxTextTertiary)
                Text("Tickets ready. Reviews still running.").font(.system(size: 18, weight: .bold)).foregroundStyle(Color.bmuxTextPrimary)
                Text("Four tickets are assigned and in review. The agent is waiting for review feedback before handing back the stack.")
                    .font(.system(size: 13.5)).foregroundStyle(Color.bmuxTextTertiary).lineSpacing(4)
                HStack(spacing: 6) { Text("Agent-reported"); Button("View source") { onRefresh() }.underline() }.font(.system(size: 12)).foregroundStyle(Color.bmuxLinkGreen)
            }.padding(.leading, 16)
        }
    }

    private var overlapNotice: some View {
        HStack(spacing: 8) { Image(systemName: "square.on.square"); Text("Another session touched a file in this work."); Spacer(); Button("Inspect overlap") { onRefresh() }.underline() }
            .font(.system(size: 13)).foregroundStyle(Color.bmuxAmberText).padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.bmuxAmberFill).clipShape(RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.bmuxAmberBorder))
    }

    private var disclosureRows: some View {
        VStack(spacing: 0) {
            disclosureRow(id: "plan", icon: "list.bullet", title: "Plan & progress", meta: "3 of 4 steps complete")
            disclosureRow(id: "checks", icon: "checkmark.circle", title: "Checks & changes", meta: "2 passed · 1 pending")
            disclosureRow(id: "blockers", icon: "lock", title: "Blockers & approach changes", meta: "1 change")
        }
    }

    private func disclosureRow(id: String, icon: String, title: String, meta: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { if expandedDisclosureRows.contains(id) { expandedDisclosureRows.remove(id) } else { expandedDisclosureRows.insert(id) } } label: {
                HStack(spacing: 10) { Image(systemName: icon); Text(title); Text(meta).font(.system(size: 12.5)); Spacer(); Image(systemName: expandedDisclosureRows.contains(id) ? "minus" : "plus") }
            }.buttonStyle(.plain).font(.system(size: 13.5)).foregroundStyle(Color.bmuxTextSecondary)
            if expandedDisclosureRows.contains(id) { Text("Details will appear as the live session reports them.").font(.system(size: 12)).foregroundStyle(Color.bmuxTextTertiary).padding(.leading, 25) }
        }.padding(.vertical, 14).overlay(alignment: .bottom) { Rectangle().fill(Color.bmuxSeparatorSubtle).frame(height: 1) }
    }

    private var previousTurns: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Previous turns").font(.system(size: 14, weight: .semibold)); Spacer(); Text("Newest first").font(.system(size: 12)).foregroundStyle(Color.bmuxTextTertiary) }
            previousTurn("Check CI across the PR stack", "4 minutes ago · completed")
            previousTurn("Split implementation into six tickets", "19 minutes ago · completed")
        }.foregroundStyle(Color.bmuxTextSecondary)
    }

    private func previousTurn(_ title: String, _ meta: String) -> some View {
        HStack { VStack(alignment: .leading, spacing: 3) { Text(title); Text(meta).font(.system(size: 11.5)).foregroundStyle(Color.bmuxTextTertiary) }; Spacer(); Text("Tokens —  +").font(.system(size: 12)).foregroundStyle(Color.bmuxTextTertiary) }
            .padding(.vertical, 12).overlay(alignment: .bottom) { Rectangle().fill(Color.bmuxSeparatorSubtle).frame(height: 1) }
    }

    private var terminalContent: some View {
        VStack(spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) { HStack { Text("You").fontWeight(.semibold); Spacer(); Text("5:02 PM").foregroundStyle(Color.bmuxTextTertiary) }; Text("Assign all those new tickets to me and put them in review.") }.padding(16).background(Color.bmuxUserMessage).clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 12) { Text("✳  Codex").fontWeight(.semibold); Text("I'll update the four tickets, then check the PR stack for review feedback.").foregroundStyle(Color.bmuxTextTertiary); Text("✓  Updated four Linear tickets                                      Completed").padding(12).background(Color.bmuxActionRow).clipShape(RoundedRectangle(cornerRadius: 6)); Text("✓  Checked CI and review status                                      Completed").padding(12).background(Color.bmuxActionRow).clipShape(RoundedRectangle(cornerRadius: 6)); Text("Working · 28m 36s").foregroundStyle(Color.bmuxTextTertiary) }
                }.padding(.top, 20)
            }
            VStack(alignment: .leading, spacing: 6) { Text("Follow up with Codex").foregroundStyle(Color.bmuxTextDisabled); TextField("Ask a follow-up, or steer the current work...", text: $composerText, axis: .vertical).textFieldStyle(.plain).frame(minHeight: 54); HStack { Text("Codex · medium effort").foregroundStyle(Color.bmuxTextTertiary); Spacer(); Button("Queue message ↑") { }.padding(.horizontal, 12).padding(.vertical, 7).background(Color.bmuxQueueFill).clipShape(RoundedRectangle(cornerRadius: 6)) } }.font(.system(size: 12)).padding(12).background(Color.bmuxComposer).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.bmuxComposerBorder))
        }
    }

    private var nativeContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "agentSession.factual.nativeUnavailable.title", defaultValue: "Provider-native session unavailable"))
                .font(.system(size: 18, weight: .bold))
            Text(String(localized: "agentSession.factual.nativeUnavailable.message", defaultValue: "This provider does not expose a native session surface in this build."))
                .foregroundStyle(Color.bmuxTextTertiary)
        }
        .padding(.top, 22)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(String(localized: "agentSession.factual.title", defaultValue: "Session"))
                .font(.system(size: 16, weight: .semibold))
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

            section(String(localized: "agentSession.factual.latestTurn", defaultValue: "Latest turn")) {
                if let turn = snapshot.latestTurn {
                    AgentSessionFactualProjectionTurnDetailView(turnSnapshot: turn)
                } else {
                    mutedText(String(localized: "agentSession.factual.noTurns", defaultValue: "No turns observed."))
                }
            }

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
