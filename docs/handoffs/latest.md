# Provenance Engine Handoff

## Slice

- ID: `human_readable_semantic_messaging`
- Title: Human-Readable Semantic Messaging Foundation
- Repository: `BrianBusby/provenance-engine`
- Implementation branch: `human-readable-semantic-messaging`
- Implementation worktree: `/private/tmp/pe-human-readable-semantic-messaging`
- Implementation PR: [#30](https://github.com/BrianBusby/provenance-engine/pull/30)
- Implementation commit: `ec0baa4b0d83b2a1025c6d6a0c0b4a8d15416e65`
- Implementation merge commit: `1b7e97d30c137b2666836a6233be78c35ab2e5fd`

## Acceptance

Accepted as implemented. The slice adds the first PE-owned presentation layer
above semantic inference:

- `ProvenanceSemanticMessageRecord`
- presentation policy identity/version
- public publish/query/materialization contracts
- deterministic default renderer for first coding-agent semantic kinds
- SQLite semantic-message cache/history table with supersession

Messages carry concise and expanded wording while preserving structured semantic
meaning, supporting evidence refs, factual revision, confidence, specificity,
producer identity/version, presentation policy, and history. Semantic truth
remains in semantic inference records; deterministic Current State remains
factual-only.

## Verification

Run on the implementation branch before merge:

```bash
swift test --filter SemanticMessageFoundationTests
swift test --filter ProvenanceSQLiteDatabaseTests
swift test
./scripts/project-docs validate
./scripts/project-docs check
GH_TOKEN=$(gh auth token) ./scripts/project-docs ci
git diff --check
```

`swift test` passed with 134 tests.

## Docs Sync

- Sync branch: `docs/human-readable-semantic-messaging-sync`
- Status: updates canonical roadmap/repository status and regenerated docs for
  PR #30.
- Generated project status: [docs/generated/project-status.md](../generated/project-status.md)
- Canonical roadmap: `human_readable_semantic_messaging` is implemented and
  `clickable_semantic_explanation_ui` is next eligible.

## Dependencies

Now satisfied:

- `first_semantic_session_inferences` -> `human_readable_semantic_messaging`
- `human_readable_semantic_messaging` -> `clickable_semantic_explanation_ui`

Active parallel slices: none.

## Next Eligible Work

Start `clickable_semantic_explanation_ui` in `BrianBusby/bmux` after this docs
sync branch is merged. Use the PE semantic message read/materialization contract
as the frozen producer shape; do not infer semantic meaning in bmux.

## Caveats

- The renderer is deterministic and rule-based; it does not call an LLM.
- Presentation language calibration and feedback learning remain planned.
- The clickable bmux UI does not exist yet.
