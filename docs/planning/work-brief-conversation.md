# Work Brief on-demand questions

The Ask section answers bounded questions over the same immutable source facts
as the visible brief. It supports attention, in-progress work, explicit review
waits, and ticket/PR co-occurrence in one workspace backed by accepted local
provenance. The ticket-to-PR relationship is labeled inferred. Answers are
deterministic and render source-backed rows and URLs. The question text and
answer are held only in the view while it is open; there is no provider runtime,
server, prompt submission, or stored question history.

An exact visible pull-request reference or source URL can identify a GitHub
review wait. The answer shows that item's observed reviewer-request evidence.
An unqualified “Why is this blocked?” asks for a reference, and a named item
without observed wait evidence receives an explicit no-evidence answer. Assigned
Linear issue summaries and local-only ticket links do not contain blocker
reasons, so the brief does not explain or invent them. English and Japanese
supported questions use the same
source facts.

This is a deliberately narrow first conversation surface. Unknown wording and
missing accepted co-workspace links produce an honest unavailable answer. It does
not infer links from branch names, change canonical source status, or grant
terminal input or external write capabilities. Recent changes and broader
natural-language synthesis remain separate slices. The domain answerer owns
classification; the UI owns localized wording and user-clicked navigation.

Verification: `swift test --package-path Packages/macOS/BmuxWorkBrief`,
`swift build --package-path Packages/macOS/BmuxWorkBriefUI`, project-doc gates,
localization audit, tagged reload, and tagged runtime dogfood.
