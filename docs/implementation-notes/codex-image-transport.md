# Codex image transport repair

Build 733's new-workspace Terminal failure is distinct from runtime discovery.
The managed 0.162.0 TUI snapshots local images into inline JSON and emits one
WebSocket frame. At 18:18:04 UTC on October 10, 2026 the provider rejected a
25,134,657-byte frame against its 16,777,216-byte frame limit. Its 64 MiB message
limit is larger. Official 0.162.1 retains the same server frame default.

## Rules and ownership

Governing sources: root AGENTS.md; continuous-code-quality; bmux-architecture
and its package-boundaries, file-api-discipline, concurrency-carveouts references;
bmux-testing and regression-and-quality/local-vs-ci-validation; bmux-debugging,
bmux-dev-workflow, and bmux-shared-behavior. This is a repair to an existing local
capability under observation, not a new roadmap capability.

`ConnectedCodexHostService` owns the adapter alongside its provider process and
closes it on launch rollback, process exit, or explicit owning-terminal close.
`BmuxAgentChat` owns provider wire compatibility alongside its existing loopback
transport. The adapter owns only framing and socket lifetime; it never parses
RPC, changes threads, resumes sessions, substitutes image content, or retries.
The app remains the composition root. The existing remote CLI relay is a
lifecycle reference, but its legacy queue-as-lock pattern is not copied.

The adapter binds only 127.0.0.1, forwards the original HTTP upgrade headers, and
leaves capability-token authentication and Origin checks with Codex. It forwards
small frames unchanged and streams large masked data frames in 1 MiB fragments,
with correct continuation/FIN semantics and fresh masking keys. The reader is
bounded, writes apply backpressure, connections are capped at eight, and upgrade
waits have a cancellable 15-second deadline. Extensions/compression are rejected;
the pinned client does not negotiate them. No credentials or payloads are logged.

Chat's receive cap also changes from 8 MiB to the provider's 64 MiB message budget
because provider notifications/history can contain the same inline images.
Codex's own 32 MiB image preparation limit and 64 MiB message limit still apply.
This does not recover or replay an already uncertain submission in build 733.

## Verification record

- Test-only commit 6509f72fe: launch the production host owner against an isolated
  16 MiB-frame provider fixture; the fake TUI sends a 24 MiB request and requires
  exactly one acceptance plus a follow-up on the same socket. Red locally.
- Test-only commit 7d73abaef: also require a 24 MiB notification through the actual
  Chat transport. Red with POSIX 40, Message too long, before the receive-cap fix.
- Green: 32 focused app-host tests, including both directions of that regression;
  220 BmuxAgentChat package tests, including frame continuation/mask fidelity,
  invalid sizes/control frames, endpoint restrictions, and relay stop/restart.
- Real pinned provider: direct 24 MiB frame disconnects; the adapter accepts the
  identical request and a follow-up. A missing credential still gets HTTP 401.
- Real pinned TUI: three synthetic PNG attachments (24,895,356 base64 bytes)
  completed exactly once, then a Terminal follow-up completed on the same original
  thread with the TUI still alive. Evidence: private scratch probe results for
  `image-transport-dpske5ac`; only test data was submitted.
- Separate upstream observation: the provider-to-model WebSocket retried five
  times before its existing HTTP fallback completed the image turn. The local
  TUI/provider connection stayed usable. This adapter does not change that
  upstream retry policy or promise faster large-image inference.
- Tagged build 734 compiled; native repo launcher -> new workspace -> Terminal
  text prompt completed. In-app three-image submission and final pushed-head
  build/CI/review remain pending.
- The focused run retains an unchanged test-only `alive` variable warning in
  ConnectedSessionOwnershipTests. No affected production-source warning was found.

Build 733 and the user's original queued images remain untouched. Test processes
use private scratch directories, separate ports, and their own lifecycle.

No UI copy, shortcut, or localized web/docs surface changes. New text is internal
source/verification documentation; the app's existing localized errors remain.
