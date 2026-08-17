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
  end

  subgraph active["Active / open"]
    monorepo["Monorepo consolidation"]
    factual_ui["Factual Session UI branch"]
  end

  subgraph planned["Planned"]
    smart["React Smart Session"]
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

## Active Migration Impact

The monorepo migration simplifies future cross-component slices so a single
branch, worktree, and PR can update PE contracts and bmux consumers together.
It does not make PE a bmux-internal module.

## Next Dependency-Ready Product Direction

After the migration is stable, the next product slices should resume in this
order unless Project Truth changes:

1. Rebase or supersede the factual agent Session view branch in the monorepo.
2. Build React Smart Session foundation from PE factual projection and semantic messages.
3. Define the PE-owned `SessionWorkModel` contract.
4. Add milestone, blocker, approach-change, and scoped architecture semantics.
5. Connect React Smart Session to `SessionWorkModel` once the contract exists.

