import AppKit

@MainActor
final class PortalSplitDividerCacheInvalidator {
    @MainActor
    private struct ViewStructure {
        weak var view: NSView?
        let subviewIDs: [ObjectIdentifier]

        init(view: NSView) {
            self.view = view
            subviewIDs = view.subviews.map(ObjectIdentifier.init)
        }

        var isCurrent: Bool {
            guard let view else { return false }
            let subviews = view.subviews
            return subviews.count == subviewIDs.count &&
                zip(subviews, subviewIDs).allSatisfy { ObjectIdentifier($0.0) == $0.1 }
        }
    }

    private var structures: [ViewStructure] = []

    /// Checks only the already-collected layout containers, without walking their descendants.
    var isStructureCurrent: Bool { structures.allSatisfy(\.isCurrent) }

    // Observer tokens are assigned/cleared from main-thread AppKit paths. Swift
    // deinit is nonisolated, so the teardown helper needs nonisolated access
    // after all main-thread use has ceased.
    private nonisolated(unsafe) var observations: [NSKeyValueObservation] = []
    private nonisolated(unsafe) var notificationObservers: [NSObjectProtocol] = []

    deinit {
        invalidateObservations()
    }

    func observe(
        geometryViews: [NSView],
        structureViews: [NSView],
        onChange: @escaping @MainActor () -> Void
    ) {
        invalidate()
        let geometryViews = Self.uniqueViews(geometryViews)
        let subviewObservedViews = Self.uniqueViews(geometryViews + structureViews)

        for view in geometryViews {
            // These NSView flags are shared; do not restore them per observer or
            // one portal cache can disable notifications another cache still needs.
            view.postsFrameChangedNotifications = true
            view.postsBoundsChangedNotifications = true
        }
        notificationObservers = geometryViews.flatMap { view in
            return [
                NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view, queue: nil) { _ in
                    MainActor.assumeIsolated { onChange() }
                },
                NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: view, queue: nil) { _ in
                    MainActor.assumeIsolated { onChange() }
                },
            ]
        }
        observations = geometryViews.map { view in
            view.observe(\.isHidden, options: [.new]) { _, _ in
                MainActor.assumeIsolated { onChange() }
            }
        }
        // NSView.addSubview does not reliably emit KVO for subviews. Keep weak snapshots
        // of the same bounded root/direct/split-related containers for cache-hit validation.
        structures = subviewObservedViews.map(ViewStructure.init)

    }

    private static func uniqueViews(_ views: [NSView]) -> [NSView] {
        var uniqueViews: [NSView] = []
        var ids = Set<ObjectIdentifier>()
        for view in views where ids.insert(ObjectIdentifier(view)).inserted {
            uniqueViews.append(view)
        }
        return uniqueViews
    }

    func invalidate() {
        structures.removeAll()
        invalidateObservations()
    }

    private nonisolated func invalidateObservations() {
        observations.removeAll()
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
        notificationObservers.removeAll()
    }
}
