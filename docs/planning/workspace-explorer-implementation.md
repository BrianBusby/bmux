# Project and Workspace Explorer implementation record

## Sources and ownership

- Design: `/Users/brianbusby/Downloads/design_handoff_workspace_explorer/README.md`, `FIXTURES.md`, and `prototype/Explorer v2.dc.html`.
- Rules: root `AGENTS.md`; `skills/bmux-architecture/SKILL.md`, `skills/bmux-testing/SKILL.md`, `skills/bmux-localization/SKILL.md`, `skills/bmux-shared-behavior/SKILL.md`, and the continuous-code-quality skill.
- Existing UI sources: `Sources/Sidebar/SidebarWorkspaceSnapshotBuilder.swift`, `Sources/WorkProvenance/WorkspaceDisplayCurrentStateSnapshot.swift`, and `Sources/ContentView.swift`.
- Restore path: `Sources/ClosedItemHistory.swift`, `Sources/AppDelegate+ClosedItemHistory.swift`, and `Sources/TabManager.swift`.
- PE boundary: `Packages/macOS/ProvenanceEngine/Sources/ProvenanceEngineContracts/ProvenanceEngineClient.swift` and its workspace/session response contracts.

The PE archive foundation stores Explorer snapshots in a separately clearable table; these snapshots are excluded from the immutable ledger and its projection rebuild. An explicit clear removes Explorer archive entries, while the ledger and session evidence remain (user decision, 2026-10-20). The Explorer coordinator owns scope, navigation, and per-view arrangement state. Lazy rows receive immutable card snapshots and action closures. TabManager remains the owner of live activation and restoration. PE owns durable historical facts and bounded history queries. bmux supplies live presence and connection state through public contracts, never PE tables. The adapter reads PE through its public client, joins by `Workspace.stableId`, and treats an archive read failure as closed count unknown while retaining live cards.

## Dependency audit on `origin/main` (2026-10-20)

| Design need | Current evidence | Required work |
| --- | --- | --- |
| Stable workspace ID | `Workspace.stableId` is persisted in `SessionWorkspaceSnapshot.stableId` and PE display uses it. `Workspace.id` and the closed restore entry use a runtime UUID that changes on restore. | Key archive and Explorer cards by `stableId`; verify restore adoption and handle legacy snapshots without one. |
| Project, ticket, PR facts | PE workspace display exposes links and PR fields for one workspace. | Add bounded historical enumeration/read. Project owner/status and ticket status lack a demonstrated source; use Unknown buckets until authoritative facts exist. |
| Closed workspace archive | `ClosedItemHistoryStore.restoreFirstRestorable` removes a restored record. | PE's public close-snapshot archive and bmux's user-close producer exist; add workspace-keyed session history and explicit Explorer clear UI, keeping restore eligibility separate. |
| Session history | PE exposes `sessionTree`, factual projection, and turn detail for known session IDs. | A bounded workspace-keyed session query now covers linked lifecycle, prompt, and turn evidence and reports partial coverage; use existing per-session detail contracts in the UI. |
| Meaningful activity | Workspace display has observation/update and prompt times, but metadata refresh is not work. | Derive activity from accepted work events; never filter on projection update time. |
| Live status | Error/Needs input/Running/Idle/Disconnected precedence is a design assumption. | Map to verified bmux session and connection signals and test precedence. |
| Reopen | TabManager restores snapshots through existing actions. | Add targeted restore by logical workspace ID, report eligibility, preserve PE history, and never start an agent implicitly. |

## Delivery sequence

1. PE close-snapshot archive foundation: public bounded read/write/clear contracts, version 26 clearable archive storage, stable-ID deduplication, and rebuild retention tests. The bmux user-close producer combines PE's linked session lifecycle, prompt, and turn activity with the last submitted prompt; broader activity sources remain.
2. Add a bmux adapter that joins PE history with live TabManager presence. Reuse the existing restore action. Test close, reopen, missing worktree, and query failure. The `workspace-explorer-adapter` branch implements this boundary; Explorer reopen strips persisted agent and tmux startup commands before the existing restore action. Only direct local workspace snapshots with a present directory are eligible in this slice. A closed-window-only or remote snapshot remains readable but cannot be reopened from Explorer yet.
3. Add a pure Explorer projection for scope, grouping, filter intersections, unique counts, and held status arrangement. Exercise `FIXTURES.md`, including multi-project overlap and missing metadata. The `workspace-explorer-projection` branch owns this normalized model; a future native coordinator will adapt live/archive facts. Missing-bucket keys are internal and must be localized before display.
4. Add native overview, project, and read-only detail views with localized English/Japanese copy. Preserve per-view navigation state and shared scope.
5. Add motion and accessibility, then run focused tests, project-doc gates when status changes, tagged build, keyboard/reduced-motion and dense-fixture checks. Dogfood before merge.

## Open decisions and verification

- Retain archived workspace metadata and captured session summaries until explicitly cleared (user decision, 2026-10-20). Clearing hides Explorer records but preserves PE session evidence. Add the UI clear path and make coverage visible; do not imply complete historical capture for pre-feature records.
- Freeze project, PR, and ticket metadata at close for read-only detail. Open cards may use current authoritative display facts.
- Verify restored workspace IDs through the real TabManager path and retain the archive record after restore. The focused adapter tests exercise this path.
- Local restore eligibility checks the recorded directory. Remote and closed-window-only snapshots are currently unavailable for targeted Explorer reopen; the existing recently closed menu keeps its own restoration behavior.
- Close capture currently runs asynchronously and can be canceled by immediate app termination. Reconcile persisted recently-closed snapshots on startup, or provide a bounded termination flush, before calling capture durable for every close.
- Verify period/date and animation behavior on supported macOS versions.
