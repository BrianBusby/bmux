# BmuxWorkBrief

This package owns bounded Work Brief source facts, local classification, source
health, inferred exact-link relationships, and the refresh coordinator. It has no app, database, filesystem, or
provider client dependency. The app supplies a loader over existing bmux and
Provenance Engine APIs; the UI package renders immutable snapshots.

The coordinator can be tested without launching bmux by injecting a fixed
snapshot loader:

```swift
let coordinator = WorkBriefCoordinator(initialSnapshot: knownSnapshot) { _ in
    refreshedSnapshot
}
await coordinator.refresh()
```

Live status observations use `observeLocalStatus(id:status:)` to update the
snapshot in memory. This keeps status changes independent of PE reads.
Provider ticket IDs or URLs and PR URLs can match accepted local PE links; the brief
labels those joins as bmux inferences and carries the matching PE event ID when
its link evidence is available. Branch names alone never establish a join. Source
notifications can call `refresh()`; overlapping requests coalesce.

Recent changes compare source metadata from two bounded snapshots. Tests pass
fixed timestamps and snapshots directly; no preferences or provider clients
are needed:

```swift
let baseline = WorkBriefBaseline(snapshot: earlierSnapshot, previous: nil, at: earlierTime)
let changes = baseline.changes(in: currentSnapshot)
```
The app stores this metadata only after a viewed brief closes, subject to the
30-day and 64 KiB limits. If the encoded record exceeds the limit, the
largest fingerprints are removed in a deterministic order. Coverage flags
prevent omitted IDs from being reported as newly created and mark the UI
comparison as limited. Titles, URLs, and
message content are excluded.
Expired preference data is deleted when the brief next opens.

Run the package tests with:

```sh
swift test --package-path Packages/macOS/BmuxWorkBrief
```
