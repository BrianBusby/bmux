# Work Brief implementation record

## Authority and status

The user requested a built-in, configurable Work Brief in coherent slices. The
first slice is local presence and accepted PE display facts; external reads,
conversation, and Slack are later slices. Ordinary terminal Codex evidence is
already implemented in the maintained bmux mainline. PE outcome retention is on
PR #212; its live database reclamation is deferred by user direction. Work Brief
must not read PE SQLite directly or generate canonical coding-agent milestones.

## Governing sources and maintained patterns

- `AGENTS.md`; `skills/bmux-architecture`, `bmux-shared-behavior`,
  `bmux-socket-policy`, `bmux-localization`, `bmux-testing`;
  `/Users/brianbusby/.codex/skills/continuous-code-quality/SKILL.md`.
- `docs/architecture/README.md`, `docs/architecture/system-overview.md`,
  `docs/provenance-integration.md`, `docs/generated/ownership-boundary.md`.
- `WorkspaceExplorerHistoryService` supplies live presence plus PE display facts;
  `WorkspaceExplorerScenes` shows app composition; `WorkspaceExplorerCommands`
  is the menu entry pattern; `AppDelegate.activateWorkspaceExplorerWorkspace`
  uses the shared workspace selection action.

## Ownership

`BmuxWorkBrief` owns bounded source facts, evidence labels, source health, and
pure classification. `BmuxWorkBriefUI` owns immutable card rendering and
explicit user actions. The app composition maps existing Explorer/PE results to
facts and validates navigation targets through existing shared actions. PE
remains the durable source for accepted local evidence. External provider
acquisition and bounded cache ownership will be added in separate services,
with no raw message archive or external write capabilities.

## Delivery and verification

1. Built-in local destination with live In progress and evidence inspection,
   partial-source state, and explicit Jump to workspace. Background refresh
   updates the view only. Add exact surface highlighting only when accepted
   association evidence provides a surface ID and the target still exists.
2. Scoped Linear/GitHub reads and correlation, health and stale states, and
   Needs attention/Waiting on rules.
3. On-demand cited briefing conversation over the bounded projection.
4. Opt-in selected Slack channels with narrow retention and no DMs or posting.
5. CompanyCam dogfood, targeted navigation/typing checks, tagged build, and
   project-doc validation/generation/check.

The first slice must not imply external sources are connected or that the
assistant can change external systems or send terminal input. Review each
slice against the complete affected architecture before expanding it.

## Local slice verification and limits (2026-10-26)

- `BmuxWorkBrief` remains pure source facts and classification. Refresh state lives in
  `BmuxWorkBriefUI`. The app maps existing live Explorer/PE reads and owns
  validated navigation. The view has no shell, socket, or terminal-input action.
- The producer caps open workspaces at 100, external links at 12 per workspace,
  and PE association reads at 32 per refresh. Refreshes coalesce while one
  read is in flight; the initial presence snapshot appears before PE enrichment.
- Package tests: two domain cases passed. Focused app tests: two adapter cases
  passed, including rejection of non-HTTPS source links and partial-source
  honesty. Package UI build, tagged app build 899, test-wiring, package grouping,
  Swift file-length budget, localization key audit, and project-doc
  validate/generate/check passed. Tagged build 900 succeeded on the committed
  code; its isolated socket answered a bounded window-count query (one window).
  The app launched, but CUA could not attach to its window (`cgWindowNotFound`),
  so card rendering and click navigation still need visual dogfood.
- Some PE display records have no field-level event reference. Those cards show
  the accepted source and observation time, plus an explicit source link where
  one exists; they cannot open raw event payloads through the current PE SDK.
  External work correlation, conversation, and Slack remain later slices.
