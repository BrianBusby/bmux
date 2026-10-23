# BmuxWorkspaces

Workspace models and policies shared by the macOS app's workspace entrypoints.

## Restored terminal directories

`WorkspaceSessionRestorePolicyService` owns runtime directory selection separately
from persisted workspace/panel metadata. Its constructor takes a
`@Sendable (String) -> Bool` directory-existence predicate. Tests can inject a
deterministic predicate or check paths under an owned temporary root without
launching the app or reading user settings. The app uses `FileManager` directory
checks that follow symbolic links.

Given a service built with injected approval, environment, and filesystem inputs:

```swift
let directories = service.runtimeWorkingDirectories(
    usesLocalWorkingDirectory: true,
    startupHandlesWorkingDirectory: true,
    workingDirectory: ownedRoot.appendingPathComponent("repo").path,
    unguardedWorkingDirectory: nil
)
```

For a guarded launcher, `directories.requested` is the path only when it exists
as a directory. A missing path or regular file returns nil so the guarded command
can handle fallback itself. `directories.unguarded` remains nil for such launches,
allowing the app to retain its existing initial-directory-report guard. Ordinary
unguarded launches retain their selected cwd. Remote launches pass
`usesLocalWorkingDirectory: false`, return nil for both values, and do not check
the remote path on the local filesystem. The app retains saved directory metadata
and unmounted-volume bindings independently of these runtime values.

## Explorer retained-session pages

`WorkspaceExplorerSessionPageStore` owns the Explorer history page cache and
request generations. The app's Explorer coordinator supplies first-page and
continuation loaders through its initializer; the store never accesses the PE
database directly. Tests can inject deterministic async loaders without starting
the app or using the user's archive. PE contracts provide the session values.

## Explorer close journal

`WorkspaceExplorerCloseJournal` retains one minimal identity file per logical
workspace beside the PE database. Its synchronous write finishes before the app
returns from a user close, while actor-owned recovery reads and clear run off the
main actor. Bmux maps these records to PE's public archive contract; the journal
does not read PE tables or retain session evidence.
