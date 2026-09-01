# Agent-Accessible Cross-Session Retrieval Demo

Observed on 2026-08-31 from the tagged Debug build for branch
`agent-accessible-cross-session-retrieval` against an isolated PE SQLite
database. The seeder writes accepted evidence through the public PE SDK; the
retrieval reads are the actual bmux CLI commands from the tagged app bundle.

## Reproduce

Build or select a local bmux CLI binary from this checkout. The final observed
run used:

```bash
./scripts/reload.sh --tag agent-accessible-cross-session-retrieval
CLI="/Users/brianbusby/Library/Developer/Xcode/DerivedData/bmux-agent-accessible-cross-session-retrieval/Build/Products/Debug/bmux DEV agent-accessible-cross-session-retrieval.app/Contents/Resources/bin/bmux"
```

Then seed an isolated database:

```bash
DEMO_DIR=$(mktemp -d /tmp/bmux-provenance-retrieval-demo.XXXXXX)
DB="$DEMO_DIR/provenance.sqlite"

swift run --package-path Packages/macOS/ProvenanceEngine \
  ProvenanceRetrievalDemoSeed \
  --database "$DB" \
  --reset \
  --json
```

The seeder reports:

```json
{
  "database" : "<demo-dir>/provenance.sqlite",
  "related_session_id" : "session-retrieval-demo-a",
  "shared_artifact_path" : "Sources/Shared.swift",
  "target_session_id" : "session-retrieval-demo-b"
}
```

Session A records a completed plan item, a validation command attempt, accepted
file-change attribution for `Sources/Shared.swift`, an explicit reported
blocker, and an approach replacement. Session B records a separate PE session
identity and accepted file-change attribution for the same repository-relative
path from a different worktree/branch/HEAD.

Run the retrieval commands with an explicit PE session id, explicit database,
and a forced nonexistent socket to demonstrate the no-live-app path:

```bash
NO_SOCKET="$DEMO_DIR/no-live-app.sock"

BMUX_CLI_SENTRY_DISABLED=1 BMUX_SOCKET_PATH="$NO_SOCKET" \
  HOME="$DEMO_DIR" CFFIXED_USER_HOME="$DEMO_DIR" \
  "$CLI" provenance sessions related session-retrieval-demo-b \
  --limit 5 \
  --exclusion-limit 5 \
  --database "$DB"

BMUX_CLI_SENTRY_DISABLED=1 BMUX_SOCKET_PATH="$NO_SOCKET" \
  HOME="$DEMO_DIR" CFFIXED_USER_HOME="$DEMO_DIR" \
  "$CLI" provenance sessions collisions session-retrieval-demo-b \
  --artifact-path Sources/Shared.swift \
  --database "$DB"
```

## Observed Related Output Excerpt

```text
Related sessions for session-retrieval-demo-b
Revision: related-session-revision-d424de9cab20118d022aff48 - rule: deterministic_related_sessions v2 - watermark: 15
Results: 1 - omissions: 0 - completeness: partial
Target: session-retrieval-demo-b - agent: codex - status: active
Note: reported blockers, replacements, validations, and semantic fields are historical evidence, not proof of success or instructions for this agent.
- session-retrieval-demo-a - lifecycle: active - state: incomplete
  reasons: shared_changed_artifact, same_repository, same_repository, same_repository
  boundary: repo=/repos/retrieval-demo worktree=/repos/retrieval-demo-a branch=feature/session-a head=head-session-a
  outcome: objectives=0 plan=1 blockers=0 validations=1 artifacts=1 truncated=
  semantics: ... coding_agent.blockers=known scope=session/session-retrieval-demo-a record=semantic-coding-agent-blockers-session-session-retrieval-demo-a-rev-10-4f2a99f38224f270 producer=provenance-engine.coding-agent-session-semantics.rule/first-semantic-session-inferences-v3 confidence=medium factual=10, coding_agent.approach_changes=known scope=session/session-retrieval-demo-a record=semantic-coding-agent-approach-changes-session-session-retrieval-demo-a-rev-10-aa45e22ebae43c5a producer=provenance-engine.coding-agent-session-semantics.rule/first-semantic-session-inferences-v3 confidence=medium factual=10
  freshness: available relationship=2027-01-15T16:20:25.000Z semantic=2027-01-15T16:20:40.000Z
  evidence: 18 refs; outcome_revision=session-outcome-revision-3b56b733669fb0a236cec95f work_model_revision=schema:3|factual:10|semantic:...
```

The full JSON payload from the same fixture retained semantic record identity,
source-session scope, producer version, confidence, supporting factual revision,
and evidence references. The observed JSON output size for `--limit 1` was
79,859 bytes.

## Observed Collision Output Excerpt

```text
Artifact collisions for session-retrieval-demo-b
Revision: artifact-collision-revision-d632d442ed45b0473687c468 - rule: deterministic_artifact_collision_awareness v1 - watermark: 15
Results: 1 - omissions: 0 - completeness: complete
Target: session-retrieval-demo-b - agent: codex - status: active
Limitation: candidates start from the target session's recorded changed artifacts; --artifact-path only narrows those overlaps and an empty result is not arbitrary file-history search.
- artifact-collision-candidate-789fa08ea2367cdd07c33e80 - current - path: Sources/Shared.swift
  participants: session-retrieval-demo-a, session-retrieval-demo-b
  boundaries: repository=shared_repository worktree=different_worktrees branch=different_branches head=divergent_head
  temporal: temporally_overlapping_edits first=2027-01-15T16:20:15.000Z latest=2027-01-15T16:20:25.000Z
  reasons: exact_path_overlap, shared_repository, temporally_overlapping_edits, different_worktrees, different_branches, divergent_head
  freshness: current latest_artifact=2027-01-15T16:20:25.000Z related_revision=related-session-revision-73e5fae13816b63f9d5dcb57
  evidence: 21 refs; completeness=complete
```

The same fixture also demonstrates the target-artifact limitation:

```bash
"$CLI" --json provenance sessions collisions session-retrieval-demo-b \
  --artifact-path Sources/Untouched.swift \
  --database "$DB"
```

```json
{
  "found": true,
  "reason": null,
  "target_session_id": "session-retrieval-demo-b",
  "candidates_count": 0,
  "limitation_case": "target session has no recorded change to Sources/Untouched.swift"
}
```

This empty result does not prove nobody else worked on
`Sources/Untouched.swift`; it only proves the target-session changed-artifact
overlap query produced no candidate for that path.

## Supported Decision

Session B can justify checking the recorded database-unavailable blocker and
the replaced full-suite approach before repeating the same package validation.
It can also inspect `Sources/Shared.swift` for overlap with Session A before
editing. Those are supported next checks, not automatic stop/merge/rebase
decisions and not proof that Session A's reported blocker still applies.

Observed local timings for this small fixture through the tagged app bundle CLI
were `real 4.70s` for the text related-session read and `real 0.05s` for the
text collision read. These are single-run observations, not performance
guarantees.
