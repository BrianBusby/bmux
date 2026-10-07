import Combine
import Foundation
import Observation
import Testing

import BmuxSidebar

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

@MainActor
struct WorkspaceSidebarObservationTests {
    @Test(.timeLimit(.minutes(1))) func referenceCardsObserveRepeatedTitlesAndAgentActivity() async throws {
        let workspace = Workspace(title: "Roof inspection")
        let panelID = try #require(workspace.focusedPanelId)
        let observation = WorkspaceReferenceCardObservation(workspaces: [workspace]) {
            WorkspaceReferenceCardSnapshot(workspace: $0, provenance: nil, workspaceTitle: $0.title)
        }
        defer { observation.cancel() }
        var snapshots = observation.updates.makeAsyncIterator()
        #expect(await snapshots.next()?.first?.title == "Roof inspection")

        for title in ["Review flashing", "Compare gutter photographs"] {
            workspace.setCustomTitle(title, source: .autoSummary)
            while true {
                let cards = try #require(await snapshots.next())
                if cards.first?.title == title { break }
            }
            #expect(workspace.title == title)
        }
        workspace.setAgentLifecycle(key: "codex", panelId: panelID, lifecycle: .running)
        while true {
            let cards = try #require(await snapshots.next())
            if cards.first?.hasActiveAIWork == true { break }
        }
        workspace.setAgentLifecycle(key: "codex", panelId: panelID, lifecycle: .idle)
        while true {
            let cards = try #require(await snapshots.next())
            if cards.first?.hasActiveAIWork == false { break }
        }
        observation.cancel()
        #expect(await snapshots.next() == nil)
    }

    @Test(.timeLimit(.minutes(1))) func lateRepositoryDiscoveryUpdatesLabelsWithoutParentRefresh() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = directory.appendingPathComponent("maple-roof-inspection")
        try FileManager.default.createDirectory(at: repository.appendingPathComponent(".git"), withIntermediateDirectories: true)

        let workspace = Workspace()
        workspace.currentDirectory = ""
        let observation = WorkspaceRepositoryLabelObservation(workspaces: [workspace])
        defer { observation.cancel() }
        var labels = observation.updates.makeAsyncIterator()
        #expect(await labels.next() == [:])

        let (roots, continuation) = AsyncStream<String?>.makeStream()
        let subscription = workspace.$extensionSidebarProjectRootPath.sink { continuation.yield($0) }
        defer { subscription.cancel(); continuation.finish() }
        workspace.currentDirectory = repository.path
        for await root in roots where root == repository.path { break }

