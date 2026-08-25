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
}

struct AgentSessionFactualProjectionModeHost<PrimaryContent: View>: View {
    let showsSwitcher: Bool
    let stableWorkspaceID: UUID?
    let workProvenanceRuntime: WorkProvenanceRuntime?
    let backgroundColor: NSColor
    @ViewBuilder let primaryContent: (_ isVisible: Bool) -> PrimaryContent

    @State private var viewMode: AgentSessionFactualProjectionMode = .terminal
    @State private var factualProjectionResult: AgentSessionFactualProjectionReadResult = .missingSession
    @State private var isLoadingFactualProjection = false

    var body: some View {
        VStack(spacing: 0) {
            if showsSwitcher {
                modePicker
                Divider()
            }
            selectedContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: showsSwitcher) { _, isVisible in
            if !isVisible {
                viewMode = .terminal
            }
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

            if showsSessionContent {
                AgentSessionFactualProjectionView(
                    result: factualProjectionResult,
                    isLoading: isLoadingFactualProjection,
                    backgroundColor: Color(nsColor: backgroundColor),
                    onRefresh: {
                        Task { await refreshFactualProjection() }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var showsSessionContent: Bool {
        showsSwitcher && viewMode == .session
    }

    private var primaryContentIsVisible: Bool {
        !showsSessionContent
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            Picker("", selection: $viewMode) {
                ForEach(AgentSessionFactualProjectionMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)

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
}

private enum AgentSessionFactualProjectionMode: String, CaseIterable, Identifiable {
    case terminal
    case session

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terminal:
            String(localized: "agentSession.viewMode.terminal", defaultValue: "Terminal")
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

    @State private var expandedPriorTurnIDs: Set<String> = []

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            }
        }
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
                    turnDetail(turn)
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
                        priorTurnCard(
                            item,
                            ordinal: offset + 1,
                            isExpanded: expandedPriorTurnIDs.contains(item.id)
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

    private func turnDetail(_ turnSnapshot: ProvenanceFactualSessionProjectionTurnSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(AgentSessionFactualProjectionEvidenceRows.turnProperties(for: turnSnapshot).enumerated()), id: \.offset) { _, property in
                turnPropertyRow(property)
            }
            if let plan = turnSnapshot.currentPlan {
                planRows(plan)
            }
            summaryCounts(turnSnapshot)
            commandRows(turnSnapshot.completedCommands)
            reasoningRows(turnSnapshot.visibleReasoningSummaries)
            fileRows(turnSnapshot.fileChangeAttributions)
        }
    }

    @ViewBuilder
    private func turnPropertyRow(_ property: AgentSessionFactualProjectionEvidenceRows.TurnProperty) -> some View {
        switch property {
        case .prompt(let prompt):
            labeledText(String(localized: "agentSession.factual.prompt", defaultValue: "Prompt"), prompt, lineLimit: 4)
        case .providerTurnID(let providerTurnID):
            factRow(String(localized: "agentSession.factual.providerTurnID", defaultValue: "Provider turn ID"), providerTurnID)
        case .peTurnID(let peTurnID):
            factRow(String(localized: "agentSession.factual.peTurnID", defaultValue: "PE turn ID"), peTurnID)
        case .peThreadID(let peThreadID):
            factRow(String(localized: "agentSession.factual.peThreadID", defaultValue: "PE thread ID"), peThreadID)
        case .status(let status):
            factRow(String(localized: "agentSession.factual.status", defaultValue: "Status"), status)
        case .model(let model):
            factRow(String(localized: "agentSession.factual.model", defaultValue: "Model"), model)
        }
    }

    private func planRows(_ plan: ProvenanceCodingAgentPlanUpdateRecord) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(String(localized: "agentSession.factual.plan", defaultValue: "Current plan"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            ForEach(plan.steps.prefix(6), id: \.id) { step in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    badge(step.status)
                    Text(step.text)
                        .font(.system(size: 12))
                        .lineLimit(2)
                }
            }
        }
    }

    private func summaryCounts(_ turnSnapshot: ProvenanceFactualSessionProjectionTurnSnapshot) -> some View {
        HStack(spacing: 8) {
            countBadge(
                String(localized: "agentSession.factual.commands", defaultValue: "Commands"),
                turnSnapshot.completedCommands.count
            )
            countBadge(
                String(localized: "agentSession.factual.reasoning", defaultValue: "Reasoning"),
                turnSnapshot.visibleReasoningSummaries.count
            )
            countBadge(
                String(localized: "agentSession.factual.files", defaultValue: "Files"),
                turnSnapshot.fileChangeAttributions.count
            )
        }
    }

    private func commandRows(_ commands: [ProvenanceCodingAgentCommandRecord]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(AgentSessionFactualProjectionEvidenceRows.latestRows(commands, limit: 5), id: \.id) { command in
                labeledText(command.status, command.command, lineLimit: 2)
            }
        }
    }

    private func reasoningRows(_ summaries: [ProvenanceCodingAgentReasoningSummaryRecord]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(AgentSessionFactualProjectionEvidenceRows.latestRows(summaries, limit: 3), id: \.id) { summary in
                labeledText(
                    String(localized: "agentSession.factual.reasoningSummary", defaultValue: "Reasoning summary"),
                    summary.text,
                    lineLimit: 3
                )
            }
        }
    }

    private func fileRows(_ attributions: [ProvenanceCodingAgentFileChangeAttributionRecord]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(AgentSessionFactualProjectionEvidenceRows.latestRows(attributions, limit: 4), id: \.id) { attribution in
                labeledText(
                    String(localized: "agentSession.factual.fileChange", defaultValue: "File change"),
                    attribution.summary ?? attribution.paths.prefix(4).joined(separator: ", "),
                    lineLimit: 2
                )
            }
        }
    }

