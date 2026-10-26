# BmuxWorkBriefSources

Read-only, bounded Linear and GitHub acquisition for Work Brief. The package
returns short issue/PR facts and source health to `BmuxWorkBrief`; it never
stores descriptions, comments, message bodies, credentials, or provider
responses. The app owns source configuration, credential lookup, lifecycle,
and presentation. PE remains the owner of accepted engineering evidence.

`LinearWorkBriefSource` reads up to two pages of 50 issues assigned to the
Linear viewer. `GitHubWorkBriefSource` reads up to four explicit `org:Name` or
`repo:Owner/Name` scopes, 50 recent open PRs per search, and reviewer requests
for at most ten authored PRs per refresh. Additional results mark the source
partial. Both actors keep at most 100 prior summaries in memory and preserve
them with their original `checkedAt` on a failed refresh. They expose stable
reason codes without logging provider content or tokens. The URLSession
transport stops reading after 2,000,000 response bytes, before JSON decoding.

`WorkBriefExternalLoader` reuses the previous provider result for automatic
local-change refreshes within 60 seconds. An explicit user refresh always
checks providers. This prevents PE display notifications from producing
unbounded external API traffic while keeping the local workspace view current.

Tests inject `WorkBriefHTTPClient` and credential/scope closures:

```swift
let source = LinearWorkBriefSource(
    authorization: { "fixture-token" },
    http: FixtureHTTPClient()
)
let result = await source.refresh(at: fixedDate)
```

Source facts are never written into PE or used as canonical coding-agent
milestones. Exact ticket IDs and PR URLs can correlate them with local PE
links; branch-name similarity alone does not establish a relationship.
