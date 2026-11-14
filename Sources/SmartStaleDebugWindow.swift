#if DEBUG
import AppKit
import ProvenanceEngineContracts
import WebKit

/// A bridge-backed preview using only synthetic, in-memory session data.
@MainActor
final class SmartStaleDebugWindowController: ReleasingWindowController {
    static let shared = SmartStaleDebugWindowController()
    private var coordinator: AgentSessionWebRendererCoordinator?

    override func makeWindow() -> NSWindow {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 720),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("bmux.smartStalePreview")
        window.title = String(localized: "debug.smartStale.title", defaultValue: "Smart Session Preview — Synthetic Data")
        let coordinator = AgentSessionWebRendererCoordinator()
        coordinator.debugSmartStaleFixture = Self.fixture()
        coordinator.bind(
            panelId: UUID(), workspaceId: UUID(), stableWorkspaceId: UUID(),
            workProvenanceRuntime: nil, rendererKind: .react, initialProviderID: .codex,
            workingDirectory: "/projects/riverbank", theme: coordinator.theme, isFocused: false
        )
        let webView = coordinator.ensureWebView(onPointerDown: {})
        let label = NSTextField(labelWithString: String(
            localized: "debug.smartStale.description",
            defaultValue: "Synthetic preview. Select Focus; Refresh returns the same stale sample."
        ))
        label.lineBreakMode = .byWordWrapping
        let container = NSView()
        label.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 10),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        window.contentView = container
        self.coordinator = coordinator
        return window
    }

    override func managedWindowWillClose(_ window: NSWindow) {
        coordinator?.close()
        coordinator = nil
    }

    func show() { showManagedWindow() }

    static func fixture() -> AgentSessionSmartSessionReadResult {
        let time = Date().addingTimeInterval(-3600)
        let session = ProvenanceSessionRecord(
            id: "synthetic-session", agentKind: "codex", workspaceID: "synthetic-workspace",
            surfaceID: nil, worktreeID: nil, cwd: "/projects/riverbank", status: "active",
            startedAt: time, updatedAt: time
        )
        let turn = ProvenanceCodingAgentTurnRecord(
            id: "synthetic-turn", sessionID: session.id, provider: "codex", providerTurnID: "synthetic-turn",
            status: "completed", startedAt: time, completedAt: time, updatedAt: time,
            source: .observed, confidence: .high
        )
        let prompt = ProvenanceCodingAgentPromptRecord(
            id: "synthetic-prompt", sessionID: session.id, turnID: turn.id, provider: "codex",
            text: String(localized: "debug.smartStale.prompt", defaultValue: "Investigate session restoration after reconnecting."),
            submittedAt: time, source: .observed, confidence: .high
        )
        let turnSnapshot = ProvenanceFactualSessionProjectionTurnSnapshot(
            turn: turn, submittedPrompt: prompt, currentPlan: nil, completedCommands: [],
            visibleReasoningSummaries: [], fileChangeAttributions: []
        )
        let factual = ProvenanceFactualSessionProjectionSnapshot(
            revision: 1, session: session, providerThreads: [], latestTurn: turnSnapshot, turns: [turnSnapshot]
        )
        let intent = ProvenanceSessionWorkModelSemanticField(
            kind: ProvenanceCodingAgentSemanticInferenceKind.turnIntent.rawValue,
            scope: .turn, scopeID: turn.id, state: .unknown, reason: "synthetic_preview"
        )
        let activity = ProvenanceSessionWorkModelSemanticField(
            kind: ProvenanceCodingAgentSemanticInferenceKind.currentActivity.rawValue,
            scope: .turn, scopeID: turn.id, state: .unknown, reason: "synthetic_preview"
        )
        let model = ProvenanceSessionWorkModel(
            revision: ProvenanceSessionWorkModelRevision(factualRevision: 1, semanticInferenceIDs: [], latestSemanticInferenceCreatedAt: nil),
            identity: ProvenanceSessionWorkModelIdentity(session: session, providerThreadIdentities: []),
            thread: nil,
            currentTurn: ProvenanceSessionWorkModelCurrentTurn(
                turn: turn, prompt: prompt, plan: nil, completedCommands: [], visibleReasoningSummaries: [],
                fileChangeAttributions: [], intent: intent, currentActivity: activity
            ),
            priorTurns: [],
            sessionPhase: ProvenanceSessionWorkModelSemanticField(
                kind: ProvenanceCodingAgentSemanticInferenceKind.sessionPhase.rawValue,
                scope: .session, scopeID: session.id, state: .unknown, reason: "synthetic_preview"
            ),
            basis: ProvenanceSessionWorkModelBasis(factualSessionProjection: factual, semanticInferenceRecords: [])
        )
        return .stale(AgentSessionSmartSessionSnapshot(workModel: model, semanticMessages: [], semanticMessagesReadStatus: "unavailable"), lastSuccessfulReadAt: time)
    }
}
#endif
