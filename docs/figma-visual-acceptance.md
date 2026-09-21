# Figma shell visual acceptance checkpoint

Updated: 2026-09-21

## Authority and evidence

- Approved Session reference: `/Users/brianbusby/Desktop/Screenshot 2026-09-20 at 6.25.55 PM.png`
- Approved Terminal reference: `/Users/brianbusby/Desktop/Screenshot 2026-09-20 at 6.25.43 PM.png`
- Current tagged build: `figma-production-integration`, build 636
- Current live captures: `/tmp/figma-production-build636.png`, `/tmp/figma-production-session636.png`, `/tmp/figma-production-terminal636.png`
- Capture dimensions: live window 1000×700 logical points; native window capture includes title-bar/shadow pixels. The CUA capture is the reliable composite for the terminal portal; `screencapture -l` omits the portal-hosted terminal layer.

## Acceptance checklist

| Area | Status | Evidence / remaining work |
| --- | --- | --- |
| Shell surfaces and colors | In review | Build 636 uses the corrected dark surface palette and app-shell border; compare at the reference scale again after the next build. |
| Workspace rail and cards | In review | Live workspace names, paths, and provenance links render. Build 636 shows ticket, owner, project, PR, and PR-owner links for a live workspace. |
| Typography, contrast, spacing, alignment | In review | Current capture is legible but uses a smaller 1000×700 window than the approved tall reference; perform one more component comparison. |
| Header and navigation | Pass for current scope | Header, repo-launcher shortcut, workspace count, Session/Terminal/Native navigation are present; no production “Design concept” label. |
| Session summary, disclosures, history | Pending live-content audit | Empty/no-session workspaces honestly show unavailable state. A live session shows PE identity/latest-turn facts; confirm all reference-era controls are sourced or explicitly unavailable. |
| Conversation, composer, buttons, footer | Pending functional audit | The live terminal path is present and nested picker tabs are suppressed. Queue/Stop/source/overlap behavior still needs end-to-end verification in an isolated session. |
| Narrow-window behavior and existing functionality | Pending | Current 1000×700 capture is stable. Verify a no-session workspace and a second session workspace after the final rebuild. |

## Findings and next actions

1. Build 636 session capture matches the shell hierarchy: rail and content pane are siblings, and workspace resource links are visible and clickable in the card.
2. Build 636 terminal capture through CUA shows the live terminal inside the outer shell with no nested Terminal/Chat/Session picker. The raw window capture omits the portal layer, so final terminal evidence must use CUA or a full-screen capture.
3. The selected `Company-Cam-API` workspace has no linked PE session and correctly shows an unavailable state; this is live-data evidence, not a fixture.
4. The fixture-only reference implementation remains behind explicit `showsAppShell && fixturePreviewEnabled` guards and is not passed by production `ContentView`.
5. Next: verify queue/stop/link actions, run the independent visual review against the two approved screenshots plus the saved live captures, correct any material mismatch, rebuild with the tagged script, and update this checklist to final status.
