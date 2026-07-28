# Provider Capability Matrix

Status: initial Slice 0 model based on current bmux code and local Codex app-server schema from `codex-cli 0.144.5`.

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

Claude is listed as a provider in `agent-chat/server.ts`, but Slice 0 did not audit its adapter deeply. Do not assume Claude capability parity with Codex until Slice 8 selects an authoritative structured Claude source.

## Terminal and hook path

- Provider session id: available when hook payload exposes it; otherwise inferred or unavailable.
- Turn boundaries: hook prompt submit/stop can approximate turns.
- Tool lifecycle: hook events such as `PreToolUse` / `PostToolUse` when present; otherwise terminal inference.
- Token usage: usually unavailable unless provider transcript or metrics expose it.
- File changes: Git observation and hook tool inputs.
- Provenance writes: existing selected lifecycle/provenance writes live in Swift/CLI paths, separate from the TypeScript app-server path.
