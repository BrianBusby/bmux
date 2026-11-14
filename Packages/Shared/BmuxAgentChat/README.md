# BmuxAgentChat

Provider transcript, conversation, and shared-control primitives used by bmux.

## Codex loopback transport

`CodexLoopbackWebSocket` authenticates directly to a local provider. Its bounded
64 MiB receive budget matches the provider's message limit, including image-bearing
notifications. Credentials never cross the renderer boundary.

`CodexWebSocketRelay` adapts original-TUI frames to the pinned provider's smaller
16 MiB frame limit. Construct it with an authenticated provider's loopback URL,
await `start()`, and give the returned URL to the TUI. The original capability
header passes through to the provider. Call `stop()` on every owner exit/rollback.
This is framing compatibility, not an RPC proxy or a retry/recovery mechanism.

Tests can construct the relay against a loopback fixture without launching the
app or accessing user configuration. Frame tests use byte values; the app-host
regression launches a private provider/TUI fixture through the real host owner.
Run package checks with `swift test --package-path Packages/Shared/BmuxAgentChat`.
