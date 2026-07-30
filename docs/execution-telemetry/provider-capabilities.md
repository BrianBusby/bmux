# Provider Capability Matrix

Status: Codex capabilities are based on the Slice 0 schema audit from
`codex-cli 0.144.5`; Claude capabilities include the first non-Codex provider
migration audit from `agent-chat/adapters/claude.ts`.

## Codex app-server in agent-chat

- Provider session id: authoritative Codex `threadId` from `thread/start`.
- bmux session id: sidecar-generated id in `agent-chat/server.ts`.
- Turn boundaries: authoritative `turn/started` and `turn/completed`.
- Turn id: available internally as `turn.id` / `turnId`; not emitted in `AgentEvent`.
- Tool lifecycle: authoritative `item/started` and `item/completed`.
- Tool operation id: item id, currently emitted as `toolId`.
- Tool timestamps: available as `startedAtMs` and `completedAtMs`; discarded.
- Approval lifecycle: app-server requests are authoritative; current code auto-responds and emits only denial/status text.
- Token usage: authoritative `thread/tokenUsage/updated`; reduced to input/output display stats.
- File changes: structured file-change items plus Git-observed dirty summary.
- Compaction: `thread/compacted` exists in schema; currently ignored.
- Subagents: schema has `collabAgentToolCall` and `subAgentActivity` items; current adapter ignores them.
- Provider errors: schema has structured `error`; current adapter keeps mostly display messages.
- Replay: sidecar process memory, capped at 5000 `AgentEvent`s.
- Headless capture: yes through REST `/api/sessions`.
- Provenance writes: none found from the app-server path.

## Claude in agent-chat

- Provider session id: authoritative `session_id` from Claude stream-json
  `system/init`.
- bmux session id: sidecar-generated id in `agent-chat/server.ts`.
- Prompt submission: sidecar-owned prompt dispatch, now emitted as
  `prompt.submitted` for live lifecycle projection.
- Turn boundaries: no Codex-parity provider turn id is exposed in the audited
  stream. Claude stream-json `result` is authoritative for coarse completion or
  result-error closure of the active sidecar turn; sidecar process close is a
  bounded failure closure for an unfinished active turn.
- Turn id: unavailable in the audited Claude stream-json path.
- Model identity: available on `system/init`; retained only as projection data
  for the existing React `meta` event, not canonical telemetry.
- Tool lifecycle: assistant `tool_use` and user `tool_result` stream-json
  blocks exist, but remain on the existing `AgentEvent` path for now because
  this slice did not select tool input/result migration.
- Token usage: not exposed in the audited stream-json events used by this
  slice. Cost, duration, and turn count from `result` remain projection-only
  display stats.
- File changes: no structured changed-file list selected in this path.
- Replay: sidecar process memory, capped at 5000 `AgentEvent`s.
- Headless capture: yes through REST `/api/sessions`.
- Provenance writes: none from the Claude app-server path beyond the existing
  broad live projection producer consuming bounded session/provider/lifecycle
  facts.

## Terminal and hook path

- Provider session id: available when hook payload exposes it; otherwise inferred or unavailable.
- Turn boundaries: hook prompt submit/stop can approximate turns.
- Tool lifecycle: hook events such as `PreToolUse` / `PostToolUse` when present; otherwise terminal inference.
- Token usage: usually unavailable unless provider transcript or metrics expose it.
- File changes: Git observation and hook tool inputs.
- Provenance writes: existing selected lifecycle/provenance writes live in Swift/CLI paths, separate from the TypeScript app-server path.
