# ADR 002: Consolidate bmux and Provenance Engine into a Monorepo

Status: active migration branch
Date: 2026-08-17

## Context

bmux and Provenance Engine began in separate repositories to protect PE's
independent architectural boundary. That boundary still matters. The Git
repository boundary no longer provides enough value for the current product
shape. Cross-component work now routinely needs paired PRs, peer branch
resolution, Project Truth synchronization, PE commit pins, cross-repo CI, and
coordinated worktrees.

The product now behaves as one architecture: bmux observes and presents coding
agent work; Provenance Engine stores accepted evidence, derives factual and
semantic projections, and will eventually provide `SessionWorkModel`, Knowledge
Compiler, Knowledge Store, and retrieval.

## Decision

Use `BrianBusby/bmux` as the canonical monorepo. Import the Provenance Engine
repository history into `Packages/macOS/ProvenanceEngine` as a subtree without
squashing. Move canonical Project Truth to the monorepo root under `project/`.
Use the local PE Swift package from bmux Xcode/SwiftPM references during normal
development.

The result is a monorepo, not a monolith.

## Migration Strategy

- Created branch `monorepo-provenance-engine` from bmux `origin/main`.
- Merged bmux Project Truth reconciliation branch first so useful bmux planning
  history is preserved in the migration branch.
- Imported PE PR #33/head history with `git subtree add --prefix=Packages/macOS/ProvenanceEngine ...` without `--squash`.
- Kept original PE commits, authors, and timestamps inspectable through Git
  history under the package prefix.
- Moved Project Truth manifest/schema/tooling from the imported PE tree to the
  monorepo root.
- Replaced remote PE revision pins with a local package reference.
- Removed peer-repo Project Truth workflow mechanics after validating the root
  manifest and generated docs.

Recovery remains possible because the original `BrianBusby/provenance-engine`
repository is not deleted and its imported commit history remains reachable.

## Consequences

Positive:

- One branch, worktree, PR, and CI run can update PE contracts and bmux consumers.
- Project Truth describes one execution graph instead of artificial repository
  pairs.
- bmux builds against the local PE package source during development.
- Architecture docs can describe the whole system without duplicate status
  authorities.

Tradeoffs:

- CI must protect the PE boundary explicitly because Git no longer does.
- PE release/versioning policy must remain visible if independent publishing or
  extraction resumes.
- Existing open PRs need a migration ledger and rebase/supersede decisions.

## Boundary Preserved

PE remains a standalone Swift package with public contracts and SDK products.
PE must not import bmux app/runtime/UI internals. bmux production integration
should consume `ProvenanceEngineContracts` and `ProvenanceEngineSDK`, not PE
SQLite implementation types.

## Future Extraction

If PE is extracted again, use this ADR, the migration ledger, the subtree merge
commit, and `Packages/macOS/ProvenanceEngine/Package.swift` as the extraction
boundary. Preserve root Project Truth history or generate an exported PE slice
of it rather than copying stale state manually.

