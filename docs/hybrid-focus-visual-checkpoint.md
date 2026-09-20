# Hybrid Focus visual checkpoint

Updated 2026-09-19 after Slice 1.

- Source: `hybrid-focus-design` at the next commit after `21b0656e2`.
- Built identity: tagged Debug build 600, `hybrid-focus-visual-s1`; the isolated build used the existing local Swift package/Ghostty cache because package fetches were unavailable.
- Slice 1: native workspace cards, assigned-color selection, joined 3px outline, 340px/290px rail policy, independent link activation, and underline view navigation are implemented in the normal app path.
- Slice 2 next: style the native Focus projection, workspace header, current-turn/history cards, and shared Chat/Terminal/Learnings presentation to the supplied workbench hierarchy.
- Slice 3 next: finish source-to-header metadata coverage, overflow/owner distinctions, disposable-session checks, and focused regressions.
- Visual evidence: Brian's build-599 screenshot establishes the pre-slice old sidebar/segmented navigation. The exact PNG named in the request was not present in this workspace; the self-contained Focus/design-book HTML references are available under `/Users/brianbusby/Downloads`. CUA and `screencapture` remain unavailable (`cgWindowNotFound` / no image from display), so the new slice is not yet visually verified.
