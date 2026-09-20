# PR #119 workbench acceptance checklist

Reference: `pr-119-swift-design-package.zip`, `approved-workbench-reference.png`.

Rendered evidence below is from the isolated native route `bmux DEV hybrid-focus-reference`, build 607, logical window 1000×700, dark appearance, global font magnification 110%, live workspace data unless marked fixture. CUA capture succeeded after moving only this tag's saved window geometry to the primary display. An independent reviewer inspected the original reference and these live captures; its results are recorded here, not inferred from implementation summaries.

| Requirement | Status | Evidence | Exception or remaining defect |
| --- | --- | --- | --- |
| R1 outer charcoal shell | partial | CUA dark Learnings and Focus captures; independent review | Dark shell is coherent but still reads as the old bmux toolbar/body treatment rather than the compact approved workbench chrome. |
| R2 workspace rail density | fail | CUA dark Focus capture; independent review | Rail is still a narrow native list with short rows, not the approximately 340px rich-card rail. |
| R3 rich workspace cards/resources | fail | CUA dark Focus capture; independent review | Real repository/title/PR data exists, but the cards lack the approved organized resource rows, separators, density and multi-ticket wrapping. This is presentation failure, not only unavailable data. |
| R4 stacked workspace header/chips | visually verified | CUA dark Focus capture | Live PR chip is present; owner/project overflow fixture remains to be reviewed. |
| R5 intrinsic Focus/Chat/Terminal/Learnings nav | visually verified | CUA dark Focus and Learnings captures | No known mismatch at the live logical size. |
| R6 current-turn card | partial | CUA dark Focus capture; independent review | Bordered card and bounded prompt are present, but default Commands/Files/Reasoning capsules do not match the reference result/activity rows. Sparse live evidence explains absent results but not the capsule styling. |
| R7 quiet prior-turn history | partial | Live Focus reports no prior turns; independent review | Stable ordering/expansion cannot be visually accepted without a bounded rich fixture or populated disposable session. |
| R8 Learnings/footer honesty | partial | CUA dark Learnings capture; independent review | Honest unavailable state is present; reference-style learning strip and restrained footer are not present. |
| D1 header before navigation | pass | CUA dark Focus capture | — |
| D2 stacked repo/title/chips | pass | CUA dark Focus capture | — |
| D3 label-width underline/order | pass | CUA dark Focus capture | — |
| D4 joined selected outline/no seam | implemented—visually unverified | Build 609 source path; prior build 608 CUA capture exposed a polygon defect which was corrected before build 609 | Shared ancestor overlay now owns the perimeter and clips off-screen rows; build 609 CUA reattachment failed before a rendered after-capture. |
| D5 selected links move/header | partial | Source/build path; independent review of build 607 | Selected raw workspace description/URL is now omitted from the active card; a post-fix rendered capture is still required. |
| D6 dark Focus composition | partial | Build 607 CUA dark Focus; build 609 not attachable | Dark Focus is reachable, but rail/cards and live sparse history/result data prevent full composition acceptance. |
| live Terminal route | pass | CUA build 607 Terminal capture | Native terminal remains the active provider surface. |
| live Chat route | pending | Not yet captured in this checkpoint | Must verify same identity/draft behavior. |
| narrow/light themes | pending | Not yet captured in this checkpoint | Must capture after shell correction. |
| capture path | pass | CUA window/app identity | Shell `screencapture` remains unavailable because Screen Recording authorization is false. |
