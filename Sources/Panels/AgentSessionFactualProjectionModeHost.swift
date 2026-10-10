import AppKit
import SwiftUI

private let agentSessionFactualProjectionAutoRefreshNanoseconds: UInt64 = 2_000_000_000

struct AgentSessionFactualProjectionModeHost<PrimaryContent: View>: View {
    let showsSwitcher: Bool
    var showsModePicker = true
    var initialPrimaryTab: AgentSessionFactualProjectionMode?
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
            if initialPrimaryTab != nil {
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
                    initialPrimaryTab: initialPrimaryTab ?? .session,
                    stableWorkspaceID: stableWorkspaceID,
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
