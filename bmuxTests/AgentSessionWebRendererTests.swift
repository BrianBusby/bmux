import Foundation
import Testing

#if canImport(bmux_DEV)
    @testable import bmux_DEV
#elseif canImport(bmux)
    @testable import bmux
#endif

@Suite(.serialized)
struct AgentSessionWebRendererTests {
#if DEBUG
    @Test @MainActor
    func acceptanceDarkOverrideChangesBridgeThemeAndRestores() {
        let defaults = UserDefaults.standard
        let key = "bmux.acceptance.forceDarkAppearance"
        let coordinator = AgentSessionWebRendererCoordinator()
        let theme = AgentSessionWebTheme.resolve(appearance: .fromConfig(GhosttyConfig.load()))
        defaults.set(true, forKey: key)
        coordinator.bind(
            panelId: UUID(), workspaceId: UUID(), stableWorkspaceId: UUID(),
            workProvenanceRuntime: nil, rendererKind: .react,
            initialProviderID: .codex, workingDirectory: nil,
            theme: theme, isFocused: false
        )
        #expect(coordinator.theme.isDark)
        #expect(coordinator.theme.pageBackground == "#11130f")
        defaults.removeObject(forKey: key)
        coordinator.bind(
            panelId: UUID(), workspaceId: UUID(), stableWorkspaceId: UUID(),
            workProvenanceRuntime: nil, rendererKind: .react,
            initialProviderID: .codex, workingDirectory: nil,
            theme: theme, isFocused: false
        )
        #expect(coordinator.theme == theme)
        coordinator.close()
    }
#endif

    @Test
    func testTrustedShellURLAcceptsOnlyMatchingFileURL() {
        let resources = URL(fileURLWithPath: "/tmp/bmux DEV test.app/Contents/Resources", isDirectory: true)
        let expected = AgentSessionWebRendererCoordinator.shellURL(
            rendererKind: .react,
            resourceDirectoryURL: resources
        )
        let equivalent = resources
            .appendingPathComponent("markdown-viewer", isDirectory: true)
            .appendingPathComponent("webviews-app", isDirectory: true)
            .appendingPathComponent("..", isDirectory: true)
            .appendingPathComponent("webviews-app", isDirectory: true)
            .appendingPathComponent("agent-session.html", isDirectory: false)
        let otherBundledFile = resources
            .appendingPathComponent("markdown-viewer", isDirectory: true)
            .appendingPathComponent("webviews-app", isDirectory: true)
            .appendingPathComponent("diff-viewer.html", isDirectory: false)

        expectTrue(AgentSessionWebRendererCoordinator.isTrustedShellURL(expected, expected: expected))
        expectTrue(AgentSessionWebRendererCoordinator.isTrustedShellURL(equivalent, expected: expected))
        expectFalse(AgentSessionWebRendererCoordinator.isTrustedShellURL(otherBundledFile, expected: expected))
        expectFalse(AgentSessionWebRendererCoordinator.isTrustedShellURL(URL(string: "https://example.com"), expected: expected))
    }

    @Test @MainActor
    func terminalChatRejectsEveryProviderMutation() async throws {
        let coordinator = AgentSessionWebRendererCoordinator()
        coordinator.terminalChatSnapshot = { ["status": "unavailable"] }
        for method in ["provider.start", "provider.writeLine", "provider.stop", "provider.select", "app.pickFiles", "smartSession.snapshot"] {
            let request = try AgentSessionBridgeRequest(body: [
                "id": "request-1", "method": method,
                "params": ["providerId": "codex", "sessionId": "original", "text": "hello"]
            ])
            do {
                _ = try await coordinator.handle(request)
                Issue.record("Read-only bridge accepted a mutation: \(method)")
            } catch let error as AgentSessionBridgeError {
                #expect(error.code == AgentSessionBridgeError.unsupportedMethod(method).code)
            }
        }
        coordinator.close()
    }

