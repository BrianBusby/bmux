# BmuxWorkBrief

This package owns bounded Work Brief source facts, local classification, source
health, and the refresh coordinator. It has no app, database, filesystem, or
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
snapshot in memory. This keeps status changes independent of PE reads. Source
notifications can call `refresh()`; overlapping requests coalesce.

Run the package tests with:

```sh
swift test --package-path Packages/macOS/BmuxWorkBrief
```
