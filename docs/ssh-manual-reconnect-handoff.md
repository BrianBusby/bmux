# SSH manual reconnect handoff

The manual reconnect repair is isolated from the SSH lifecycle fixture and error-sanitizer maintenance changes. The existing native workspace action owns terminal replacement; the shell must request that action once after ending its old session, then exit without launching another SSH process.

## Regression evidence

On the unchanged build 773 CLI, the updated `manualReconnectHandsOffToNativeOwner` test runs one generated VM SSH startup command. It records one SSH attempt and one session-end notification, but pressing `r` exits with status 1 and sends no reconnect RPC. The local executable test fails three expectations. The fixture now answers current `vm.ssh_info` requests and includes the created surface ID, so it reaches the actual startup script.

The focused app-host gate selects the full suite on existing shard 3 before unchanged full-suite coverage. Job 114964414611 selected a Swift Testing method without its callable suffix and reported zero tests; that green status is not regression evidence. The suite selector corrects this coverage gap. Actual nonzero CI red is still pending. No production fix is included in the first commit. The fake CLI acceptance tests shell handoff only; it does not prove native replacement succeeds. Native owner and socket failure coverage remain required.

## Ownership and verification remaining

`Workspace.reconnectRemoteConnection` must remain the single replacement owner for the prompt, context menu and disconnected placeholder. Targeted failure must propagate through the socket adapter; nil/workspace reconnect semantics remain unchanged. Old-session cleanup and one-shot password removal must finish before requesting a replacement. Enter and EOF retain the SSH exit status. A failed request leaves the prompt available for another explicit choice.

The three native guard methods in the existing suite still contain assumptions from the earlier same-shell retry design. They require behavior-level migration against the current respawn contract, not deletion or suppression. Initial, reusable and bootstrap launch paths, credential cleanup, failure reporting, native identity and entrypoint behavior remain to be verified. No app was built, launched or replaced for the regression preparation.

Guidance: root `AGENTS.md`, `continuous-code-quality`, and repository testing, architecture, shared-behavior, socket-policy and localization skills. The maintained surface-respawn socket strings seam resolves localization in the app bundle. New reconnect failure text must follow that ownership and include English and Japanese.
