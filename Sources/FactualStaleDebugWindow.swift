#if DEBUG
import AppKit
import SwiftUI
import ProvenanceEngineContracts

/// An isolated, synthetic preview of the factual projection's stale state.
final class FactualStaleDebugWindowController: ReleasingWindowController {
    static let shared = FactualStaleDebugWindowController()

    override func makeWindow() -> NSWindow {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 680),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "debug.factualStale.title", defaultValue: "Factual Session Preview — Synthetic Data")
        window.identifier = NSUserInterfaceItemIdentifier("bmux.factualStalePreview")
        window.center()
        let observedAt = Date().addingTimeInterval(-3600)
        let turn = ProvenanceCodingAgentTurnRecord(
            id: "preview-turn", sessionID: "preview-session", provider: "codex",
            providerTurnID: "preview-turn", status: "completed", startedAt: observedAt,
            completedAt: observedAt, updatedAt: observedAt, source: .observed, confidence: .high
        )
        let turnSnapshot = ProvenanceFactualSessionProjectionTurnSnapshot(
            turn: turn,
            submittedPrompt: ProvenanceCodingAgentPromptRecord(
                id: "preview-prompt", sessionID: "preview-session", turnID: turn.id, provider: "codex",
                text: String(localized: "debug.factualStale.prompt", defaultValue: "Investigate session restoration after reconnecting."),
                submittedAt: observedAt, source: .observed, confidence: .high
            ),
            currentPlan: nil, completedCommands: [], visibleReasoningSummaries: [], fileChangeAttributions: []
        )
        let snapshot = ProvenanceFactualSessionProjectionSnapshot(
            revision: 1,
            session: ProvenanceSessionRecord(
                id: "preview-session", agentKind: "codex", workspaceID: "preview-workspace",
                surfaceID: "preview-surface", worktreeID: "preview-worktree", cwd: "/projects/riverbank",
                status: "active", startedAt: observedAt, updatedAt: observedAt
            ),
            providerThreadIdentities: [], providerThreads: [], latestTurn: turnSnapshot,
            priorTurns: [], turns: [turnSnapshot]
        )
        window.contentView = NSHostingView(rootView: AgentSessionFactualProjectionView(
            result: .stale(snapshot, lastSuccessfulReadAt: observedAt),
            isLoading: false, backgroundColor: Color(nsColor: .windowBackgroundColor), onRefresh: {},
            liveTerminalContent: AnyView(
                Text(String(localized: "debug.factualStale.terminalUnavailable", defaultValue: "Terminal unavailable in this synthetic preview."))
                    .padding(.top, 20)
            ),
            workspaceLabel: String(localized: "debug.factualStale.workspace", defaultValue: "Riverbank workspace"),
            sessionTitle: String(localized: "debug.factualStale.session", defaultValue: "Session restoration"),
            sessionDescription: String(localized: "debug.factualStale.description", defaultValue: "Synthetic preview; no session data is read.")
        ))
        return window
    }

    func show() { showManagedWindow() }
}
#endif
