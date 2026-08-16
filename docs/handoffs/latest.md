# Provenance Engine Handoff

## Slice

- ID: `first_semantic_session_inferences`
- Title: First Semantic Session Inferences
- Repository: `BrianBusby/provenance-engine`
- Implementation branch: `first-semantic-session-inferences`
- Implementation worktree: `/private/tmp/pe-first-semantic-session-inferences`
- Implementation PR: [#28](https://github.com/BrianBusby/provenance-engine/pull/28)
- Implementation commit: `50a4fb58a1147feea581eee9d26d45a325b4672d`
- Implementation merge commit: `2c1b2d42fd2affdae9f5f54421e91ad4fd1c5ba3`

## Acceptance

Accepted as implemented. The slice adds the first concrete semantic records for
coding-agent sessions:

- `coding_agent.thread_intent`
- `coding_agent.turn_intent`
- `coding_agent.session_phase`
- `coding_agent.current_activity`

The records are rule-produced from factual session projections, carry typed
structured payloads, preserve supporting evidence refs and factual revision, and
use the existing semantic inference publish/query/supersession path. They do not
write semantic fields into deterministic Current State.

## Verification

Run on the implementation branch before merge:

```bash
swift test
./scripts/project-docs validate
./scripts/project-docs check
GH_TOKEN=$(gh auth token) ./scripts/project-docs ci
git diff --check
```

`swift test` passed with 124 tests.

## Docs Sync

- Sync branch: `docs/first-semantic-session-inferences-sync`
- Status: updates canonical roadmap/repository status and regenerated docs for
  PR #28.
- Generated project status: [docs/generated/project-status.md](../generated/project-status.md)
- Canonical roadmap: `first_semantic_session_inferences` is implemented and
  `human_readable_semantic_messaging` is next eligible.

## Dependencies

Now satisfied:

- `semantic_inference_framework` -> `first_semantic_session_inferences`
- `first_semantic_session_inferences` -> `human_readable_semantic_messaging`

Active parallel slices: none.

## Next Eligible Work

Start `human_readable_semantic_messaging` after this docs sync branch is
merged. Keep it to presentation-oriented semantic message contracts and
generation/cache behavior. Do not start bmux UI, feedback learning, milestone
inference, scoped architecture projection, GitHub ingestion, or Knowledge
Compiler work in the same slice.

## Caveats

- The current semantic implementation is deterministic and rule-based. It does
  not call an LLM or provide model-adapter execution.
- The concise/expanded human-readable messaging layer does not exist yet.
- The docs-sync branch should not be combined with the next implementation
  slice.
