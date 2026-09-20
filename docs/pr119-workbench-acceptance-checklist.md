# PR #119 workbench acceptance checklist

Reference: `pr-119-swift-design-package.zip`, `approved-workbench-reference.png`.

Rendered evidence below distinguishes the supplied build-609 screenshot from the isolated native route `bmux DEV hybrid-focus-reference`, build 610. The live window is 1000×700, dark appearance, global font magnification 110%; the new rich rail and Focus/history fixtures are Debug-only and opt-in via `bmux.hybridFocus.fixture`, and never enter the workspace store or provider path. An independent reviewer inspected the original reference and the supplied screenshot; build 610 is compiled and on-screen but CUA cannot attach.

| Requirement | Status | Evidence | Exception or remaining defect |
| --- | --- | --- | --- |
| R1 outer charcoal shell | partial | Supplied build-609 dark Chat screenshot; build 610 source/build | The corrected build retains the coordinated dark shell; final rendered after-capture is unavailable. |
| R2 workspace rail density | implemented—visually unverified | Build 610 DEBUG fixture path `HybridWorkbenchFixtureRail` in `Sources/ContentView.swift` | Three rich cards, retained purple selection, status/activity and scrollable resource rows are now in the native sidebar composition. CUA cannot attach to verify geometry. |
| R3 rich workspace cards/resources | implemented—visually unverified | Build 610 DEBUG fixture cards in `Sources/ContentView.swift` | Separate selection button and Link controls, multiple references, PR state/owner, project, long activity and honest missing references are implemented. Fixture evidence is not live metadata proof. |
| R4 stacked workspace header/chips | visually verified | CUA dark Focus capture | Live PR chip is present; owner/project overflow fixture remains to be reviewed. |
| R5 intrinsic Focus/Chat/Terminal/Learnings nav | visually verified | CUA dark Focus and Learnings captures | No known mismatch at the live logical size. |
| R6 current-turn card | implemented—visually unverified | Build 610 DEBUG Focus fixture in `Sources/Panels/AgentSessionFactualProjectionView.swift`; live Focus implementation retained | Current objective, status, concise result, source-qualified checks and expandable tool evidence are represented in the same native Focus host. Fixture data is explicitly non-telemetry. |
| R7 quiet prior-turn history | implemented—visually unverified | Build 610 DEBUG Focus fixture in `Sources/Panels/AgentSessionFactualProjectionView.swift` | Three stable newest-first rows expand to Changed/Checked/Remains; live ordering/projection behavior remains covered by existing tests. Fixture is not live PE history. |
| R8 Learnings/footer honesty | partial | CUA dark Learnings capture; independent review | Honest unavailable state is present; reference-style learning strip and restrained footer are not present. |
| D1 header before navigation | pass | CUA dark Focus capture | — |
| D2 stacked repo/title/chips | pass | CUA dark Focus capture | — |
| D3 label-width underline/order | pass | CUA dark Focus capture | — |
| D4 joined selected outline/no seam | implemented—visually unverified | Build 610 source path; shared border uses assigned workspace color and the full-height sidebar divider was removed | CoreGraphics sees the build-610 window on-screen, but CUA returns `-10005: cgWindowNotFound` before after-capture. |
| D5 selected links move/header | implemented—visually unverified | Build 610 source path; independent review of supplied build 609 screenshot identified the remaining selected subtitle duplication and it is corrected | Selected cards omit prompt-derived description/subtitle while preserving notification status; final rendered after-capture is blocked. |
| D6 dark Focus composition | implemented—visually unverified | Build 610 DEBUG Focus fixture and shared Focus host | Populated current/history composition is reachable through the normal Focus tab in fixture mode; no rendered build-610 screenshot due CUA attach failure. |
| live Terminal route | pass | CUA build 607 Terminal capture | Native terminal remains the active provider surface. |
| live Chat route | partial | Supplied build-609 dark Chat screenshot | Same shell/nav is shown; draft/identity retention is not proven by this image. |
| narrow/light themes | pending | Not yet captured in this checkpoint | Must capture after shell correction. |
| capture path | fail | CoreGraphics: PID 55403, window 11654, on-screen, 1000×700, sharing state 1; CUA exact app attach | CUA still returns `Computer Use server error -10005: cgWindowNotFound`; `screencapture` cannot create an image because Screen Recording authorization is false. No system permissions were changed. |