        let refreshed = try #require(await labels.next())
        #expect(refreshed[workspace.id] == "maple-roof-inspection")
    }

    @Test(.timeLimit(.minutes(1))) func repositoryLabelChangesAndClearsAsDirectoryChanges() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstRepository = directory.appendingPathComponent("maple-roof-inspection")
        let secondRepository = directory.appendingPathComponent("oak-roof-inspection")
        for repository in [firstRepository, secondRepository] {
            try FileManager.default.createDirectory(at: repository.appendingPathComponent(".git"), withIntermediateDirectories: true)
        }

        let workspace = Workspace()
        workspace.currentDirectory = ""
        let (roots, continuation) = AsyncStream<String?>.makeStream()
        let subscription = workspace.$extensionSidebarProjectRootPath.sink { continuation.yield($0) }
        defer { subscription.cancel(); continuation.finish() }
        workspace.currentDirectory = firstRepository.path
        var rootChanges = roots.makeAsyncIterator()
        while let root = await rootChanges.next(), root != firstRepository.path {}

        let observation = WorkspaceRepositoryLabelObservation(workspaces: [workspace])
        defer { observation.cancel() }
        var labels = observation.updates.makeAsyncIterator()
        #expect(await labels.next()?[workspace.id] == "maple-roof-inspection")

        workspace.currentDirectory = secondRepository.path
        while let root = await rootChanges.next(), root != secondRepository.path {}
        let changed = try #require(await labels.next())
        #expect(changed[workspace.id] == "oak-roof-inspection")

        workspace.currentDirectory = directory.path
        while let root = await rootChanges.next(), root != nil {}
        #expect(await labels.next() == [:])

        observation.cancel()
        #expect(await labels.next() == nil)
    }

    @Test func sidebarObservationPublisherEmitsForLateStatusSubscriber() {
        let workspace = Workspace()
        workspace.statusEntries["test_probe"] = SidebarStatusEntry(
            key: "test_probe",
            value: "VISIBLE?",
            icon: "star.fill",
            color: "#FF0000",
            priority: 200
        )

        var publishCount = 0
        let cancellable = workspace.sidebarObservationPublisher.sink {
            publishCount += 1
        }
        defer { cancellable.cancel() }

        #expect(
            publishCount > 0,
            "A sidebar row that subscribes after status metadata already exists must still refresh from the current workspace state."
        )
    }

    @Test func agentRuntimeObservationChangesWhenAgentPIDMakesExistingStatusVisible() throws {
        let workspace = Workspace()
        let panelId = try #require(workspace.focusedPanelId)
        workspace.statusEntries["codex"] = SidebarStatusEntry(
            key: "codex",
            value: "Running",
            icon: "bolt.fill",
            color: "#4C8DFF"
        )
        #expect(
            !workspace.sidebarStatusEntriesInDisplayOrder().contains { $0.key == "codex" },
            "Structured agent statuses stay hidden until a live agent runtime owns the status key."
        )

        let generationBeforeRecord = workspace.sidebarAgentRuntimeObservation.changeGeneration
        var workspaceWillChangeCount = 0
        let objectWillChangeCancellable = workspace.objectWillChange.sink {
            workspaceWillChangeCount += 1
        }
        defer { objectWillChangeCancellable.cancel() }

        workspace.recordAgentPID(
            key: "codex.session-b",
            pid: 12_345,
            panelId: panelId,
            refreshPorts: false
        )

        #expect(
            workspace.sidebarStatusEntriesInDisplayOrder().contains { $0.key == "codex" },
            "Recording the agent PID makes the existing Running status visible."
        )
        #expect(
            workspace.sidebarAgentRuntimeObservation.changeGeneration > generationBeforeRecord,
            "Agent PID ownership changes must notify the sidebar row runtime observation stream."
        )
        #expect(
            workspaceWillChangeCount == 0,
            "Agent PID ownership is sidebar presentation state and must not broadly invalidate Workspace observers."
        )
    }

    @Test func terminalAgentContextDoesNotObserveAgentRuntimeMaps() throws {
        let workspace = Workspace()
        let panelId = try #require(workspace.focusedPanelId)
        let panel = try #require(workspace.panels[panelId])
        let changeFlag = ObservationChangeFlag()

        withObservationTracking {
            _ = WorkspaceContentView.terminalAgentContext(panel: panel, workspace: workspace)
        } onChange: {
            changeFlag.mark()
        }

        workspace.recordAgentPID(
            key: "codex.session-c",
            pid: 12_346,
            panelId: panelId,
            refreshPorts: false
        )

        #expect(
            changeFlag.fired == false,
            "Terminal content must not subscribe to sidebar-only agent runtime map churn."
        )
    }

    @Test func sidebarImmediateObservationPublisherEmitsForLateTitleSubscriber() {
        let workspace = Workspace()
        workspace.title = "Restored Workspace"

        var publishCount = 0
        let cancellable = workspace.sidebarImmediateObservationPublisher.sink {
            publishCount += 1
        }
        defer { cancellable.cancel() }

        #expect(
            publishCount > 0,
            "A sidebar row that subscribes after immediate workspace fields already exist must still refresh from the current workspace state."
        )
    }

    @Test func sidebarImmediateObservationPublisherDeliversFirstChangeSynchronously() {
        let workspace = Workspace()

        var publishCount = 0
        let cancellable = workspace.sidebarImmediateObservationPublisher.sink {
            publishCount += 1
        }
        defer { cancellable.cancel() }
        publishCount = 0

        workspace.title = "User Edit"

        #expect(
            publishCount == 1,
            "The first immediate-field change after subscribing must reach the sidebar in the same run-loop turn; coalescing may only defer the tail of a burst."
        )
    }

    @Test func sidebarImmediateObservationPublisherLetsSubscriberReadUpdatedCustomTitleSynchronously() throws {
        let manager = TabManager()
        let workspace = try #require(manager.selectedWorkspace)

        var observedTitles: [String] = []
        let cancellable = workspace.sidebarImmediateObservationPublisher.sink {
            observedTitles.append(workspace.title)
        }
        defer { cancellable.cancel() }
        observedTitles.removeAll()

        let applied = manager.setCustomTitle(
            tabId: workspace.id,
            title: "Explain codebase workspace"
        )

        #expect(applied)
        #expect(
            observedTitles == ["Explain codebase workspace"],
            "Sidebar rows must rebuild after the workspace title is stored, not during @Published willSet while the old title is still visible."
        )
    }

    @Test func sidebarImmediateObservationPublisherReadsLatestSubmittedPromptSynchronously() {
        let workspace = Workspace()

        var observedPrompts: [String?] = []
        let cancellable = workspace.sidebarImmediateObservationPublisher.sink {
            observedPrompts.append(workspace.latestSubmittedMessage)
        }
        defer { cancellable.cancel() }
        observedPrompts.removeAll()

        #expect(workspace.recordSubmittedMessage("Explain this codebase"))

        #expect(
            observedPrompts.first == "Explain this codebase",
            "The first prompt-submit row invalidation must already expose the latest submitted message."
        )
    }

    @Test func progressMutationsPostWorkspaceDisplayMetadataNotificationsWithoutClearingCurrentWork() {
        let workspace = Workspace()
        var notificationCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .workspaceDisplayMetadataDidChange,
            object: workspace,
            queue: nil
        ) { _ in
            notificationCount += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        workspace.progress = SidebarProgressState(value: 0.4, label: "Indexing durable context")

        #expect(notificationCount == 1)
        #expect(!workspace.workspaceDisplayExplicitClearedFields.contains("current_work_summary"))

        workspace.progress = nil

        #expect(notificationCount == 2)
        #expect(!workspace.workspaceDisplayExplicitClearedFields.contains("current_work_summary"))
    }

    @Test func sidebarImmediateObservationPublisherCoalescesTitleBursts() {
        let workspace = Workspace()

        var publishCount = 0
        let cancellable = workspace.sidebarImmediateObservationPublisher.sink {
            publishCount += 1
        }
        defer { cancellable.cancel() }
        publishCount = 0

        for turn in 0..<20 {
            workspace.title = "Agent Turn \(turn)"
        }

        #expect(
            publishCount == 1,
            "A synchronous burst of distinct titles must deliver only its leading edge immediately."
        )

        // Generous pump so the 50ms trailing emission fires deterministically.
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        #expect(
            publishCount == 2,
            "A coalesced burst must settle with exactly one trailing emission carrying the latest state."
        )
    }

    @Test func coalesceLatestKeepsLeadingEdgeSynchronousAndEmitsLatestTrailing() {
        let subject = PassthroughSubject<Int, Never>()
        var received: [Int] = []
        let cancellable = subject
            .coalesceLatest(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { received.append($0) }
        defer { cancellable.cancel() }

        // First value models the @Published current-state replay: forwarded
        // synchronously without opening a coalesce window.
        subject.send(1)
        #expect(received == [1])

        // First change is the synchronous leading edge and opens the window.
        subject.send(2)
        #expect(received == [1, 2])

        // Burst inside the window coalesces to the latest value.
        subject.send(3)
        subject.send(4)
        subject.send(5)
        #expect(received == [1, 2])

        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        #expect(received == [1, 2, 5])

        // After the window closes and the trailing window expires, the next
        // value is synchronous again.
        subject.send(6)
        #expect(received == [1, 2, 5, 6])
    }

    @Test func coalesceLatestDropsStalePendingValueWhenLeadingSupersedesOverdueTrailing() {
        let scheduler = VirtualCoalesceScheduler()
        let subject = PassthroughSubject<Int, Never>()
        var received: [Int] = []
        let cancellable = subject
            .coalesceLatest(for: .milliseconds(50), scheduler: scheduler)
            .sink { received.append($0) }
        defer { cancellable.cancel() }

        subject.send(1) // replay: forwarded, no window
        subject.send(2) // leading edge: opens window
        subject.send(3) // pending trailing value for the open window
        #expect(received == [1, 2])
        #expect(scheduler.scheduledActionCount == 1)

        // The deadline passes WITHOUT the scheduled callback running,
        // modeling a stalled main run loop with an overdue timer.
        scheduler.advance(by: 0.12)
        subject.send(4) // deadline passed: new leading edge must supersede 3

        #expect(
            received == [1, 2, 4],
            "A newer leading value after an overdue deadline must drop the stale pending value."
        )

        scheduler.runScheduledActions()
        #expect(
            received == [1, 2, 4],
            "The overdue trailing callback must not emit the superseded stale value out of order."
        )
    }

    @Test func sidebarObservationPublisherIgnoresRemoteHeartbeatOnlyChanges() {
        let workspace = Workspace()

        var publishCount = 0
        let cancellable = workspace.sidebarObservationPublisher.sink {
            publishCount += 1
        }
        defer { cancellable.cancel() }
        publishCount = 0

        workspace.remoteHeartbeatCount = 1
        workspace.remoteLastHeartbeatAt = Date()

        #expect(
            publishCount == 0,
            "Expected non-visible remote heartbeat updates to avoid invalidating sidebar rows"
        )
    }
}

