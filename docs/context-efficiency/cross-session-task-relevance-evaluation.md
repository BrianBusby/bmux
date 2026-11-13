# Cross-session task relevance evaluation

This is a proposed, not yet executed, isolated PE evaluation. IDs and expected
results are fixed here before implementation or ranking tuning. Seed evidence
through public writes, with `caller` in repository `eval-repo`, no changed
artifacts, and separate branches/worktrees for the path sessions. The corpus
must also include `unrelated` in the same repository and `other-repo` outside
it. Times and revisions must be fixed so repeated reads have identical inputs.

| Query and condition | Required session IDs | Additional assertion |
| --- | --- | --- |
| Path `Sources/Example.swift` | `path-active`, `path-history` | Both branches and worktrees are distinguishable. |
| Ticket `EVAL-42` | `ticket-exact` | Exact linked identifier outranks `unrelated`. |
| Objective `repair cache invalidation` | `objective-attempt` | Labeled text match and source reference are present. |
| Recorded blocker and resolution | `blocker-old`, `blocker-resolution` | Evidence shows chronology and the recorded relationship; unknown validity stays unknown. |
| Missing task metadata | none | Availability or unsupported state is explicit. |
| No matching selector | none | Empty state is explicit. |
| Path with more relevant results than limit | `budget-1`, `budget-2` | Stable selected IDs and omission count over repeated reads; remaining IDs `budget-3`, `budget-4` are relevant. |

For the first four rows, all listed IDs are required within the requested limit.
For the budget row, fix the fixture's evidence and declared ranking keys so the
first two IDs are the expected winners before measuring. `unrelated` and
`other-repo` are irrelevant for every selector query; `other-repo` must never be
returned by the default scope. If selector semantics deliberately allow broad
same-repository fallbacks, direct matches must rank above them and the output
must label the fallback.

Pass thresholds: 100% required-result recall at the stated limits; zero
`other-repo` inclusions; zero `unrelated` inclusions ahead of a required direct
match; a usable source ID and revision on every direct match; identical ranking,
revision, and omissions for repeated reads against the same evidence; and no
compact JSON response above 12 KiB. Record actual sizes, counts, source
references, and failures rather than reporting these targets as results.

Open evidence questions: Session Outcome exposes observed objectives; workspace
display records expose ticket IDs and links, but session association and ticket
availability must be verified through public paths. Artifact-collision reads are
caller-change-based today, so arbitrary path selection requires a PE-owned read
that can discover candidates independently of the caller's changes. Existing
caller resolution fails closed for some reused panes and shared daemon sessions;
evaluation must not treat those unavailable cases as successful retrieval.
