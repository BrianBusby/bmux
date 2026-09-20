# Hybrid Focus visual checkpoint

Updated 2026-09-19 after Slices 1–3.

- Source: `hybrid-focus-design` after the follow-up visual/data commit.
- Built identity: tagged Debug build 603, `hybrid-focus-visual-s1`; the isolated build used the existing local Swift package/Ghostty cache because package fetches were unavailable. The app is running and its tagged socket responds to `workspace list`.
- Slice 1: native workspace cards, assigned-color selection, joined 3px outline, 340px/290px rail policy, independent link activation, and underline view navigation are implemented in the normal app path.
- Slice 2: shared workspace header, current-evidence-first Focus composition, restrained newest-first history, disclosure-backed source identity, and coordinated light/dark shell tokens are implemented.
- Slice 3: native projection now forwards PR state, PR owner, ticket owner, project, and all known resource links; owner links are distinct from PR/ticket links and link activation does not select a workspace.
- Remaining verification: disposable populated Focus/Chat/Terminal navigation and rendered comparison require a capturable isolated window. The known CUA/screencapture errors remain unchanged.
- Visual evidence: Brian's build-599 screenshot establishes the pre-slice old sidebar/segmented navigation. The exact PNG named in the request was not present in this workspace; the self-contained Focus/design-book HTML references are available under `/Users/brianbusby/Downloads`. CUA and `screencapture` remain unavailable (`cgWindowNotFound` / no image from display), so the new slice is not yet visually verified.
