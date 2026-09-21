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

## Final evidence for build 637

- Live Session composite: captured from the tagged build through CUA; it shows the real `companycam-mobile` workspace, PE session identity, thread IDs, latest turn, and prior-turn evidence.
- Live no-session composite: captured after selecting workspace 2 through the tagged CLI; it shows the real `Company-Cam-API` workspace and the honest `No supported coding agent has been detected in this workspace.` state.
- Live Terminal composite: captured from the tagged build through CUA; it shows the original Codex terminal surface inside the outer shell, with no nested Figma picker and the existing terminal input surface intact.
- Raw terminal window capture: `/tmp/figma-production-terminal637.png`. The raw `screencapture -l` path omits the portal-hosted terminal layer; the CUA composite is the authoritative terminal visual evidence.

## Findings and next actions

1. Build 636 session capture matches the shell hierarchy: rail and content pane are siblings, and workspace resource links are visible and clickable in the card.
2. Build 636 terminal capture through CUA shows the live terminal inside the outer shell with no nested Terminal/Chat/Session picker. The raw window capture omits the portal layer, so final terminal evidence must use CUA or a full-screen capture.
3. The selected `Company-Cam-API` workspace has no linked PE session and correctly shows an unavailable state; this is live-data evidence, not a fixture.
4. The fixture-only reference implementation remains behind explicit `showsAppShell && fixturePreviewEnabled` guards and is not passed by production `ContentView`.
5. The independent code reviewer found no defect in the final cleanup. Its environment could not directly render local images, so it is not being recorded as independent visual sign-off. The primary visual comparison used the approved screenshots and final tagged-build composites above.
6. Queue/Stop/source/overlap controls from the old showcase are no longer reachable in production; the real terminal surface owns its existing command path. No isolated live-session mutation was sent during this visual pass, so end-to-end command acknowledgement/failure handling remains outside this screenshot-only acceptance evidence.
