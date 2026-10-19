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
    private var bufferedEvents: [Event] = []
    private var pendingWait: PendingWait?
    private let registeredApp: AppDelegate?

    init(eventTimeout: Duration) throws {
        _ = NSApplication.shared
        self.eventTimeout = eventTimeout
        let ownedDefaults = try #require(UserDefaults(suiteName: suiteName))
        defaults = ownedDefaults
        defaults.set("standard", forKey: WorkspacePresentationModeSettings.modeKey)
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
                contentViewBody: { [weak self] in self?.contentViewBody += 1; self?.record(.body) },
                workspaceContentBody: { [weak self] in self?.workspaceContentBody += 1; self?.record(.body) },
                workspaceRailBody: { [weak self] in self?.workspaceRailBody += 1; self?.record(.body) }
            ))
            .background(WorkspacePresentationModeChangeObserver { [weak self] minimal in
                if minimal { self?.record(.minimal) }
            })
            .defaultAppStorage(defaults)
        window.contentView = MainWindowHostingView(rootView: root)
        window.contentView?.layoutSubtreeIfNeeded()
        try await waitForEvent(phase: .mountBodies) { [self] event in
            event == .body && contentViewBody > 0 && workspaceContentBody > 0 && workspaceRailBody > 0
        }
        try await finishCurrentTransaction(phase: .mountTransaction)
    }

    func resetCounts() {
        contentViewBody = 0
        workspaceContentBody = 0
        workspaceRailBody = 0
    }

    func switchToMinimalMode() async throws {
        defaults.set("minimal", forKey: WorkspacePresentationModeSettings.modeKey)
        try await waitForEvent(phase: .minimalMode) { $0 == .minimal }
        try await finishCurrentTransaction(phase: .minimalTransaction)
    }

    func close() {
        pendingWait?.completion.finish()
        pendingWait = nil
        bufferedEvents.removeAll()
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

    private func finishCurrentTransaction(phase: Phase) async throws {
        // AppKit's completion owns this rendering transaction, not all future SwiftUI work.
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in self?.record(.transaction) }
        window.contentView?.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        CATransaction.commit()
        CATransaction.flush()
        try await waitForEvent(phase: phase) { $0 == .transaction }
    }

    private func record(_ event: Event) {
        guard let pendingWait else {
            bufferedEvents.append(event)
            return
        }
        guard ContinuousClock.now <= pendingWait.deadline else {
            completeWait(id: pendingWait.id, result: .failed(Failure.eventTimedOut))
            return
        }
        if pendingWait.matches(event) {
            completeWait(id: pendingWait.id, result: .matched)
        }
    }

    private func completeWait(id: UUID, result: WaitResult) {
        guard let pendingWait, pendingWait.id == id else { return }
        self.pendingWait = nil
        pendingWait.completion.yield(result)
        pendingWait.completion.finish()
    }

    private func waitForEvent(phase: Phase, _ matches: @escaping @MainActor @Sendable (Event) -> Bool) async throws {
        let started = ContinuousClock.now
        let deadline = started.advanced(by: eventTimeout)
        let id = UUID()
        let (results, completion) = AsyncStream<WaitResult>.makeStream(bufferingPolicy: .bufferingNewest(1))
        pendingWait = PendingWait(id: id, deadline: deadline, matches: matches, completion: completion)
        defer {
            if pendingWait?.id == id { pendingWait = nil }
            completion.finish()
        }
        // Preserve FIFO consumption, evaluating queued events once against current counts.
        let queued = bufferedEvents
        bufferedEvents.removeAll()
        for event in queued { record(event) }
        do {
            let result = try await withThrowingTaskGroup(of: Void.self) { group in
                defer { group.cancelAll() }
                group.addTask { [weak self] in
                    do {
                        // Injected failure containment for native observations, never settling.
                        try await ContinuousClock().sleep(until: deadline)
                        await self?.completeWait(id: id, result: .failed(Failure.eventTimedOut))
                    } catch {
                        await self?.completeWait(id: id, result: .failed(error))
                    }
                }
                for await result in results { return result }
                throw CancellationError()
            }
            try Task.checkCancellation()
            switch result {
            case .matched: return
            case .failed(let error): throw error
            }
        } catch Failure.eventTimedOut {
            throw PhaseTimeout(
                phase: phase, elapsed: started.duration(to: .now),
                contentBodies: contentViewBody, workspaceBodies: workspaceContentBody,
                railBodies: workspaceRailBody,
                registered: registeredApp?.mainWindowContexts[ObjectIdentifier(window)] != nil
            )
        }
    }

    private struct PendingWait {
        let id: UUID
        let deadline: ContinuousClock.Instant
        let matches: @MainActor @Sendable (Event) -> Bool
        let completion: AsyncStream<WaitResult>.Continuation
    }

    private enum WaitResult { case matched, failed(any Error) }

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
    private enum Phase: String { case mountBodies, mountTransaction, minimalMode, minimalTransaction }

    private struct PhaseTimeout: Error, CustomStringConvertible {
        let phase: Phase
        let elapsed: Duration
        let contentBodies: Int
        let workspaceBodies: Int
        let railBodies: Int
        let registered: Bool

        var description: String {
            "minimal_mode_event_timeout phase=\(phase.rawValue) elapsed=\(elapsed) "
                + "content_bodies=\(contentBodies) workspace_bodies=\(workspaceBodies) "
                + "rail_bodies=\(railBodies) registered=\(registered)"
        }
    }
}
