import AppKit
import Bonsplit
import Observation
import BmuxAgentChat
import Foundation
import Testing
#if canImport(bmux_DEV)
@testable import bmux_DEV
#else
@testable import bmux
#endif

@Suite(.serialized) @MainActor
struct ConfiguredCodexLaunchTests {
    @Test(arguments: [
        (#"codex --add-dir 'Maple Street'"#, ["--add-dir", "Maple Street"]),
        (#"codex --add-dir "a\q""#, ["--add-dir", #"a\q"#]),
        (#"codex --config '--model'"#, ["--config", "--model"]),
        (#"codex --config --config"#, ["--config", "--config"]),
        (#"codex --model=hidden-valid --sandbox read-only"#, ["--model", "hidden-valid", "--sandbox", "read-only"])
    ])
    func literalArgumentsRetainTheirValues(command: String, expected: [String]) throws {
        let configuration = try #require(ConnectedCodexLaunchConfiguration(command: command, environment: [:]))
        #expect(configuration.arguments == expected)
        if expected.first == "--config" {
            #expect(configuration.hostArguments == expected)
            #expect(!configuration.hasExplicitModel)
        }
    }

    @Test(arguments: ["codex resume existing", "codex && echo x", "codex --remote ws://127.0.0.1:1",
        "codex --model $CHOICE", "codex --sandbox", "codex --add-dir 'unterminated", "codex\necho x"])
    func otherShellCommandsStayOrdinary(command: String) {
        #expect(ConnectedCodexLaunchConfiguration(command: command, environment: [:]) == nil)
    }

    @Test func customExecutableAndExplicitConfigModelArePreserved() throws {
        #expect(ConnectedCodexLaunchConfiguration(command: "codex", environment: ["PATH": "/custom/bin"]) == nil)
        let configuration = try #require(ConnectedCodexLaunchConfiguration(command: #"codex -c 'model="chosen-model"'"#, environment: [:]))
        #expect(configuration.hasExplicitModel)
        #expect(configuration.hostArguments == ["--config", #"model="chosen-model""#])
    }

    @Test func workspaceSetupDoesNotBecomeAConnectedLaunch() throws {
        var launches = 0
        let runtime = TerminalChatRuntime(reader: ConnectedCodexFixtureReader(),
            hosts: ConnectedCodexFixtureHost(connection: CodexRPCConnection(transport: ConnectedCodexFixtureTransport()),
                beforeLaunch: { launches += 1 }), bind: { _, _, _, _ in })
        let manager = TabManager(initialWorkingDirectory: "/tmp", autoWelcomeIfNeeded: false)
        manager.terminalChatReader = runtime
        defer { for workspace in manager.tabs { for panel in workspace.panels.values { panel.close() } } }
        for surfaceCommand in [nil, "codex"] as [String?] {
            let definition = BmuxWorkspaceDefinition(name: "Roof Inspection", cwd: "/tmp", setup: "codex",
                layout: .pane(BmuxPaneDefinition(surfaces: [BmuxSurfaceDefinition(type: .terminal, command: surfaceCommand)])))
            #expect(BmuxConfigExecutor.executeWorkspaceCommand(command: .init(name: "Roof Inspection", workspace: definition),
                workspace: definition, tabManager: manager, baseCwd: "/tmp"))
            let panel = try #require(manager.selectedWorkspace?.focusedTerminalPanel)
            #expect(panel.presentation.configuredCodexLaunch == nil)
        }
        #expect(launches == 0)
    }

    @Test(arguments: [BmuxConfigTerminalCommandTarget.newTabInCurrentPane, .currentTerminal])
    func configuredAgentActionsRespectTheirTerminalTarget(target: BmuxConfigTerminalCommandTarget) throws {
        let manager = TabManager(initialWorkingDirectory: "/tmp", autoWelcomeIfNeeded: false)
        manager.terminalChatReader = TerminalChatRuntime(reader: ConnectedCodexFixtureReader(),
            hosts: ConnectedCodexFixtureHost(connection: CodexRPCConnection(transport: ConnectedCodexFixtureTransport())),
            bind: { _, _, _, _ in })
        let workspace = try #require(manager.selectedWorkspace)
        let original = try #require(workspace.focusedTerminalPanel)
        defer { for panel in workspace.panels.values { panel.close() } }
        let action = BmuxResolvedConfigAction(id: "inspect-roof", title: "Roof Inspection", subtitle: nil,
            keywords: [], palette: true, shortcut: nil, icon: nil, tooltip: nil,
            action: .agent(.codex, args: "--sandbox read-only"), confirm: false,
            terminalCommandTarget: target, actionSourcePath: nil, iconSourcePath: nil, newWorkspaceMenu: nil)
        #expect(BmuxConfigExecutor.execute(action: action, commands: [], commandSourcePaths: [:],
            tabManager: manager, baseCwd: "/tmp", globalConfigPath: "/isolated/bmux.json"))
        let selected = try #require(workspace.focusedTerminalPanel)
        if target == .currentTerminal {
            #expect(selected === original)
            #expect(selected.presentation.configuredCodexLaunch == nil)
            #expect(workspace.panels.count == 1)
        } else {
            #expect(selected !== original)
            #expect(selected.presentation.configuredCodexLaunch?.isStarting == true)
            #expect(workspace.panels.count == 2)
        }
    }

    @Test func configuredStartupIsReservedAndClosingItsSourceRollsBack() async throws {
        let entered = AsyncStream<Void>.makeStream()
        let ended = AsyncStream<UUID>.makeStream()
        var release: CheckedContinuation<Void, Never>?
        var launches = 0
        let runtime = TerminalChatRuntime(reader: ConnectedCodexFixtureReader(),
            hosts: ConnectedCodexFixtureHost(connection: CodexRPCConnection(transport: ConnectedCodexFixtureTransport()), beforeLaunch: {
                launches += 1
                await withCheckedContinuation { continuation in
                    release = continuation
                    entered.continuation.yield(())
                }
            }, onEnd: { ended.continuation.yield($0) }), bind: { _, _, _, _ in })
        let manager = TabManager(initialWorkingDirectory: "/tmp", autoWelcomeIfNeeded: false)
        manager.terminalChatReader = runtime
        let workspace = try #require(manager.selectedWorkspace)
        let source = try #require(workspace.focusedTerminalPanel)
        workspace.sendConfiguredTerminalInput("codex\n", to: source, workingDirectory: "/tmp")
        var iterator = entered.stream.makeAsyncIterator()
        _ = await iterator.next()
        #expect(source.presentation.configuredCodexLaunch?.isStarting == true)
        source.isChatPresentationActive = true
        await #expect(throws: CodexControlError.duplicateRequest) { try await workspace.startConnectedCodex(from: source.id) }
        #expect(launches == 1)
        source.close()
        release?.resume()
        var endIterator = ended.stream.makeAsyncIterator()
        let endedSurface = await endIterator.next()
        #expect(endedSurface != nil)
        #expect(endedSurface == source.id)
        #expect(workspace.panels.count == 1)
        entered.continuation.finish()
        ended.continuation.finish()
    }
    @Test(arguments: [NewTabPosition.current, .end], [WorkspaceLayoutMode.splits, .canvas])
    func replacementPreservesTabAndCanvasOwnership(position: NewTabPosition, layout: WorkspaceLayoutMode) async throws {
        let entered = AsyncStream<Void>.makeStream()
        let finished = AsyncStream<Void>.makeStream()
        var release: CheckedContinuation<Void, Never>?
        let runtime = TerminalChatRuntime(reader: ConnectedCodexFixtureReader(),
            hosts: ConnectedCodexFixtureHost(connection: CodexRPCConnection(transport: ConnectedCodexFixtureTransport()), beforeLaunch: {
                await withCheckedContinuation { continuation in
                    release = continuation
                    entered.continuation.yield(())
                }
            }), bind: { _, _, _, _ in })
        let manager = TabManager(initialWorkingDirectory: "/tmp", autoWelcomeIfNeeded: false)
        manager.terminalChatReader = runtime
        let workspace = try #require(manager.selectedWorkspace)
        let source = try #require(workspace.focusedTerminalPanel)
        defer {
            entered.continuation.finish(); finished.continuation.finish()
            for panel in workspace.panels.values { panel.close() }
        }
        let pane = try #require(workspace.paneId(forPanelId: source.id))
        var settings = workspace.bonsplitController.configuration
        settings.newTabPosition = position
        workspace.bonsplitController.configuration = settings
        workspace.setLayoutMode(layout)
        let sibling = try #require(workspace.newTerminalSurfaceInFocusedPane(focus: true))
        workspace.focusPanel(source.id)
        source.isChatPresentationActive = true
        workspace.sendConfiguredTerminalInput("codex\n", to: source, workingDirectory: "/tmp")
        let coordinator = try #require(source.presentation.configuredCodexLaunch)
        var enteredIterator = entered.stream.makeAsyncIterator()
        _ = await enteredIterator.next()
        // The user can navigate elsewhere while preparation is suspended.
        workspace.focusPanel(sibling.id)
        let tabOrder = workspace.bonsplitController.tabs(inPane: pane).map(\.id)
        let selectedTab = workspace.bonsplitController.selectedTab(inPane: pane)?.id
        let canvasPanes = workspace.canvasModel.persistablePanes.map(\.panelIds)
        withObservationTracking { _ = coordinator.isStarting } onChange: { finished.continuation.yield(()) }
        release?.resume()
        var finishedIterator = finished.stream.makeAsyncIterator()
        _ = await finishedIterator.next()
        let replacement = try #require(workspace.terminalPanel(for: source.id))
        #expect(replacement !== source)
        #expect(replacement.id == source.id)
        #expect(replacement.surface.debugWaitAfterCommand())
        #expect(replacement.presentation.chatRenderer === source.presentation.chatRenderer)
        #expect(replacement.isChatPresentationActive)
        #expect(workspace.bonsplitController.tabs(inPane: pane).map(\.id) == tabOrder)
        #expect(workspace.bonsplitController.selectedTab(inPane: pane)?.id == selectedTab)
        #expect(workspace.focusedPanelId == sibling.id)
        #expect(workspace.canvasModel.persistablePanes.map(\.panelIds) == canvasPanes)
    }

}
