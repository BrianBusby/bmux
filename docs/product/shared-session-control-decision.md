# Shared-session Chat control decision

Status: read-only implementation under observation; shared control remains blocked at the feasibility gate. This is not a claim that
all three assignment phases passed. Base: `585f0a693f18b45954227d87dea4d0099a23e2d3`.

## Ownership and identity

Terminal is the original Ghostty PTY and provider TUI. `TerminalPanel.id` equals
`TerminalSurface.id`; `workspaceId` identifies its current workspace. A process
PID is only a liveness observation: reuse, relaunch, wrappers and children make
it insufficient as conversation identity. The transcript registry associates
provider session/thread ID, workspace, surface, transcript and observed PID.
Chat reads only an unambiguous exact workspace/surface binding, rechecking it
after asynchronous history reads. It does not select by cwd or newest PID.

Codex provider thread ID survives individual turns and may survive process
restarts. Provider turn ID identifies one execution. PE session ID is a separate
durable evidence identity resolved by the existing provenance adapters. Neither
PE identity nor a matching rollout grants authority to control a live process.
Session continues to use the PE factual/semantic projections. Chat uses the
existing `AgentChatTranscriptService` and `BmuxAgentChat` parser/tailer, not PE.

There are several distinct transports:

| Path | Owner and meaning |
| --- | --- |
| Ordinary CLI | Ghostty PTY hosts the original provider TUI; transcript service observes it |
| `webviews/agent-session` managed panel | `AgentSessionProcessStore` launches its own app-server; `thread/start` creates its conversation |
| `agent-chat` sidecar | Separate runtime/WebSocket integration; not an ordinary CLI attachment |
| `BmuxAgentChat` wire events | Existing history/update/reset/preview contract, also used by mobile consumers |
| PE | Durable evidence and work projections; not an input transport |

## Local protocol probe

On 2026-09-16 local time, command lookup found `/opt/homebrew/bin/codex` version
0.152.1; interactive shell startup resolved `/Users/brianbusby/.local/bin/codex`
version 0.154.0. Both were inspected explicitly. The ordinary interactive probe
ran 0.154.0, PID 49104, PTY `ttys009`, in disposable
`/tmp/bmux-shared-session-probe`, read-only sandbox, approval policy `never`.
The original provider thread was `01a0ad3c-2109-7d41-a6b6-f6277fb2b073`.
Only identifiers and harmless marker prompts are recorded here; no full rollout
or auth/config content is copied into repository logs.

- Initial prompt: `Reply only BMUX_CONTINUITY_PROBE_916. Do not use tools.`
- Provider `task_started` / `task_complete` identified turn
  `01a0ad3c-2182-7c13-94c8-fb89dc0de3de`; original terminal displayed the marker.
- `codex app-server proxy` with 0.154.0 failed with missing
  `~/.codex/app-server-control/app-server-control.sock` while this TUI was alive.
  `app-server daemon version` also failed to connect. `lsof` showed unnamed Unix
  socket pairs, not a public named control listener for this process.
- Generated protocol bindings expose `thread/resume`, `turn/start`, and
  `turn/interrupt`. Their existence does not establish attachment to this TUI.
  Resume rejoins a running thread in the *connected app-server*; starting another
  app-server and loading the same persisted thread would not satisfy continuity.
- A second raw-terminal prompt requested only `sleep 30` and a marker. Escape
  produced the provider's interruption notice; a subsequent marker prompt was
  accepted by the same still-running TUI. This is terminal-input evidence only,
  not structured Chat acceptance or interruption proof.