    @Test @MainActor
    func terminalChatReadsAndTerminalFallbackUseOnlyInjectedOwner() async throws {
        let coordinator = AgentSessionWebRendererCoordinator()
        var reads = 0
        var terminalOpens = 0
        coordinator.terminalChatSnapshot = { reads += 1; return ["status": "observed", "sessionId": "original"] }
        coordinator.onInteractInTerminal = { terminalOpens += 1 }
        let request = try AgentSessionBridgeRequest(body: ["id": "read-1", "method": "terminalChat.snapshot"])
        let reply = try await coordinator.handle(request) as? [String: String]
        #expect(reply?["sessionId"] == "original")
        #expect(reads == 1)
        _ = try await coordinator.handle(AgentSessionBridgeRequest(body: ["id": "open-1", "method": "terminalChat.openTerminal"]))
        #expect(terminalOpens == 1)
        let providers = try await coordinator.handle(AgentSessionBridgeRequest(body: ["id": "list-1", "method": "provider.list"])) as? [Any]
        #expect(providers?.isEmpty == true)
        coordinator.close()
        #expect(terminalOpens == 1)
    }
    @Test
    func terminalChatPullReconcilesLateOutputResetAndUnreadableHistory() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("rollout.jsonl")
        func prose(_ text: String) -> String {
            "{\"type\":\"response_item\",\"timestamp\":\"2026-09-16T12:00:00Z\",\"payload\":{\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"\(text)\"}]}}\n"
        }
        try prose("First response").write(to: file, atomically: true, encoding: .utf8)
        let tailer = AgentChatTranscriptTailer(sessionID: "ordinary", agentKind: .codex, path: file.path, onBatch: { _ in })
        await tailer.start()
        // Suppress watcher delivery: a pull must reconcile the file itself.
        await tailer.stop()
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(prose("Late response").utf8))
        try handle.close()
        let late = await tailer.refreshHistory(beforeSeq: nil, limit: 500)
        #expect(late?.messages.count == 2)
        let repeated = await tailer.refreshHistory(beforeSeq: nil, limit: 500)
        #expect(repeated?.messages.map(\.id) == late?.messages.map(\.id))
        #expect(repeated?.sourceRevision == late?.sourceRevision)
        try prose("Replacement history").write(to: file, atomically: true, encoding: .utf8)
        let reset = await tailer.refreshHistory(beforeSeq: nil, limit: 500)
        #expect(reset?.messages.count == 1)
        #expect(reset?.sourceRevision != late?.sourceRevision)
        try FileManager.default.removeItem(at: file)
        let unavailable = await tailer.refreshHistory(beforeSeq: nil, limit: 500)
        #expect(unavailable == nil)
    }

}

@Suite(.serialized) @MainActor
struct ConnectedSessionBridgeTests {
    @Test func absentControlOwnerCannotAcceptAnAction() async throws {
        let coordinator = AgentSessionWebRendererCoordinator()
        coordinator.terminalChatSnapshot = { ["status": "unavailable"] }
        await #expect(throws: (any Error).self) {
            try await coordinator.handle(AgentSessionBridgeRequest(body: ["id": "action", "method": "terminalChat.action", "params": [:]]))
        }
        coordinator.close()
    }

    @Test func attachedActionOwnerDoesNotUnlockManagedProviderMutations() async throws {
        let coordinator = AgentSessionWebRendererCoordinator()
        var actions = 0
        coordinator.terminalChatSnapshot = { ["status": "observed"] }
        coordinator.terminalChatAction = { request in
            actions += 1
            return ["id": try request.requiredString("requestId"), "delivery": "accepted"]
        }
        let action = try AgentSessionBridgeRequest(body: ["id": "bridge-1", "method": "terminalChat.action", "params": ["requestId": "client-1"]])
        let result = try await coordinator.handle(action) as? [String: String]
        #expect(result?["id"] == "client-1")
        #expect(actions == 1)
        for method in ["provider.start", "provider.stop", "provider.writeLine"] {
            await #expect(throws: (any Error).self) {
                try await coordinator.handle(AgentSessionBridgeRequest(body: ["id": "forbidden", "method": method]))
            }
        }
        #expect(actions == 1)
        coordinator.close()
    }
}
