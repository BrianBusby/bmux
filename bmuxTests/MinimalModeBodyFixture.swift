import AppKit
import BmuxTerminal
import BmuxUpdater
import GhosttyKit
import QuartzCore
import SwiftUI
import Testing

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Owns the current terminal/rail composition and observations of native render transactions.
@MainActor
final class MinimalModeBodyFixture {
    private(set) var contentViewBody = 0
    private(set) var workspaceContentBody = 0
    private(set) var workspaceRailBody = 0
    private let defaults: UserDefaults
    private let suiteName = "MinimalModeBodyFixture.\(UUID())"
    private let windowID = UUID()
    private let window: NSWindow
    private let manager: TabManager
    private let eventTimeout: Duration
    private let events: AsyncStream<Event>
    private let signal: AsyncStream<Event>.Continuation
    private let registeredApp: AppDelegate?

    init(eventTimeout: Duration) throws {
        _ = NSApplication.shared
        self.eventTimeout = eventTimeout
        let ownedDefaults = try #require(UserDefaults(suiteName: suiteName))
        defaults = ownedDefaults
        defaults.set("standard", forKey: WorkspacePresentationModeSettings.modeKey)
        (events, signal) = AsyncStream.makeStream()
        registeredApp = AppDelegate.shared
        manager = TabManager(autoWelcomeIfNeeded: false)
        manager.tabs.forEach { $0.teardownAllPanels() }
        manager.tabs = (0..<7).map { Self.workspace(index: $0, defaults: ownedDefaults) }
        manager.selectedTabId = manager.tabs[0].id
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
    }

    func mount() async throws {
        let notifications = TerminalNotificationStore.shared
        let root = ContentView(updateViewModel: UpdateStateModel(), windowId: windowID, initialPrimaryTab: .terminal, titlebarDefaults: defaults)
            .environmentObject(manager)
            .environmentObject(notifications)
            .environmentObject(notifications.sidebarUnread)
            .environmentObject(SidebarState())
            .environmentObject(SidebarSelectionState())
            .environmentObject(FileExplorerState())
            .environmentObject(BmuxConfigStore(startFileWatchers: false))
            .environment(\.minimalModeInvalidationProbe, MinimalModeInvalidationProbe(
                contentViewBody: { [weak self] in self?.contentViewBody += 1; self?.signal.yield(.body) },
                workspaceContentBody: { [weak self] in self?.workspaceContentBody += 1; self?.signal.yield(.body) },
                workspaceRailBody: { [weak self] in self?.workspaceRailBody += 1; self?.signal.yield(.body) }
            ))
            .background(WorkspacePresentationModeChangeObserver { [weak self] minimal in
                if minimal { self?.signal.yield(.minimal) }
            })
            .defaultAppStorage(defaults)
        window.contentView = MainWindowHostingView(rootView: root)
        window.contentView?.layoutSubtreeIfNeeded()
        try await waitForEvent { [self] event in
            event == .body && contentViewBody > 0 && workspaceContentBody > 0 && workspaceRailBody > 0
        }
        try await finishCurrentTransaction()
    }

    func resetCounts() {
        contentViewBody = 0
        workspaceContentBody = 0
        workspaceRailBody = 0
    }

    func switchToMinimalMode() async throws {
        defaults.set("minimal", forKey: WorkspacePresentationModeSettings.modeKey)
        try await waitForEvent { $0 == .minimal }
        try await finishCurrentTransaction()
    }

    func close() {
        signal.finish()
        window.contentView = nil
        // Remove only this fixture's registration before close can persist window history.
        registeredApp?.unregisterMainWindowContextForTesting(windowId: windowID)
        manager.sidebarGitMetadataService.stopSidebarGitMetadataObservation()
        manager.tabs.forEach { $0.teardownAllPanels() }
        manager.tabs = []
        manager.window = nil
        window.close()
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func finishCurrentTransaction() async throws {
        // AppKit's completion owns this rendering transaction, not all future SwiftUI work.
        CATransaction.begin()
        CATransaction.setCompletionBlock { [signal] in signal.yield(.transaction) }
        window.contentView?.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        CATransaction.commit()
        CATransaction.flush()
        try await waitForEvent { $0 == .transaction }
    }

    private func waitForEvent(_ matches: @escaping @MainActor (Event) -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: eventTimeout)
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask { @MainActor [events] in
                for await event in events { if matches(event) { return } }
                throw CancellationError()
            }
            group.addTask {
                // Injected failure containment for actual body/mode/transaction events, never settling.
                try await ContinuousClock().sleep(until: deadline)
                throw Failure.eventTimedOut
            }
            _ = try await group.next()
        }
        try Task.checkCancellation()
    }

    private static func workspace(index: Int, defaults: UserDefaults) -> Workspace {
        let surface = TerminalSurface(
            tabId: UUID(), context: GHOSTTY_SURFACE_CONTEXT_SPLIT, configTemplate: nil,
            workingDirectory: nil, manualIO: true, manualInputHandler: { _ in }
        )
        let panel = TerminalPanel(workspaceId: surface.tabId, surface: surface)
        let transfer = Workspace.DetachedSurfaceTransfer(
            sourceWorkspaceId: surface.tabId, panelId: panel.id, panel: panel,
            title: panel.displayTitle, icon: panel.displayIcon, iconImageData: nil,
            kind: "terminal", isLoading: false, isPinned: false,
            directory: nil, directoryIsTrustedRemoteReport: false, directoryDisplayLabel: nil,
            ttyName: nil, cachedTitle: nil, customTitle: nil, customTitleSource: nil,
            manuallyUnread: false, restoredUnreadIndicator: nil, restorableAgent: nil,
            restorableAgentResumeState: nil, restoredResumeSessionWorkingDirectory: nil,
            resumeBinding: nil, agentRuntime: nil, isRemoteTerminal: false,
            remoteRelayPort: nil, remotePTYSessionID: nil, remoteCleanupConfiguration: nil
        )
        return Workspace(
            title: "Workspace \(index)", closeTabWarningDefaults: defaults,
            agentSessionAutoResumeDefaults: defaults, initialDetachedSurface: transfer
        )
    }

    private enum Event { case body, minimal, transaction }
    private enum Failure: Error { case eventTimedOut }
}
