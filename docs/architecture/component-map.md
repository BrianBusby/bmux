# Component Map

This map describes major components and their maturity. It intentionally avoids
one giant graph; use [data-flows.md](data-flows.md) for flow-specific diagrams
and [implementation-map.md](implementation-map.md) for file locations.

## bmux Components

```mermaid
flowchart TB
  shell["CURRENT: native macOS shell/container"]
  workspace["CURRENT: workspace/domain model"]
  mutation["CURRENT: canonical mutation paths"]
  surfaces["CURRENT: surface and panel management"]
  runtime["CURRENT: provider runtime"]
  codex["CURRENT: Codex adapter"]
  claude["CURRENT: Claude adapter"]
  acp["CURRENT: ACP / PI adapter shape"]
  telemetry["CURRENT: structured execution telemetry"]
  agentchat["CURRENT: React Terminal agent-chat"]
  native["CURRENT: Native view"]
  terminal["CURRENT: Terminal view"]
  session["ACTIVE/PLANNED: Session view"]
  pebridge["CURRENT: PE integration boundary"]

  shell --> workspace --> mutation --> surfaces
  surfaces --> native
  surfaces --> terminal
  runtime --> codex
  runtime --> claude
  runtime --> acp
  codex --> telemetry
  claude --> telemetry
  acp --> telemetry
  telemetry --> agentchat
  telemetry --> pebridge
  pebridge --> session
```

CURRENT bmux implementation includes the native app shell, workspace/session
models, panel/surface hosting, provider sessions, `agent-chat` React Terminal,
provider-normalized execution telemetry, PE evidence production, and workspace
Current State consumption.

The Session view should remain a separate summary/understanding surface. It must
not become a second transcript and must not infer PE-owned semantics in React or
Swift presentation code.

## Provenance Engine Components

```mermaid
flowchart TB
  contracts["CURRENT: evidence and public contracts"]
  sdk["CURRENT: public in-process SDK"]
  storage["CURRENT: SQLite immutable ledger"]
  identity["CURRENT: identity and relationships"]
  current["CURRENT: deterministic Current State"]
  workspace["CURRENT: workspace display projections"]
  factual["CURRENT: factual session projection"]
  turn["CURRENT: turn detail reads"]
  semfw["CURRENT: semantic inference framework"]
  semrec["CURRENT: semantic records/history"]
  semmsg["CURRENT: semantic presentation messages"]
  swm["CURRENT: SessionWorkModel"]
  compiler["PLANNED: Knowledge Compiler"]
  store["PLANNED: Knowledge Store"]
  retrieval["PLANNED: retrieval"]

  contracts --> sdk --> storage
  contracts --> storage
  storage --> current
  storage --> identity
  current --> workspace
  current --> factual --> turn
  factual --> semfw --> semrec --> semmsg
  semrec --> swm
  semmsg --> swm
  swm --> compiler --> store --> retrieval
```

PE's implemented semantic layer records inferred meaning and separately
materializes human-readable messages. `SessionWorkModel` should
compose factual projections, semantic records, semantic messages, and provenance
references into a stable consumer snapshot.

## Boundary Rules

- bmux imports `ProvenanceEngineContracts` and `ProvenanceEngineSDK`.
- bmux does not import `ProvenanceEngineSQLite` in production integration paths.
- PE does not import bmux app, UI, provider, terminal, or workspace internals.
- PE package tests may exercise SQLite internals; external consumers should use
  contracts and SDK.
- Shared Project Truth status lives at repository root, not inside PE or a peer
  checkout.
