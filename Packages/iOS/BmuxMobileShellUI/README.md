# BmuxMobileShellUI

The SwiftUI half of the bmux iOS shell.

This is the leaf UI layer extracted out of the `bmuxFeature` catch-all target. It
owns the workspace shell, sign-in, pairing, terminal detail, and root routing
views, plus the iOS push coordinator that the root view injects into the
SwiftUI environment.

It depends only downward: the decomposed domain facade
(`BmuxMobileShell.BMUXMobileShellStore`), the core/value packages
(`BMUXMobileCore`, `BmuxMobileShellModel`, `BmuxMobileWorkspace`,
`BmuxMobileSupport`), `BmuxAuthRuntime` for the injected `AuthCoordinator`,
`BmuxMobileTerminal` for the libghostty surface, and `BmuxMobileCamera` for the
QR-pairing capture stack. It never reaches into RPC/transport concretes.

`bmuxFeature` now sits *above* this package as the composition root
(`BMUXMobileRootScene`, `BMUXMobileRuntime`, the auth/push wiring) and
re-exports the package so the app shell keeps `import bmuxFeature` working.

## Entry points

- ``BMUXMobileAppView`` — the live mobile UI root, mounted by `BMUXMobileRootScene`.
- ``MobilePushCoordinator`` — APNs↔store bridge, constructed at the app root.
