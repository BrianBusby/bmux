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
    terminal["React Terminal / agent-chat"]
    telemetry["Provider-neutral telemetry foundation"]
    monorepo["Monorepo consolidation"]
    factual_ui["Factual native Session inspection"]
  end

  subgraph selected["Selected next"]
    smart["React Smart Session"]
  end

  subgraph planned["Planned"]
    swm["SessionWorkModel"]
    milestone["Milestone semantics"]
    blocker["Blocker / approach-change semantics"]
    architecture["Scoped architecture projection"]
    knowledge["Knowledge Compiler / Store / Retrieval"]
  end

  telemetry --> factual
  pe_pkg --> local_sdk --> sqlite --> workspace
  sqlite --> factual --> semantic --> messages
  messages --> smart
  semantic --> swm --> smart
  monorepo --> smart
  monorepo --> swm
  factual_ui --> smart
  swm --> milestone --> architecture --> knowledge
  blocker --> swm
```

## Completed Migration Impact

The monorepo migration simplifies future cross-component slices so a single
branch, worktree, and PR can update PE contracts and bmux consumers together.
It does not make PE a bmux-internal module.

## Next Dependency-Ready Product Direction

After the completed monorepo and factual native Session view slices, the next
product slices should resume in this order unless Project Truth changes:

1. Build React Smart Session foundation from PE factual projection and semantic messages.
2. Define the PE-owned `SessionWorkModel` contract.
3. Add milestone, blocker, approach-change, and scoped architecture semantics.
4. Connect React Smart Session to `SessionWorkModel` once the contract exists.
