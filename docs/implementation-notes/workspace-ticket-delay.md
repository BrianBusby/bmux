# Workspace ticket observation delay

The follow-up stacks on the workspace-header ticket UI, whose base is the exact
commit used for build 723 (`c262d0b7ca384f79a18af96720d3e2d1f6edbfea`).
Ticket facts still come from PE; the UI does not infer a second ticket state.

## Evidence and bounded change

Build 726 resolved PR 11712 metadata before its INP-2430 ticket appeared. Sampling
showed workspace display persistence waiting for SQLite's writer lock while a
Codex monitor rebuilt historical turn and session outcomes. Current outcome reads
previously rebuilt projections, including reads performed inside append refresh.
Repeated unchanged Git context also invalidated historical repository/worktree
outcomes. Failed workspace observations retained their deduplication fingerprint,
suppressing later attempts to save the same snapshot.

PE now reads current materialized outcome revisions without writing. Missing or
obsolete rule projections recover lazily; session reads validate constituent turn
revision dependencies. Append remains the owner of projection refresh. Unchanged
Git context does not invalidate historical outcomes, and turn-scoped evidence
refreshes both previous and current owners when records are reassigned. Evidence
reads respect the projection sequence so rebuilding from the ledger reproduces
the same outcome. Failed app observations release their matching fingerprint for
retry without clearing a newer in-flight observation. Observation retries at most
three times with a short backoff, stops after cancellation or supersession, and
returns through the existing runtime display refresh path.

The broad multi-process SQLite writer policy remains unresolved. Already-running
apps and CLI monitors retain their old code and can continue holding the shared
writer lock. This slice neither rewrites existing history nor changes database
ownership, storage location, retention, or canonical ticket-link authority.

## Verification

Behavior tests reproduce locked materialized reads, identical snapshot retry after
a failed ticket write, unchanged-context turn refresh, ledger replay, moved prompt
ownership, and obsolete turn dependencies in session caches. The PE suite passes
247 tests. The three affected app observer/resource suites pass 24 tests, including automatic
retry, duplicate notification, cancellation, and supersession cases. A new isolated
tagged build is required before handoff.
A local 30-turn benchmark reduced command append from 489 ms to 84 ms and session
read from 315 ms to 29 ms; this
is synthetic measurement, not a live-workspace latency guarantee.

No labels, tooltips, shortcuts, or other user-facing strings change. The existing
localized ticket control and its authoritative URL remain unchanged.