// Mutable flag captured by Observation's Sendable onChange closure in this test.
private final class ObservationChangeFlag: @unchecked Sendable {
    private(set) var fired = false

    func mark() {
        fired = true
    }
}

// Deterministic Combine scheduler for coalesceLatest tests: `now` only moves
// via advance(by:), and scheduled actions run only when runScheduledActions()
// is called, so overdue-timer interleavings are exact instead of wall-clock.
private final class VirtualCoalesceScheduler: Scheduler {
    typealias SchedulerTimeType = RunLoop.SchedulerTimeType
    typealias SchedulerOptions = Never

    private(set) var now = SchedulerTimeType(Date(timeIntervalSinceReferenceDate: 0))
    var minimumTolerance: SchedulerTimeType.Stride { .seconds(0) }
    private var scheduledActions: [() -> Void] = []

    var scheduledActionCount: Int { scheduledActions.count }

    func advance(by seconds: TimeInterval) {
        now = SchedulerTimeType(now.date.addingTimeInterval(seconds))
    }

    func runScheduledActions() {
        let actions = scheduledActions
        scheduledActions = []
        actions.forEach { $0() }
    }

    func schedule(options: Never?, _ action: @escaping () -> Void) {
        action()
    }

    func schedule(
        after date: SchedulerTimeType,
        tolerance: SchedulerTimeType.Stride,
        options: Never?,
        _ action: @escaping () -> Void
    ) {
        scheduledActions.append(action)
    }

    func schedule(
        after date: SchedulerTimeType,
        interval: SchedulerTimeType.Stride,
        tolerance: SchedulerTimeType.Stride,
        options: Never?,
        _ action: @escaping () -> Void
    ) -> Cancellable {
        scheduledActions.append(action)
        return AnyCancellable {}
    }
}
