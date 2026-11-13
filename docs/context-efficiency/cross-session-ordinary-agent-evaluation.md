# Ordinary-agent context evaluation

This is a limited development observation, not a general measure of agent
quality. The decision and failed-attempt scenarios are not yet validated.

## Concurrent work: observed

On 2026-11-13 an isolated macOS build 956 was launched through Launch Services
with its own home, PE database, socket, Codex home, and two linked Git worktrees.
The build included the common-directory task selector fix; it was compiled
while follow-up PE changes were being made, so a build from the final pushed
head remains necessary. The fixture repository contained `Sources/CachePolicy.swift`
and maintainer notes about generation-based invalidation.

The writer was an ordinary Codex 0.162.0 terminal session in branch `concurrent`.
Its task was to document cache invalidation in the file. It edited a comment and
left its session open. The normal transcript monitor appended an inferred,
low-confidence file attribution for session
`01a1d3a8-77af-7e63-93c8-5b7df37984f6` without a manual import.

A fresh reader in branch `reader`, with no edits, was asked whether it should
independently change the same file. It independently invoked
`bmux provenance sessions related --current --artifact-path Sources/CachePolicy.swift`.
The sandbox initially denied socket access; the authorized retry outside the
sandbox returned a 12,010-byte compact text response. For the writer it included:

- Recorded lifecycle `active`, recent observation, branch `concurrent`, and the
  observed objective to document cache invalidation in that file.
- Requested-artifact evidence `event-5dfe4d2e84aad4ee6d208b60`, ledger sequence
  214, labeled `inferred`, and outcome revision
  `session-outcome-revision-4d945f0b81a89de0e34f56ee`.
- Objective turn revision `turn-outcome-revision-68e570cb8545bf6234b349e7`.
  Secondary fields and evidence references were omitted and counted by compaction.

The reader followed the outcome revision, inspected the concurrent worktree's
uncommitted two-line comment, and recommended coordinating with that writer
before editing. It made no changes. Earlier fixture sessions were also returned
with recorded active states; those states are not proof that they were still
running. No retrieval-omitted comparison was run. The material contribution in
this observation was identifying the other worktree and session to inspect.

Reproduction requires an isolated PE home and repository with separate
worktrees. Launch the tagged app via Launch Services with the isolated home,
Codex home, and PE home; direct invocation from an agent process causes bmux's
nested-agent suppression to apply. Start a writer through the bundled Codex
wrapper, request an edit, and keep it open. Start a fresh reader in the other
worktree, ask it to assess overlap, and approve its socket access if the sandbox
requires it. Record the query, returned IDs and revisions, outcome drill-down,
worktree inspection, and decision. This run used real terminal transcript
capture; earlier seeded fixture checks are documented separately in
[cross-session-task-relevance-evaluation.md](cross-session-task-relevance-evaluation.md).

## Remaining scenarios

- **Prior useful decision:** establish a case in which the decision is not
  already visible from the reader's prompt or local files; capture the evidence
  reference and the materially supported next action.
- **Prior failed attempt:** capture the failure and conditions, then show a new
  agent checking whether those conditions still apply before selecting its next
  action.

A previous manual transcript import established that the importer could recover
inferred nested patch evidence; it is not counted as the automatic live capture
above. A separate global Codex 0.162.1 fixture encountered IPC decoding errors.
