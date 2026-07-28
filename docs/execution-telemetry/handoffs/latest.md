# Execution Telemetry Handoff

## Session identity

- Date: 2026-07-28
- Slice: Slice 1 - Ownership boundaries and provider-neutral contract
- Branch: `execution-telemetry-slice-1`
- Base branch: stacked on PR #11 / `execution-telemetry-slice-0`
- Slice 0 accepted head: `6cc83ff8e2cdde480e1a00295e40d0abd51b4cf7`
- Slice 1 head after autoreview fix: `964e1131354ae277d896e5db9c61f10973a9d906`
- Working tree status: clean at final handoff

## Objective completed

Validated the Slice 0 audit and defined the first provider-neutral telemetry contract plus ownership boundaries without changing React behavior.

## Slice 0 validation

PR #11 is open, draft, clean against `main`, and docs-only. The branch contains the autoreview follow-up commit `6cc83ff8e` after the original audit commit. Local code inspection confirmed the Slice 0 claims:

- `agent-chat/adapters/codex.ts` maps raw Codex app-server messages directly into display-oriented `AgentEvent` values.
- `agent-chat/server.ts` owns sidecar session ids, status, replay, and WebSocket fanout.
- `agent-chat/src/session.ts` duplicates `AgentEvent` and folds it into React render blocks.
- `Sources/AppDelegate+AgentChat.swift` starts or opens the browser-backed sidecar URL rather than subscribing to the TypeScript event stream.
- No app-server-to-provenance path was found in the inspected Slice 0 files.

## Work completed

- Added `agent-chat/executionTelemetryTypes.ts` as the canonical sidecar-owned provider-neutral telemetry type module.
- Hardened the metadata contract in `964e11313` so `TelemetryJsonValue` does not allow `undefined` and `metadata` only allows scalar facts or scalar lists.
- Added `docs/execution-telemetry/contract.md` with ownership boundaries, envelope rules, minimal event variants, Swift sync policy, and deferred work.
- Updated `docs/execution-telemetry/architecture.md` to point at the Slice 1 contract and ownership boundary.
- Updated `docs/execution-telemetry/decisions.md` with Slice 1 ADRs for contract location, event identity/ordering, bounded provider metadata, and Swift drift policy.
- Updated `docs/execution-telemetry/README.md` and `implementation-status.md` for Slice 1.

No event bus, persistence, provenance writes, React rendering changes, Swift bridge, or Claude implementation work was added.

## Contract summary

- Source of truth: `agent-chat/executionTelemetryTypes.ts`.
- Current UI schema: `agent-chat/types.ts` remains `AgentEvent` and is still the WebSocket projection.
- Ordering: sidecar-assigned `sequence` is authoritative per bmux session.
- Identity: `eventId` is opaque; provider ids are retained separately when available.
- Metadata: `providerEvent` and `metadata` are bounded references only, not raw provider envelopes.
- Swift policy: future Swift consumers decode versioned JSON and add drift checks or fixtures in the same slice.

## Tests run

```bash
git diff --check
```

Result: passed.

```bash
npm exec --yes --package typescript@5.9.3 -- tsc --noEmit --target ES2022 --module ESNext --moduleResolution Bundler --strict agent-chat/executionTelemetryTypes.ts
```

Result: passed.

Expected limitation remains: `bun` is not on PATH in this shell, so package tests that require Bun cannot run unless the environment changes.

## Known failures or limitations

- `bun` is unavailable on PATH in this shell.
- The contract file is not wired to producers or consumers yet by design.
- The TypeScript contract has not been converted to JSON Schema yet.
- Swift mirror/decoder types do not exist yet by design.

## Important files for the next session

- `agent-chat/executionTelemetryTypes.ts`
- `docs/execution-telemetry/contract.md`
- `docs/execution-telemetry/architecture.md`
- `docs/execution-telemetry/event-inventory.md`
- `docs/execution-telemetry/provider-capabilities.md`
- `docs/execution-telemetry/decisions.md`
- `docs/execution-telemetry/implementation-status.md`
- `agent-chat/types.ts`
- `agent-chat/server.ts`
- `agent-chat/adapters/codex.ts`

## Next slice

Slice 2 - Introduce the sidecar-owned telemetry fanout path and projection seam.

## First action for the next agent

Design the smallest sidecar-owned fanout that can accept `TelemetryEventEnvelope` values, assign ids/sequences in one place, and project to the existing `AgentEvent` stream without changing React rendering.

## Do not do yet

- Do not add persistence.
- Do not add provenance writes.
- Do not start Claude implementation or structured-source selection.
- Do not change React rendering behavior.
- Do not make Swift the schema owner.
- Do not store raw provider envelopes in canonical telemetry events.