    private func priorTurnRow(_ turn: ProvenanceFactualSessionProjectionTurnReference) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            badge(turn.status)
            Text(turn.providerTurnID)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Text(dateText(turn.completedAt ?? turn.updatedAt))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func priorTurnCard(
        _ item: AgentSessionFactualProjectionEvidenceRows.PriorTurnItem,
        ordinal: Int,
        isExpanded: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                togglePriorTurnExpansion(item.id)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        Text(String.localizedStringWithFormat(
                            String(localized: "agentSession.factual.turnOrdinal", defaultValue: "Turn %d"),
                            ordinal
                        ))
                        .font(.system(size: 12, weight: .semibold))
                        badge(priorTurnStatus(item))
                        Spacer(minLength: 0)
                        Text(dateText(priorTurnFinishedAt(item)))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Text(priorTurnPrompt(item))
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 4) {
                        metadataLine(
                            systemImage: "clock",
                            text: String.localizedStringWithFormat(
                                String(localized: "agentSession.factual.started", defaultValue: "Started %@"),
                                dateText(priorTurnStartedAt(item))
                            )
                        )
                        metadataLine(
                            systemImage: "checkmark.circle",
                            text: String.localizedStringWithFormat(
                                String(localized: "agentSession.factual.finished", defaultValue: "Finished %@"),
                                dateText(priorTurnFinishedAt(item))
                            )
                        )
                        metadataLine(
                            systemImage: "timer",
                            text: String.localizedStringWithFormat(
                                String(localized: "agentSession.factual.duration", defaultValue: "Duration %@"),
                                priorTurnDurationText(item)
                            )
                        )
                    }