The official [App Server documentation](https://learn.chatgpt.com/docs/app-server)
is the protocol reference. The installed executable's generated schema is the
version-specific reference. No daemon was bootstrapped, no user session was
resumed into a second owner, and no production terminal was interrupted.

**Gate result:** ordinary existing CLI shared control is not proven. The tested
ordinary launch exposes no attachable control socket. This is not a universal
claim that every Codex hosting mode lacks shared control. A TUI launched against
a known daemon (`--remote`) is a different hosting topology requiring its own
same-owner, acknowledgement, approval and interruption proof.

## Capability matrix

| Operation | Ordinary existing CLI in this change | Existing managed structured panel |
| --- | --- | --- |
| Read conversation | Exact-binding transcript observation, bounded history | Process output/activity events |
| Submit prompt | Disabled: no verified attached transport; use Terminal | Existing own-thread submit; write success is not yet provider acceptance |
| Steer active turn | Disabled | Not verified |
| Queue follow-up | Disabled | Startup buffering is not a provider follow-up queue |
| Interrupt turn | Disabled; use original Terminal | End session terminates its own process; not an interrupt |
| Approval/question | Disabled; use original Terminal | Existing automatic decision path is unchanged; not shared request resolution |
| Change model/effort/permissions | Disabled | Existing own-session behavior; not ordinary CLI control |

The UI contract enumerates each operation and its unavailable reason. The native
read-only bridge independently rejects provider mutations; hiding a composer
alone is not the boundary. Stable action IDs, uncertain delivery reconciliation,
expected-turn interruption, shared approval retirement, and durable follow-up
queue remain gated. There is no fake pending echo, automatic retry, inferred
approval option, or terminal keystroke adapter in Chat.

## Read-only implementation boundary

The terminal panel retains the WebKit consumer while the original surface stays
mounted. View changes only change visibility/input focus; Chat cannot launch,
stop, resume, or own the CLI. PE failure does not affect direct terminal input.
The existing React shell, theme, sanitized Markdown and native trusted-frame
bridge are reused. Messages are chronological; the Session prior-turn overview
keeps its existing order. Tool IDs survive late results; bounded snapshots
replace the window rather than appending replayed events. Transcript truncation
replaces old rows and changes the source revision to clear cached row output, and failed reads explicitly label retained content stale.

The current consumer shows the newest 500 messages with an explicit partial
history notice. Tool output expands in chunks and reads retained raw command
output on demand, scoped through session/message identity. Unknown activity is
labeled unknown; lack of fresh output never marks a turn complete. This consumer
uses authoritative transcript messages only; it does not scrape terminal prose
or promote mobile provisional previews to durable messages. Codex turn start, completion and interruption come only from explicit provider
events and retain the provider turn ID. A late completion for another turn
cannot finish the current turn. Sources lacking those events remain unknown.
Provisional preview streaming is not enabled in this consumer.

## Remaining decision and verification

Keep existing ordinary sessions read-only. Before enabling controls, decide
whether future sessions may be launched with the provider TUI connected to an
explicit shared app-server owner. That alternative must retain the real TUI and
prove that every view targets that same owner; it must never silently replace
already-running sessions. If the provider adds attachment to ordinary in-process
TUIs, prefer a version/capability-negotiated attachment and repeat the proof.

The completion report must distinguish automated checks, raw CLI smoke evidence,
and actual tagged-app UI dogfood. Shared Chat send/interrupt, delayed interrupts,
acknowledgement-loss recovery, shared approvals and queue delivery have not been
verified and must not be reported complete.

## Reproducible tagged macOS smoke evidence

On build 565, Codex 0.154.0 ran in the real terminal with read-only sandbox and
approval policy `never`. Workspace `875F959A-9F05-4717-805E-6684E587EBD3`, surface
`EF2B2760-059B-4227-AF2F-BBCE7D573864`, PID `19922`, and provider thread
`01a0ad5d-4463-7cb2-80f3-f61422c4eb1d` were corroborated through the existing
registry, process liveness, original terminal, and that process's rollout.
Session displayed PE thread `coding-agent-thread-9ecd360c54702dd752b30c70` and
PE turn `coding-agent-turn-283bb0256db9dde65c4ae4a2` for the first turn.

| UTC time | Provider event | Turn |
| --- | --- | --- |
| 2026-09-17 03:16:05.969 | task_started, requested only sleep 5 and a harmless marker | `01a0ad5d-44cd-7f72-bdc9-d734cd6b52e7` |
| 03:16:20.876 | task_complete; Chat showed the prompt, assistant prose, expandable observed result and final marker | same |
| 03:16:52.313 | task_started, requested only sleep 30; switched to Chat while working | `01a0ad5d-f9c6-7820-b2bd-9a2424d2e4d7` |
| 03:17:05.687 | turn_aborted after Escape in original Terminal | same |
| 03:17:11.823 | task_started for the next harmless marker prompt | `01a0ad5e-4606-7fe0-84dd-4bba895e0788` |
| 03:17:15.499 | task_complete; Chat showed the follow-up response | same |

Switching Terminal → Chat → Session → Chat preserved the process/thread and the
expanded tool disclosure. Interact in Terminal returned keyboard focus to the
original terminal. Each ordinary prompt appeared once; Chat submitted none.
This proves observation continuity and raw-terminal interruption only. The
provider reported a background sleep task after Escape; a turn interruption is
not a claim that every subprocess was killed.

The UI smoke caught a file-watcher freshness gap. Pull reads now reconcile file
growth before returning history. A test disables watcher delivery, appends late
output, repeats the read, replaces the transcript and deletes it; it verifies
new content, stable identity, replacement and unavailable history. The smoke
also caught multiple restored bindings; Chat now clears the previous conversation
and reports ambiguity instead of guessing the active session.

Codex's explicit `turn_aborted` event is preserved as an interrupted status.
Its regression test failed with zero projected events before the parser change.
The separate managed panel's destructive action is labeled **End session** in
its tooltip/accessibility name; it has not acquired safe turn interruption.

## Verification coverage and limits

- Shared parser package: 209 tests, including the interruption regression.
- Web contract, model, Markdown and DOM behavior: 64 tests; sanitization, no
  composer/mutations, scoped identity, replay/reset, stale cache, ambiguity,
  500-message cap and progressive 20,000-character tool output covered.
- Native bridge and refreshed history: four focused Swift Testing tests, with
  the test target compiled. Mutation rejection and injected Terminal navigation
  are exercised through the bridge.
- macOS light appearance, accessible controls, native focus, real CLI output,
  disclosure persistence and view switches exercised through the running app.
- New UI copy has English and Japanese catalog entries. Existing workspace PR,
  ticket, project and PR-owner rendering paths were not replaced.

Shared send, steering, delayed interrupt, acknowledgement-loss reconciliation,
approval retirement and queue delivery are intentionally unverified/disabled.
The consumer uses authoritative history only, with no provisional preview.
Working/completed/interrupted states require explicit Codex events; no state is
inferred from prose or elapsed silence. Individual failed tool results remain
separate from turn status. Sources without a known turn-failure event stay
unknown rather than manufacturing a failed turn.
The latest 500 messages are shown, with no older-history paging yet. Dark-mode
visual inspection, VoiceOver, provider-crash recovery, and a real PE outage were
not exercised. Those remain acceptance checks; neither all of Phase 2 nor Phase
3 is marked complete. No demo video was recorded.
