# Figma shell visual acceptance checkpoint

Updated: 2026-09-21

## Authority and evidence

- Approved Session reference: `/Users/brianbusby/Desktop/Screenshot 2026-09-20 at 6.25.55 PM.png`
- Approved Terminal reference: `/Users/brianbusby/Desktop/Screenshot 2026-09-20 at 6.25.43 PM.png`
- Approved Conversation reference: `/Users/brianbusby/Downloads/approved-conversation-design.png`
- Current tagged build: `figma-production-integration`, build 638
- Current live captures: `/tmp/figma-production-chat638-check.png`, `/tmp/figma-production-chat638-chat2.png`
- Capture dimensions: live window 1000×700 logical points; native window capture includes title-bar/shadow pixels. The CUA capture is the reliable composite for the terminal portal; `screencapture -l` omits the portal-hosted terminal layer.

## Acceptance checklist

| Area | Status | Evidence / remaining work |
| --- | --- | --- |
| Shell surfaces and colors | In review | Build 636 uses the corrected dark surface palette and app-shell border; compare at the reference scale again after the next build. |
| Workspace rail and cards | In review | Live workspace names, paths, and provenance links render. Build 636 shows ticket, owner, project, PR, and PR-owner links for a live workspace. |
| Typography, contrast, spacing, alignment | In review | Current capture is legible but uses a smaller 1000×700 window than the approved tall reference; perform one more component comparison. |
| Header and navigation | In review | Header, repo-launcher shortcut, workspace count, and Session/Chat/Terminal navigation are present; no production “Design concept” label. Chat is now wired to the existing live renderer. |
| Session summary, disclosures, history | Pending live-content audit | Empty/no-session workspaces honestly show unavailable state. A live session shows PE identity/latest-turn facts; confirm all reference-era controls are sourced or explicitly unavailable. |
| Conversation, composer, buttons, footer | Pending functional audit | Chat now mounts `TerminalChatWebRenderer` from the selected workspace’s focused terminal panel. Queue/Stop/source/overlap behavior still needs end-to-end verification in an isolated session. |
| Narrow-window behavior and existing functionality | Pending | Current 1000×700 capture is stable. Verify a no-session workspace and a second session workspace after the final rebuild. |

## Evidence for build 638

- Live Session composite: captured from the tagged build through CUA; it shows the real `companycam-mobile` workspace, PE session identity, thread IDs, latest turn, and prior-turn evidence.
- Live no-session composite: captured after selecting workspace 2 through the tagged CLI; it shows the real `Company-Cam-API` workspace and the honest `No supported coding agent has been detected in this workspace.` state.
- Live Terminal composite: captured from the tagged build through CUA; it shows the original Codex terminal surface inside the outer shell, with no nested Figma picker and the existing terminal input surface intact.
- Build 638 compiles successfully with the new production Chat wiring; build output is recorded in the reload log at `/tmp/bmux-reload-figma-production-integration.log`.
- `/tmp/figma-production-chat638-check.png` is a live session capture showing real workspace/session data and the three primary tabs. The attempted click capture `/tmp/figma-production-chat638-chat2.png` remained on Session because this environment’s native automation surface could not target the off-screen tagged window reliably; it is not Chat sign-off.

## Findings and next actions

1. Build 638 session capture matches the shell hierarchy: rail and content pane are siblings, and workspace resource links are visible in the live card.
2. The production primary navigation is now Session / Chat / Terminal. Chat delegates to the existing renderer/coordinator rather than recreating a fixture composer; Terminal remains the native terminal path.
3. The selected `Company-Cam-API` workspace has no linked PE session and correctly shows an unavailable state; this is live-data evidence, not a fixture.
4. The fixture-only reference implementation remains behind explicit `showsAppShell && fixturePreviewEnabled` guards and is not passed by production `ContentView`.
5. Independent visual sign-off is still pending: the native automation surface could not target the tagged app’s off-screen window, so Chat and Terminal interaction captures could not be completed in this pass.
6. Queue/Stop/source/overlap controls are delegated to the existing live renderer path. No isolated live-session mutation was sent during this visual pass, so end-to-end command acknowledgement/failure handling remains unverified.
