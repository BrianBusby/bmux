import Foundation
import Bonsplit

#if canImport(bmux_DEV)
@testable import bmux_DEV
#elseif canImport(bmux)
@testable import bmux
#endif

/// Captures history at the completed close boundary, before another test can clear it.
@MainActor
final class ClosedTabHistoryObservation: BonsplitDelegate {
    struct Entry: Sendable {
        let title: String
        let detail: String
    }

    private enum Failure: Error { case timedOut, missingCompletion }
    private let delegate: any BonsplitDelegate
    private let expectedTabID: TabID
    private let completion = AsyncStream<Entry?>.makeStream(bufferingPolicy: .bufferingNewest(1))

    init(delegate: any BonsplitDelegate, expectedTabID: TabID) {
        self.delegate = delegate
        self.expectedTabID = expectedTabID
    }

    func finish() {
        completion.continuation.finish()
    }

    func waitForClosedHistory() async throws -> Entry? {
        let events = completion.stream
        return try await withThrowingTaskGroup(of: Entry?.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await entry in events { return entry }
                try Task.checkCancellation()
                throw Failure.missingCompletion
            }
            group.addTask {
                // Preserve the original ten-second failure deadline without polling.
                try await ContinuousClock().sleep(for: .seconds(10))
                throw Failure.timedOut
            }
            return try await group.next() ?? nil
        }
    }

    func splitTabBar(_ controller: BonsplitController, shouldCreateTab tab: Bonsplit.Tab, inPane pane: PaneID) -> Bool {
        return delegate.splitTabBar(controller, shouldCreateTab: tab, inPane: pane)
    }

    func splitTabBar(_ controller: BonsplitController, shouldCloseTab tab: Bonsplit.Tab, inPane pane: PaneID) -> Bool {
        return delegate.splitTabBar(controller, shouldCloseTab: tab, inPane: pane)
    }

    func splitTabBar(_ controller: BonsplitController, didCreateTab tab: Bonsplit.Tab, inPane pane: PaneID) {
        delegate.splitTabBar(controller, didCreateTab: tab, inPane: pane)
    }

    func splitTabBar(_ controller: BonsplitController, didCloseTab tabId: TabID, fromPane pane: PaneID) {
        delegate.splitTabBar(controller, didCloseTab: tabId, fromPane: pane)
        guard tabId == expectedTabID else { return }
        // Forward first: Workspace has now removed the panel and recorded its history.
        let entry = ClosedItemHistoryStore.shared.menuSnapshot().items.first.map {
            Entry(title: $0.title, detail: $0.detail)
        }
        completion.continuation.yield(entry)
        completion.continuation.finish()
    }

    func splitTabBar(_ controller: BonsplitController, didSelectTab tab: Bonsplit.Tab, inPane pane: PaneID) {
        delegate.splitTabBar(controller, didSelectTab: tab, inPane: pane)
    }

    func splitTabBar(_ controller: BonsplitController, didMoveTab tab: Bonsplit.Tab, fromPane source: PaneID, toPane destination: PaneID) {
        delegate.splitTabBar(controller, didMoveTab: tab, fromPane: source, toPane: destination)
    }

    func splitTabBar(_ controller: BonsplitController, didReorderTabsInPane pane: PaneID, orderedTabIds: [TabID]) {
        delegate.splitTabBar(controller, didReorderTabsInPane: pane, orderedTabIds: orderedTabIds)
    }

    func splitTabBar(_ controller: BonsplitController, shouldSplitPane pane: PaneID, orientation: SplitOrientation) -> Bool {
        return delegate.splitTabBar(controller, shouldSplitPane: pane, orientation: orientation)
    }

    func splitTabBar(_ controller: BonsplitController, shouldClosePane pane: PaneID) -> Bool {
        return delegate.splitTabBar(controller, shouldClosePane: pane)
    }

    func splitTabBar(_ controller: BonsplitController, didSplitPane originalPane: PaneID, newPane: PaneID, orientation: SplitOrientation) {
        delegate.splitTabBar(controller, didSplitPane: originalPane, newPane: newPane, orientation: orientation)
    }

    func splitTabBar(_ controller: BonsplitController, didClosePane paneId: PaneID) {
        delegate.splitTabBar(controller, didClosePane: paneId)
    }

    func splitTabBar(_ controller: BonsplitController, didFocusPane pane: PaneID) {
        delegate.splitTabBar(controller, didFocusPane: pane)
    }

    func splitTabBar(_ controller: BonsplitController, didRequestNewTab kind: String, inPane pane: PaneID) {
        delegate.splitTabBar(controller, didRequestNewTab: kind, inPane: pane)
    }

    func splitTabBar(_ controller: BonsplitController, didRequestCustomAction identifier: String, inPane pane: PaneID) {
        delegate.splitTabBar(controller, didRequestCustomAction: identifier, inPane: pane)
    }

    func splitTabBar(_ controller: BonsplitController, didRequestTabContextAction action: TabContextAction, for tab: Bonsplit.Tab, inPane pane: PaneID) {
        delegate.splitTabBar(controller, didRequestTabContextAction: action, for: tab, inPane: pane)
    }

    func splitTabBar(_ controller: BonsplitController, didRequestTabMoveToDestination destinationId: String, for tab: Bonsplit.Tab, inPane pane: PaneID) {
        delegate.splitTabBar(controller, didRequestTabMoveToDestination: destinationId, for: tab, inPane: pane)
    }

    func splitTabBar(_ controller: BonsplitController, didChangeGeometry snapshot: LayoutSnapshot) {
        delegate.splitTabBar(controller, didChangeGeometry: snapshot)
    }

    func splitTabBar(_ controller: BonsplitController, shouldNotifyDuringDrag: Bool) -> Bool {
        return delegate.splitTabBar(controller, shouldNotifyDuringDrag: shouldNotifyDuringDrag)
    }

}
