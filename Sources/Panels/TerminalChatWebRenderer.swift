import AppKit
import SwiftUI

/// Retains the styled consumer on the terminal panel; it never owns the PTY.
struct TerminalChatWebRenderer: NSViewRepresentable {
    let panel: TerminalPanel
    let reader: any TerminalChatReading
    let appearance: PanelAppearance
    var onStartConnectedSession: (() async throws -> Void)? = nil
    let onRequestPanelFocus: () -> Void
    let onTerminal: () -> Void

    func makeCoordinator() -> AgentSessionWebRendererCoordinator { panel.presentation.chatRenderer }

    func makeNSView(context: Context) -> AgentSessionWebHostView {
        AgentSessionWebHostView()
    }

    func updateNSView(_ host: AgentSessionWebHostView, context: Context) {
        panel.isChatPresentationActive = true
        let coordinator = context.coordinator
        coordinator.terminalChatSnapshot = { [weak reader, weak panel] in
            guard let reader, let panel else { return ["status": "unavailable"] }
            return await reader.terminalChatSnapshot(workspaceID: panel.workspaceId, surfaceID: panel.id)
        }
        coordinator.terminalChatRawOutput = { [weak reader, weak panel] sessionID, messageID in
            guard let reader, let panel else { return nil }
            return try await reader.terminalChatRawOutput(
                workspaceID: panel.workspaceId, surfaceID: panel.id, sessionID: sessionID, messageID: messageID
            )
        }
        coordinator.onStartConnectedSession = onStartConnectedSession
        coordinator.terminalChatDraft = { [weak reader, weak panel] request in
            guard let runtime = reader as? any TerminalChatConnecting, let panel,
                  let revision = UUID(uuidString: try request.requiredString("draftRevision")),
                  let text = request.params["text"] as? String else { throw AgentSessionBridgeError.invalidRequest }
            try runtime.updateConnectedDraft(workspaceID: panel.workspaceId, surfaceID: panel.id,
                sessionID: request.requiredString("sessionId"), revision: revision, text: text)
        }
        coordinator.terminalChatAction = { [weak reader, weak panel] request in
            guard let runtime = reader as? any TerminalChatConnecting, let panel,
                  let requestID = UUID(uuidString: try request.requiredString("requestId")) else {
                throw AgentSessionBridgeError.invalidRequest
            }
            guard let draftRevision = UUID(uuidString: try request.requiredString("draftRevision")) else { throw AgentSessionBridgeError.invalidRequest }
            return try await runtime.performConnectedAction(workspaceID: panel.workspaceId, surfaceID: panel.id,
                sessionID: request.requiredString("sessionId"), requestID: requestID,
                draftRevision: draftRevision,
                text: request.params["text"] as? String ?? "", expectedTurnID: request.params["expectedTurnId"] as? String)
        }
        coordinator.onInteractInTerminal = onTerminal
        coordinator.bind(
            panelId: panel.id, workspaceId: panel.workspaceId, stableWorkspaceId: panel.workspaceId,
            workProvenanceRuntime: nil, rendererKind: .react, initialProviderID: .codex,
            workingDirectory: nil, theme: .resolve(appearance: appearance), isFocused: false
        )
        // The surrounding pane's SwiftUI tap gesture can reassert terminal
        // focus after WebKit handles mouseDown. Reclaim panel/WebKit focus on
        // the following runloop turn, after that gesture has completed.
        let webView = coordinator.ensureWebView(onPointerDown: {})
        webView.onPointerDown = {}
        webView.onPointerUp = { [weak coordinator] in
            DispatchQueue.main.async {
                onRequestPanelFocus()
                coordinator?.focus()
            }
        }
        webView.underPageBackgroundColor = appearance.contentBackgroundColor
        host.attachWebView(webView)
        host.onDidMoveToWindow = { [weak coordinator] in coordinator?.loadShellIfNeeded() }
        host.onGeometryChanged = { [weak coordinator] in coordinator?.flushVisiblePaintIfReady() }
        coordinator.loadShellIfNeeded()
    }

    static func dismantleNSView(_ host: AgentSessionWebHostView, coordinator: AgentSessionWebRendererCoordinator) {
        host.detachHostedWebViewIfOwned(coordinator.webView)
        host.onDidMoveToWindow = nil
        host.onGeometryChanged = nil
    }
}
