# Work Brief on-demand questions

The Ask section answers bounded questions over the same immutable source facts
as the visible brief. It supports attention, in-progress work, explicit review
waits, and ticket-to-PR links backed by accepted local provenance. Answers are
deterministic and render source-backed rows and URLs. The question text and
answer are held only in the view while it is open; there is no provider runtime,
server, prompt submission, or stored question history.

This is a deliberately narrow first conversation surface. Unknown wording and
missing explicit relationships produce an honest unavailable answer. It does
not infer links from branch names, change canonical source status, or grant
terminal input or external write capabilities. Recent changes and broader
natural-language synthesis remain separate slices. The domain answerer owns
classification; the UI owns localized wording and user-clicked navigation.

Verification: `swift test --package-path Packages/macOS/BmuxWorkBrief`,
`swift build --package-path Packages/macOS/BmuxWorkBriefUI`, project-doc gates,
localization audit, tagged reload, and tagged runtime dogfood.
