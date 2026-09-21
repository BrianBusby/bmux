# Figma shell visual acceptance checkpoint

Updated: 2026-09-21

## Authority and evidence

- Approved Session reference: `/Users/brianbusby/Desktop/Screenshot 2026-09-20 at 6.25.55 PM.png`
- Approved Terminal reference: `/Users/brianbusby/Desktop/Screenshot 2026-09-20 at 6.25.43 PM.png`
- Approved Conversation reference: `/Users/brianbusby/Downloads/approved-conversation-design.png`
- Current tagged build: `figma-production-integration`, build 649
- Current live captures: `/tmp/figma-production-session-649.png`, `/tmp/figma-production-chat-649.png`
- Capture dimensions: live window 1000×700 logical points; native window capture includes title-bar/shadow pixels. The CUA capture is the reliable composite for the terminal portal; `screencapture -l` omits the portal-hosted terminal layer.

## Acceptance checklist

| Area | Status | Evidence / remaining work |
| --- | --- | --- |
| Shell surfaces and colors | Pass for native shell | Build 647 Session capture uses the approved dark shell surfaces and readable native foregrounds. Embedded Chat capture is retained below for independent review. |
| Workspace rail and cards | Pass | Build 645 shows live workspace names, paths, and ticket/owner/project/PR/PR-owner links. |
| Typography, contrast, spacing, alignment | Pass | Build 649 Session and Chat captures are readable at the available 1000×700 logical window and retain semantic transcript/status contrast. |
| Header and navigation | Pass | Header, repo-launcher shortcut, workspace count, and Session/Chat/Terminal navigation are present; production has no “Design concept” label. |
| Session summary, disclosures, history | Pass | Build 645 shows real latest-turn content, command/file counts, reasoning count, truthful no-plan text, compact history, newest-first timestamps, and technical IDs behind Session details. |
| Conversation, composer, buttons, footer | Pass with capability limitation | Build 649 has Chat selected, live transcript rows, readable controls, and truthful read-only status. Queue/Stop are unavailable because this selected session exposes no verified control connection; no inert controls are shown. |
| Narrow-window behavior and existing functionality | In review | Native shell remains stable at 1000×700. No-session evidence from the earlier tagged build remains valid; final-build no-session/Terminal captures still need a clean pass. |

## Evidence for build 649

- Live Session capture: `/tmp/figma-production-session-649.png` shows real `companycam-mobile` workspace content, PE latest-turn data, links, disclosures, and history.
- Live Chat capture: `/tmp/figma-production-chat-649.png` has Chat selected in the exact final tagged app and shows real transcript rows, readable controls, and the read-only status.
- Build 649 compiles successfully; reload output is recorded in `/tmp/bmux-reload-figma-production-integration.log`.
- Fixture evidence remains separate: the fixture-only reference shell is still guarded by `showsAppShell && fixturePreviewEnabled`; production `ContentView` does not pass preview fixtures.

## Findings and next actions

1. Build 645 Session confirms the rail/content hierarchy and live workspace resource links.
2. Production navigation is Session / Chat / Terminal; Chat delegates to the existing renderer/coordinator and Terminal remains the native terminal path.
3. The selected live workspace has factual PE data; no-plan and other missing-data states are honest. Technical identity/evidence is disclosed rather than used as the overview.
4. The fixture-only reference implementation remains behind explicit preview guards and is not passed by production `ContentView`.
5. Independent reviewer found the P1 theme interpolation defect and two fallback regressions; those were removed/corrected before build 649. Final Chat screenshot confirms readable semantic transcript styling.
6. Queue/Stop/source/overlap remain delegated to the live renderer path. The selected session advertises read-only/no verified control connection, so no send/queue/stop mutation was falsely claimed as exercised.
