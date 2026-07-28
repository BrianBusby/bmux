# Execution Telemetry Event Inventory

Status: Slice 0 audit. This is current behavior, not the final contract.

Local Codex schema source:

- `codex --version`: `codex-cli 0.144.5`
- `codex app-server generate-json-schema --out /tmp/bmux-codex-schema-1785276507`

The `/tmp` schema directory is not durable. Regenerate it when continuing.

## Current AgentEvent Schema

`agent-chat/types.ts` defines display-oriented events: `meta`, `options`, `commands`, `user`, `status`, `delta`, `assistant`, `thinking`, `tool-start`, `tool-end`, `done`, `files-changed`, and `error`.

React duplicates this union in `agent-chat/src/session.ts` and projects it into renderable `Block` rows with `foldEvent()`.

## Requests bmux Sends To Codex

`agent-chat/adapters/codex.ts` sends `initialize`, `thread/start`, `thread/fork`, `turn/start`, `turn/steer`, `turn/interrupt`, `thread/settings/update`, `model/list`, `collaborationMode/list`, and `skills/list`.

## Current Codex Notification Mapping

- `turn/started`: updates `turnActive` and `currentTurnId`; emits no event.
- `thread/settings/updated`: updates Codex state and emits UI `options`.
- `skills/changed`: refreshes and emits UI `commands`.
- `item/agentMessage/delta`: emits `delta` text only.
- reasoning delta variants: emit `thinking` text only.
- `item/started` command/file/web/MCP items: emits `tool-start`.
- `item/completed` command/file/web/MCP items: emits `tool-end`.
- `thread/tokenUsage/updated`: stores `tokenUsage.total` as `lastUsage`; emits no event.
- `turn/completed`: emits `done` with display `stats`; sets status idle.
- `turn/failed`: emits `error` then `done`; sets status idle.
- approval server requests: auto-responds and emits status text only for denied or unsupported requests.

## Fields Currently Lost Or Reduced

- Provider turn id is absent from most public `AgentEvent`s.
- Operation timestamps (`startedAtMs`, `completedAtMs`) are discarded.
- Numeric token details are reduced to a footer string.
- Numeric durations are stringified or discarded.
- Command cwd, source, actions, process id, and exact exit metadata are reduced.
- MCP server/plugin/resource/result/error details are reduced.
- File-change path/kind/diff structures are summarized for tool cards.
- Approval request id, prompt, decision, and timing are not modeled.
- Reasoning and assistant deltas lose item id, turn id, and indices.

## Schema Notifications Not Currently Handled

The local schema includes notifications for `error`, `thread/started`, `thread/status/changed`, `thread/name/updated`, `thread/goal/updated`, `hook/started`, `hook/completed`, `turn/diff/updated`, `turn/plan/updated`, approval review start/completion, process output/exit, file patch updates, server request resolution, MCP progress, account/rate-limit updates, fs changes, `thread/compacted`, model reroutes, moderation metadata, warnings, and realtime events. The current Codex adapter ignores these before bounded metadata capture.

## File-Change Behavior

There are two current file-change sources:

1. Codex structured `fileChange` / `patchApply` items.
2. Git observation in `agent-chat/server.ts`, which emits `files-changed` before `done` by comparing dirty baselines around a turn.

The Git summary is useful but is not the same evidence source as provider structured file-change telemetry.

## Ordering And Replay

Current ordering is array order in `Session.events`. There is no provider sequence field in `AgentEvent`.

`sendPrompt()` uses an internal `turnGeneration` to place deferred `files-changed` and `done` events. That generation is not a provider turn id and is stripped from the public event.

Replay is bounded by `MAX_SESSION_EVENTS = 5000`. When exceeded, older events are dropped and a status event is inserted: `(transcript truncated: older events dropped)`.

## Explicit Answers

React is not required for lifecycle capture. `POST /api/sessions` can create a session and send the first prompt without a React subscriber.

React is not required for session ownership. `agent-chat/server.ts` owns the session map, status, events, and provider adapter state.

Multiple WebSocket consumers can subscribe to the same session, but there is no provider-neutral non-UI subscription API.

No Codex app-server lifecycle events from `agent-chat/adapters/codex.ts` were found reaching provenance-engine.
