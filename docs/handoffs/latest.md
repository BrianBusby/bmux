# Latest Handoff

## Active Slice

- Slice: `cross_session_artifact_collision_awareness`
- Branch: `cross-session-artifact-collision-awareness`
- Worktree: `/Users/brianbusby/repos/.bmux-worktrees/cross-session-artifact-collision-awareness`
- PR: pending
- Status: implemented locally; validation and PR handoff in progress

## Current Generated Truth

- [Project status](../generated/project-status.md)
- [Nested roadmap](../generated/nested-roadmap.md)
- [Repository status](../generated/repository-status.md)

## What Changed

Provenance Engine now owns deterministic artifact and change collision
awareness through `ProvenanceEngineClient.artifactCollisions(...)`. The read
uses a target PE session, the bounded related-session projection, and exact
Session Outcome revisions to return bounded possible-collision candidates.

Each candidate explains the exact normalized artifact path, participating
sessions, repository/worktree/branch/HEAD boundaries, temporal overlap state,
freshness, completeness, source evidence watermark, related-session projection
revision, Session Outcome revisions, and supporting evidence references. SQLite
schema 24 persists artifact-collision revisions and latest pointers.

Supported reason kinds include exact path overlap, shared repository, same or
different worktree, same or different branch, same or divergent HEAD,
temporally overlapping edits, historical overlap, stale overlap, incomplete
evidence, and unsupported rename identity.

## Boundaries

This is possible collision awareness, not conflict proof or coordination. It
does not infer semantic incompatibility, overwrite certainty, implementation
obsolescence, correctness, merge-conflict certainty, or whether a session should
stop. It also does not add automatic interruption, rebasing, merging, stashing,
file mutation, prompt/context injection, agent-to-agent coordination, raw
transcript sharing, hidden reasoning storage, LLM-authored collision summaries,
proactive bmux notifications, Smart Session collision UI, agent-facing
retrieval, Knowledge Compiler integration, remote sharing, or organization-scale
collision handling.

Rename and stable file identity across moves remain explicitly unsupported
without accepted deterministic rename evidence. Similar paths, same filenames in
different directories, and same relative paths in different repositories do not
become collision candidates.

## Validation

In progress.

No tagged app build or reload is expected because this slice changes PE package
contracts/storage/docs only.

## Known Limitations

V1 artifact identity is exact normalized repository-relative path inside shared
repository identity. It is case-sensitive and lexical; it does not call Git,
inspect the filesystem, resolve symlinks, compare diff hunks, infer components,
or track renames.

The candidate state is factual and freshness-based: current, historical, stale,
or incomplete. It is not a semantic conflict severity or recommendation.

## Next Ready Work

Richer cross-session work-state semantics remain gated on validated milestone
and blocker/approach-change semantics. Agent-accessible cross-session retrieval
remains gated on richer semantics plus validated artifact-collision awareness.