                    labeledText(
                        String(localized: "agentSession.factual.summary", defaultValue: "Summary"),
                        priorTurnSummary(item),
                        lineLimit: 3
                    )
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                    Text(String(localized: "agentSession.factual.details", defaultValue: "Details"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    priorTurnDetails(item)
                }
                .padding(.top, 12)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.secondary.opacity(0.16))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(priorTurnPrompt(item)))
    }

    @ViewBuilder
    private func priorTurnDetails(_ item: AgentSessionFactualProjectionEvidenceRows.PriorTurnItem) -> some View {
        switch item {
        case .detail(let turnSnapshot):
            turnDetail(turnSnapshot)
        case .reference(let turn):
            priorTurnRow(turn)
        }
    }

    private func metadataLine(systemImage: String, text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
    }

    private func togglePriorTurnExpansion(_ id: String) {
        if expandedPriorTurnIDs.contains(id) {
            expandedPriorTurnIDs.remove(id)
        } else {
            expandedPriorTurnIDs.insert(id)
        }
    }

    private func priorTurnPrompt(_ item: AgentSessionFactualProjectionEvidenceRows.PriorTurnItem) -> String {
        switch item {
        case .detail(let turnSnapshot):
            if let text = turnSnapshot.submittedPrompt?.text.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return text
            }
            return String(localized: "agentSession.factual.prompt.missing", defaultValue: "No prompt captured")
        case .reference:
            return String(localized: "agentSession.factual.prompt.missing", defaultValue: "No prompt captured")
        }
    }

    private func priorTurnSummary(_ item: AgentSessionFactualProjectionEvidenceRows.PriorTurnItem) -> String {
        switch item {
        case .detail(let turnSnapshot):
            if let summary = turnSnapshot.fileChangeAttributions.compactMap(\.summary).last?.trimmingCharacters(in: .whitespacesAndNewlines),
               !summary.isEmpty {
                return summary
            }
            if let summary = turnSnapshot.visibleReasoningSummaries.last?.text.trimmingCharacters(in: .whitespacesAndNewlines),
               !summary.isEmpty {
                return summary
            }
            if !turnSnapshot.completedCommands.isEmpty {
                return String.localizedStringWithFormat(
                    String(localized: "agentSession.factual.summary.commands", defaultValue: "Ran %d commands"),
                    turnSnapshot.completedCommands.count
                )
            }
            return String.localizedStringWithFormat(
                String(localized: "agentSession.factual.summary.status", defaultValue: "Turn ended with status %@"),
                turnSnapshot.turn.status
            )
        case .reference(let turn):
            return String.localizedStringWithFormat(
                String(localized: "agentSession.factual.summary.status", defaultValue: "Turn ended with status %@"),
                turn.status
            )
        }
    }

    private func priorTurnStatus(_ item: AgentSessionFactualProjectionEvidenceRows.PriorTurnItem) -> String {
        switch item {
        case .detail(let turnSnapshot):
            turnSnapshot.turn.status
        case .reference(let turn):
            turn.status
        }
    }

    private func priorTurnStartedAt(_ item: AgentSessionFactualProjectionEvidenceRows.PriorTurnItem) -> Date? {
        switch item {
        case .detail(let turnSnapshot):
            turnSnapshot.turn.startedAt
        case .reference(let turn):
            turn.startedAt
        }
    }

    private func priorTurnFinishedAt(_ item: AgentSessionFactualProjectionEvidenceRows.PriorTurnItem) -> Date {
        switch item {
        case .detail(let turnSnapshot):
            turnSnapshot.turn.completedAt ?? turnSnapshot.turn.updatedAt
        case .reference(let turn):
            turn.completedAt ?? turn.updatedAt
        }
    }

    private func priorTurnDurationText(_ item: AgentSessionFactualProjectionEvidenceRows.PriorTurnItem) -> String {
        guard let startedAt = priorTurnStartedAt(item) else {
            return String(localized: "agentSession.factual.unknown", defaultValue: "Unknown")
        }
        let duration = max(0, priorTurnFinishedAt(item).timeIntervalSince(startedAt))
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3_600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        if let text = formatter.string(from: duration), !text.isEmpty {
            return text
        }
        return String.localizedStringWithFormat(
            String(localized: "agentSession.factual.duration.seconds", defaultValue: "%.0f sec"),
            duration
        )
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

    private func labeledText(_ label: String, _ text: String, lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(nonEmpty(text))
                .font(.system(size: 12))
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func badge(_ text: String) -> some View {
        Text(nonEmpty(text))
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.12), in: Capsule())
    }

    private func countBadge(_ label: String, _ count: Int) -> some View {
        badge("\(label): \(count)")
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

    private func dateText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func dateText(_ date: Date?) -> String {
        guard let date else {
            return String(localized: "agentSession.factual.unknown", defaultValue: "Unknown")
        }
        return dateText(date)
    }
}
