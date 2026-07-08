import Foundation
import os

private nonisolated struct BmuxTopProcessSnapshotCacheState {
    var snapshot: BmuxTopProcessSnapshot?
    var includeProcessDetails = false
    var includeBMUXScope = true
}

// libproc snapshots are a short-lived platform bridge shared by the CLI, socket,
// and Task Manager paths; keep the cache here so ownership stays with capture().
private nonisolated let bmuxTopProcessSnapshotCache = OSAllocatedUnfairLock(
    initialState: BmuxTopProcessSnapshotCacheState()
)

nonisolated extension BmuxTopProcessSnapshot {
    static func captureCached(
        includeProcessDetails: Bool = false,
        includeBMUXScope: Bool = true,
        maximumAge: TimeInterval
    ) -> BmuxTopProcessSnapshot {
        let now = Date()
        if let cached = bmuxTopProcessSnapshotCache.withLock({ state -> BmuxTopProcessSnapshot? in
            guard let snapshot = state.snapshot,
                  Self.cachedSnapshotDetailsSatisfy(
                      state.includeProcessDetails,
                      requested: includeProcessDetails
                  ),
                  Self.cachedSnapshotBMUXScopeSatisfies(
                      state.includeBMUXScope,
                      requested: includeBMUXScope
                  ),
                  now.timeIntervalSince(snapshot.sampledAt) <= maximumAge else {
                return nil
            }
            return snapshot
        }) {
            return cached
        }

        let snapshot = capture(
            includeProcessDetails: includeProcessDetails,
            includeBMUXScope: includeBMUXScope
        )
        return bmuxTopProcessSnapshotCache.withLock { state in
            let storeTime = Date()
            if let cached = state.snapshot,
               Self.cachedSnapshotDetailsSatisfy(
                   state.includeProcessDetails,
                   requested: includeProcessDetails
               ),
               Self.cachedSnapshotBMUXScopeSatisfies(
                   state.includeBMUXScope,
                   requested: includeBMUXScope
               ),
               storeTime.timeIntervalSince(cached.sampledAt) <= maximumAge {
                return cached
            }
            state.snapshot = snapshot
            state.includeProcessDetails = includeProcessDetails
            state.includeBMUXScope = includeBMUXScope
            return snapshot
        }
    }

    private static func cachedSnapshotDetailsSatisfy(
        _ cachedIncludesProcessDetails: Bool,
        requested: Bool
    ) -> Bool {
        cachedIncludesProcessDetails || !requested
    }

    private static func cachedSnapshotBMUXScopeSatisfies(
        _ cachedIncludesBMUXScope: Bool,
        requested: Bool
    ) -> Bool {
        cachedIncludesBMUXScope || !requested
    }
}
