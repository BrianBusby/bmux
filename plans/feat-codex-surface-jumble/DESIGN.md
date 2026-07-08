# Codex sessions jumble (restore into the wrong surface) after reload

Root cause from an adversarially-verified workflow (4 investigators + verify + synthesis, high confidence). Distinct from the cwd-drift work (#5300/#5312): that is the **directory** axis; this is the **surface-mapping** axis. Own PR.

## Symptom
After reload, a codex session restores into the WRONG surface/pane (single-leak = wrong surface; with a second codex, the two surfaces swap sessions). The cwd is correct in each (codex is `.cwdInFile` and keeps its recorded cwd), so it looks like a coherent session in the wrong pane — "jumbled".

Only reproduces via the codex-family CLI launchers (`bmux omx` / oh-my-codex, `bmux codex-teams`, the teams launchers). A plain `codex` started directly in a shell does NOT jumble.

## Root cause (durable bug = wrong surfaceId written at spawn/hook time, NOT a restore mis-map)
`CLI/bmux.swift:17301-17306` (`configureTmuxCompatEnvironment`) overwrites **only** `BMUX_WORKSPACE_ID` / `BMUX_SURFACE_ID` from the operator's globally-focused pane (`focusedContext`, resolved via `system.identify` → `TerminalController.swift:4178-4181` selectedTabId+focusedPanelId), while leaving `BMUX_PANEL_ID` / `BMUX_TAB_ID` at the launch surface. So codex launched in surface B while A is focused gets `BMUX_SURFACE_ID=A` but `BMUX_PANEL_ID=B` (desynced). This helper feeds OMX/OMO/OMC + claude-teams.

Contrast: the in-app per-surface terminal env (`Sources/TerminalStartupEnvironment.swift:40-44` `applyManagedBmuxContextEnvironment`) sets all four IDs from the surface's OWN id (matched), which is why plain codex is fine.

The leaked `BMUX_SURFACE_ID=A` then:
- is **preferred over PID truth** by the codex/generic hook: `runGenericAgentHook` reads `directSurfaceArg = env BMUX_SURFACE_ID` (`CLI/bmux.swift:26912-26913`); the processBinding PID corrector is **suppressed** by the guard at `26945-26947` precisely when both env IDs are populated; `resolveTarget` prefers `preferredSurfaceId = env` first (`27134-27136`).
- is **persisted durably** as the SurfaceResumeBinding: `publishAgentSurfaceResumeBinding` → `surface.resume.set` (`24379-24394`) → `TerminalController.swift:8772 setSurfaceResumeBinding(panelId: A)` → serialized into the panel snapshot → re-bound inline at reload (`Workspace.swift:1602`). **This path has NO live-pid gate**, which is why the wrong id survives reload.

The restore map (`RestorableAgentSession.swift:1009-1010,1033`) faithfully propagates the poisoned id; its one corrector (`liveScopedProcessID` / `matchesBMUXScope`) is defeated because `BmuxTopSnapshotScopeCache.swift:113-114` reads `BMUX_SURFACE_ID` before `BMUX_PANEL_ID`, so the live process corroborates the leak.

`codex-teams` root does NOT call `configureTmuxCompatEnvironment` (root codex inherits the correct `launcherEnvironment`); its parallel leak rides the watcher CLI args at `CLI/bmux.swift:18276-18279` (`--workspace-id focusedContext.workspaceId --surface-id rootSurfaceId`, `rootSurfaceId = focusedContext.surfaceId` at 18178).

## Fix plan (two-commit red/green)
1. **PRIMARY** `CLI/bmux.swift:17301-17306`: prefer the launching process's OWN `BMUX_SURFACE_ID`/`BMUX_WORKSPACE_ID` (set correctly at terminal creation by `applyManagedBmuxContextEnvironment`); fall back to `focusedContext` only when the process has no own id. Never overwrite to a value that disagrees with the inherited `BMUX_PANEL_ID`/`BMUX_TAB_ID`. Keep `focusedContext` only for the cosmetic `TMUX`/`TMUX_PANE` shim (17274-17284). One helper feeds OMX/OMO/OMC + claude-teams.
2. **SYMMETRIC** `CLI/bmux.swift:18276-18279` (runCodexTeams watcher args): pass the launcher's own surface/workspace, not `focusedContext`.
3. **DEFENSIVE** `CLI/bmux.swift:26945-26947`: drop the `directSurfaceArg != nil` term from the guard so the PID/TTY corrector (`resolveAgentProcessTerminalBinding`, 21717-21756) still runs and can override a leaked env even when both env IDs are populated. (Mirror claude's `resolvePreferredSurfaceIdForClaudeHook(preferred: mappedSession?.surfaceId)` at 20854-20859 for id-keyed agents on prompt-submit/teardown.) Note: does not fix session-start write (mapped is nil there), so #1 stays primary.
4. **OPTIONAL** `Sources/BmuxTopSnapshotScopeCache.swift:113-114`: key the scope check on `BMUX_PANEL_ID`/launch-cwd (which the leak never corrupts) so restore self-heals against future single-key leaks. Low priority.

## Test plan
- **True-source** (seam = launcher env builder): drive `configureTmuxCompatEnvironment`/`configureOMXEnvironment` with own `BMUX_SURFACE_ID`/`BMUX_PANEL_ID`=B and a stubbed focused-context resolver returning A; assert child env `BMUX_SURFACE_ID==B` AND `BMUX_SURFACE_ID==BMUX_PANEL_ID` (matched-pair invariant). RED: A while PANEL=B. Needs a seam to inject the focused-context resolver.
- **Symmetric codex-teams**: focused=A, launch=B; assert watcher argv `--surface-id`/`--workspace-id` (18276-18279) == B.
- **Hook guard** (seam = subprocess `bmux hooks codex session-start` via `CLINotifyProcessIntegrationRegressionTests`): leaked env A, PID in surface B; capture `surface.resume.set` → RED surface_id=A, GREEN=B after dropping the 26945 guard term.
- **Survives-reload** (seam = SurfaceResumeBinding persistence): `v2SurfaceResumeSet(surface_id=A)` → serialize → reload → assert `createPanel` re-binds into A before, B after. No pid gate → deterministic.
- **DON'T** rely on a synthetic `RestorableAgentSessionIndex.load`-only test: it keys faithfully by `record.surfaceId`, so a hand-written wrong id resolves identically red and green and proves nothing.

## Related issues
- https://github.com/manaflow-ai/bmux/issues/4920 (spawn env leaks focused workspace/surface IDs) — the source.
- https://github.com/manaflow-ai/bmux/issues/695 (codex-hook routes to wrong workspace/session) — the symptom; codex prefers env over the session-keyed mapping unlike claude-hook.
