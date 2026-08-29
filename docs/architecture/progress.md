# Architecture Progress

This page is a human-readable progress map. Generated Project Truth remains the
authority for exact status.

```mermaid
flowchart LR
  subgraph implemented["Implemented / merged"]
    pe_pkg["PE Swift package"]
    local_sdk["Public contracts and SDK"]
    sqlite["SQLite ledger and Current State"]
    workspace["Workspace display Current State"]
    factual["Factual session projection"]
    semantic["Semantic inference records"]
    messages["Semantic message materialization"]
    work_model["SessionWorkModel contract"]
    related["Related-session awareness"]
    terminal["React Terminal / agent-chat"]
    telemetry["Provider-neutral telemetry foundation"]
    monorepo["Monorepo consolidation"]
    factual_ui["Factual native Session inspection"]
  end

  subgraph selected["Selected next"]
    smart["React Smart Session"]
  end

  subgraph planned["Planned"]
    milestone["Milestone semantics"]
    blocker["Blocker / approach-change semantics"]
    architecture["Scoped architecture projection"]
    cross_semantics["Cross-session semantics"]
    collision["Artifact collision awareness"]
    knowledge["Knowledge Compiler / Store / Retrieval"]
  end

  telemetry --> factual
  pe_pkg --> local_sdk --> sqlite --> workspace
  sqlite --> factual --> semantic --> messages
  semantic --> work_model
  factual --> related
  work_model --> related
  messages --> smart
  work_model --> smart
  monorepo --> smart
  monorepo --> work_model
  factual_ui --> smart
  work_model --> milestone --> architecture --> knowledge
  blocker --> work_model
  related --> cross_semantics --> collision --> knowledge
```

## Completed Migration Impact

The monorepo migration simplifies future cross-component slices so a single
branch, worktree, and PR can update PE contracts and bmux consumers together.
It does not make PE a bmux-internal module.

## Next Dependency-Ready Product Direction

After the completed monorepo and factual native Session view slices, the next
product slices should resume in this order unless Project Truth changes:

1. Build richer cross-session work-state semantics from validated
   `SessionWorkModel` and related-session foundations.
2. Add artifact and change collision awareness from factual overlap evidence.
3. Add agent-accessible explicit cross-session retrieval.
4. Continue React Smart Session work from PE factual projection, semantic
   messages, and `SessionWorkModel` without local semantic reinterpretation.
