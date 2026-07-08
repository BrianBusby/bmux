import Foundation
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@Suite struct BmuxAgentChatConfigTests {

    @MainActor
    private func withBrowserDisabled(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: BrowserAvailabilitySettings.disabledKey) as? Bool
        let hadPrevious = defaults.object(forKey: BrowserAvailabilitySettings.disabledKey) != nil
        BrowserAvailabilitySettings.setDisabled(true)
        defer {
            if hadPrevious, let previous {
                BrowserAvailabilitySettings.setDisabled(previous)
            } else {
                defaults.removeObject(forKey: BrowserAvailabilitySettings.disabledKey)
                NotificationCenter.default.post(name: BrowserAvailabilitySettings.didChangeNotification, object: nil)
            }
        }
        try body()
    }

    private func decode(_ json: String) throws -> BmuxConfigFile {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(BmuxConfigFile.self, from: data)
    }

    @Test func decodeAgentChatConfigTrimsURLAndStartCommand() throws {
        let json = """
        {
          "agentChat": {
            "url": "  http://127.0.0.1:8777/chat  ",
            "startCommand": "  bmux-chat --port 8777  "
          }
        }
        """
        let config = try decode(json)
        #expect(config.agentChat?.url == "http://127.0.0.1:8777/chat")
        #expect(config.agentChat?.startCommand == "bmux-chat --port 8777")
        let resolved = BmuxAgentChatConfiguration.resolved(local: config.agentChat, global: nil)
        #expect(resolved.healthURL.absoluteString == "http://127.0.0.1:8777/healthz")
    }

    @Test func decodeAgentChatRejectsBlankAndNonHTTPURL() {
        #expect(throws: (any Error).self) {
            try decode("""
        {
          "agentChat": {
            "url": "   "
          }
        }
        """)
        }
        #expect(throws: (any Error).self) {
            try decode("""
        {
          "agentChat": {
            "url": "file:///tmp/chat"
          }
        }
        """)
        }
        #expect(throws: (any Error).self) {
            try decode("""
        {
          "agentChat": {
            "startCommand": "   "
          }
        }
        """)
        }
    }

    @Test func resolveLocalURLOnlyDoesNotInheritGlobalStartCommand() {
        let localPath = "/repo/bmux.json"
        let globalPath = "/Users/me/.config/bmux/bmux.json"
        let resolved = BmuxAgentChatConfiguration.resolved(
            local: BmuxAgentChatConfigDefinition(url: "http://127.0.0.1:9010"),
            global: BmuxAgentChatConfigDefinition(
                url: "http://127.0.0.1:9000",
                startCommand: "bmux-chat --port 9000"
            ),
            localSourcePath: localPath,
            globalSourcePath: globalPath
        )

        #expect(resolved.url.absoluteString == "http://127.0.0.1:9010")
        #expect(resolved.startCommand == nil)
        #expect(resolved.source == .local(path: localPath))
        #expect(resolved.source.sourcePath == localPath)
        #expect(!resolved.startCommandRequiresTrust)
    }

    @Test func resolveLocalSidecarOnlyFieldsUseGlobalServerConfig() throws {
        let localPath = "/repo/bmux.json"
        let globalPath = "/Users/me/.config/bmux/bmux.json"
        let localConfig = try decode("""
        {
          "agentChat": {
            "fontSize": 14,
            "keymap": "vim"
          }
        }
        """)
        let resolved = BmuxAgentChatConfiguration.resolved(
            local: localConfig.agentChat,
            global: BmuxAgentChatConfigDefinition(
                url: "http://127.0.0.1:9000",
                startCommand: "bmux-chat --port 9000"
            ),
            localSourcePath: localPath,
            globalSourcePath: globalPath
        )

        #expect(resolved.url.absoluteString == "http://127.0.0.1:9000")
        #expect(resolved.startCommand == "bmux-chat --port 9000")
        #expect(resolved.source == .global(path: globalPath))
        #expect(!resolved.startCommandRequiresTrust)
    }

    @Test func resolveLocalStartCommandOnlyUsesDefaultURL() {
        let localPath = "/repo/bmux.json"
        let resolved = BmuxAgentChatConfiguration.resolved(
            local: BmuxAgentChatConfigDefinition(startCommand: "bmux-chat --port 9010"),
            global: BmuxAgentChatConfigDefinition(
                url: "http://127.0.0.1:9000",
                startCommand: "bmux-chat --port 9000"
            ),
            localSourcePath: localPath,
            globalSourcePath: "/Users/me/.config/bmux/bmux.json"
        )

        #expect(resolved.url.absoluteString == BmuxAgentChatConfiguration.defaultURLString)
        #expect(resolved.startCommand == "bmux-chat --port 9010")
        #expect(resolved.source == .local(path: localPath))
        #expect(resolved.startCommandRequiresTrust)
    }

    @Test func resolveNoLocalUsesGlobalBlock() {
        let globalPath = "/Users/me/.config/bmux/bmux.json"
        let resolved = BmuxAgentChatConfiguration.resolved(
            local: nil,
            global: BmuxAgentChatConfigDefinition(
                url: "http://127.0.0.1:9000",
                startCommand: "bmux-chat --port 9000"
            ),
            localSourcePath: nil,
            globalSourcePath: globalPath
        )

        #expect(resolved.url.absoluteString == "http://127.0.0.1:9000")
        #expect(resolved.startCommand == "bmux-chat --port 9000")
        #expect(resolved.source == .global(path: globalPath))
        #expect(!resolved.startCommandRequiresTrust)
    }

    @Test func resolveNeitherUsesDefaultBlock() {
        let resolved = BmuxAgentChatConfiguration.resolved(local: nil, global: nil)

        #expect(resolved.url.absoluteString == BmuxAgentChatConfiguration.defaultURLString)
        #expect(resolved.startCommand == nil)
        #expect(resolved.source == .defaults)
        #expect(resolved.source.sourcePath == nil)
        #expect(!resolved.startCommandRequiresTrust)
    }

    @Test func newAgentChatInFlightGateRejectsDuplicatesUntilCleared() {
        let firstBegin = AgentChatActionInFlightGate.begin()
        #expect(firstBegin)
        guard firstBegin else { return }

        #expect(!AgentChatActionInFlightGate.begin())
        AgentChatActionInFlightGate.end()

        let secondBegin = AgentChatActionInFlightGate.begin()
        #expect(secondBegin)
        if secondBegin {
            AgentChatActionInFlightGate.end()
        }
    }

    @MainActor
    @Test func performNewAgentChatActionRejectsWhenBrowserSurfacesAreDisabled() throws {
        try withBrowserDisabled {
            let didStart = AppDelegate().performNewAgentChatAction(
                tabManager: TabManager(),
                agentChat: .default,
                globalConfigPath: nil,
                preferredWindow: nil
            )

            #expect(!didStart)
        }
    }
}
