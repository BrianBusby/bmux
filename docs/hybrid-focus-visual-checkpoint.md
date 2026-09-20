# Hybrid Focus visual checkpoint

Updated 2026-09-20 after reference comparison correction.

- Source: `hybrid-focus-design` after the follow-up visual/data commit.
- Built identity: tagged Debug build 607, `hybrid-focus-reference`; the isolated build used the existing local Swift package/Ghostty cache because package fetches were unavailable. The app is running and CUA can capture its primary-display window.
- Slice 1: native workspace cards, assigned-color selection, 340px/290px rail policy, independent link activation, and underline view navigation are implemented in the normal app path. The shared joined perimeter still needs visual correction against the approved reference.
- Slice 2: shared stacked workspace header, current-evidence-first Focus composition, restrained newest-first history, disclosure-backed source identity, and coordinated light/dark shell tokens are implemented.
- Slice 3: native projection now forwards PR state, PR owner, ticket owner, project, and all known resource links; owner links are distinct from PR/ticket links and link activation does not select a workspace.
- Reference comparison correction: moved the header above navigation, changed navigation to Focus/Chat/Terminal/Learnings with intrinsic-width underlines, removed the standalone accent bar, stacked repo/title/resource chips, made the current turn a bordered card, and replaced the raw-ID-first latest-turn presentation with an objective/status/summary/progress card whose source IDs remain behind evidence disclosure.
- Capture diagnosis fixed: the tagged app restored to display 2 at x=3936. Moving its saved geometry to display 3 made CUA target it successfully. Live Terminal, Focus, and Learnings states are now captured after the correction; dark/light, narrow, and expanded-history captures remain follow-up checks.
- Visual evidence: the supplied archive's approved dark reference and build-605 before-state were inspected. CUA captured the corrected live light and dark Focus/Terminal states for build 607; shell `screencapture` still lacks Screen Recording authorization. Rich multi-card fixture coverage, narrow layout, expanded history and the shared joined perimeter remain visually unverified.
