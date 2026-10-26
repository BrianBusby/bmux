# Work Brief external correlation slice

## Authority and base

User handoff: scoped Linear and GitHub reads, stable external work identities,
source health, explicit relationships, Needs attention and Waiting on, and an
external item without a local workspace. Stacked on `work-brief-local` PR #213;
that branch is under review and must be reconciled before merge. Storage PR #212
has merged. This slice only reads existing PE facts and keeps external facts in
a bounded in-memory snapshot.

Read `AGENTS.md`, context-efficiency status/roadmap/milestones,
`skills/bmux-architecture`, `bmux-testing`, `bmux-localization`,
`bmux-shared-behavior`, `bmux-socket-policy`, `bmux-settings`, and
`/Users/brianbusby/.codex/skills/continuous-code-quality/SKILL.md`.
Existing patterns: `WorkProvenanceSettingsLinearAuthorizationProvider` for
Keychain-backed Linear auth; `WorkProvenanceLinearTicketLinkResolver` for bounded
GraphQL transport/error handling; `BmuxGit/PullRequestProbeService` for GitHub
credential probing and request timeout; `WorkBriefLocalAdapter` for PE boundary.

## API evidence and scope

- Linear's official GraphQL guide documents `viewer`, `viewer.assignedIssues`,
  cursor pagination, `orderBy: updatedAt`, and partial `errors` responses:
  https://linear.app/developers/graphql and
  https://linear.app/developers/pagination.
- GitHub's official search guide documents `review-requested:<login>`,
  `author:<login>`, and `org:` / `repo:` qualifiers:
  https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/filtering-and-searching-issues-and-pull-requests.

Initial scope: Linear issues assigned to the authenticated viewer in the
configured Linear workspace; GitHub open PRs requesting the authenticated
user's review or authored by them, limited to explicitly configured
`org:Name` and `repo:Owner/Name` scopes. The default GitHub scope is empty.
Brian's CompanyCam dogfood should use `org:CompanyCam` in his local settings. The
source also checks requested reviewers on a bounded subset of authored PRs
to place observed review waits in Waiting on. No source expands silently to
all accessible organizations.
Do not fetch issue descriptions, PR bodies, comments, or Slack content. Source
URLs and stable IDs are accepted only from provider responses. Reject invalid
URLs. Reuse existing credential mechanisms; never log tokens or response bodies.

## Ownership and verification

Provider clients own read-only acquisition and bounded retry/cache. The Work
Brief domain owns source facts and deterministic classification/correlation.
The UI renders immutable snapshots and only exposes user-clicked source open or
validated local navigation. The app composition owns lifecycle and config.
PE remains the durable owner of engineering evidence; external facts are
short-lived in-memory data, not PE events or a second unrestricted archive.

Focused fixtures must cover pagination caps, partial API responses, credentials
missing/expired, offline refresh preserving known facts with stale state,
conflicting statuses, exact ticket/PR linkage, no branch-only invented links,
external-without-local rendering, and URL validation. Tagged build and runtime
dogfood must remain isolated from active user builds.
