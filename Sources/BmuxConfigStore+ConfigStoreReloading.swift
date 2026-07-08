import BmuxTerminalCore

/// Lets `BmuxConfigStoreReloadCoordinator` drive per-window config reloads through a
/// protocol seam. `BmuxConfigStore`'s existing `loadAll()` already satisfies the
/// requirement, so this conformance is empty.
extension BmuxConfigStore: BmuxConfigStoreReloading {}
