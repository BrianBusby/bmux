# Provenance Engine Handoff

## Slice

- ID: `semantic_inference_framework`
- Title: Semantic Inference Framework Foundation
- Repository: `BrianBusby/provenance-engine`
- Implementation branch: `semantic-inference-framework`
- Implementation worktree: `/private/tmp/pe-semantic-inference-framework`
- Implementation PR: [#26](https://github.com/BrianBusby/provenance-engine/pull/26)
- Implementation commit: `d66e847c5cb71d7a63a3d0b3ecdf3c29b65c1f28`
- Implementation merge commit: `5c0a82e433fcce809b6d099a9482ae41418e1c08`

## Acceptance

Accepted as implemented. The slice adds public semantic inference contracts,
bounded inference input and invalidation/coalescing contracts, SQLite schema v18
persistence, query/publish APIs, and transactional supersession. Semantic
records remain above deterministic factual projections and do not add concrete
semantic concepts yet.

## Verification

Run on the implementation branch before merge:

```bash
swift test
./scripts/project-docs validate
./scripts/project-docs check
./scripts/project-docs ci
git diff --check
```

`swift test` passed with 116 tests.

## Docs Sync

- Sync branch: `docs/semantic-inference-framework-sync`
- Status: updates canonical roadmap/repository status and regenerated docs for
  PR #26.
- Generated project status: [docs/generated/project-status.md](../generated/project-status.md)
- Canonical roadmap: `semantic_inference_framework` is implemented and
  `first_semantic_session_inferences` is next eligible.

## Dependencies

Now satisfied:

- `factual_projection_consumer_shape_followup` -> `semantic_inference_framework`
- `semantic_inference_framework` -> `first_semantic_session_inferences`

Active parallel slices: none.

## Next Eligible Work

Start `first_semantic_session_inferences` after this docs sync branch is merged.
Keep it below milestone, architecture, messaging, and bmux UI scope. Use a fresh
implementation branch/worktree and treat blocker/approach-change semantics as a
later slice unless the canonical roadmap is explicitly changed.

## Caveats

- The semantic framework stores inference records and supporting provenance; it
  does not infer thread intent, turn intent, phase, current activity, milestones,
  architecture, or presentation wording.
- The docs-sync branch should not be combined with the next implementation
  slice.
