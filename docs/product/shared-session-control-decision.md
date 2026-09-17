# Shared-session Chat control decision

Status: ordinary CLI read-only implementation under observation; opt-in new shared-host controls are being implemented and verified. Ordinary attachment and safe structured interruption have not passed their gates. This is not a claim that
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
alone is not the boundary. The ordinary-CLI boundary remains read-only. The new opt-in connection contract below separately owns action IDs and delivery reconciliation. Expected-turn interruption and shared approval retirement remain gated. There is no fake pending echo, automatic retry, inferred
approval option, or terminal keystroke adapter in Chat.

## Read-only implementation boundary

The terminal panel retains the WebKit consumer while the original surface stays
mounted. For ordinary existing CLI sessions, view changes only change visibility/input focus; Chat cannot stop, resume, or own that CLI. PE failure does not affect direct terminal input.
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

At the read-only handoff, shared send, steering, delayed interrupt, acknowledgement-loss reconciliation, approval retirement and queue delivery were unverified/disabled. The opt-in follow-up below does not change ordinary CLI capabilities.
The consumer uses authoritative history only, with no provisional preview.
Working/completed/interrupted states require explicit Codex events; no state is
inferred from prose or elapsed silence. Individual failed tool results remain
separate from turn status. Sources without a known turn-failure event stay
unknown rather than manufacturing a failed turn.
The latest 500 messages are shown, with no older-history paging yet. Dark-mode
visual inspection, VoiceOver, provider-crash recovery, and a real PE outage were
not exercised. Those remain acceptance checks; neither all of Phase 2 nor Phase
3 is marked complete. No demo video was recorded.

## Follow-up: shared-host connection probe (2026-09-17)

The next experiment used a **new** disposable Codex 0.154.0 session, not an
attachment to an ordinary existing TUI. A single app-server (PID `80313`) listened
on a mode-0600 Unix socket inside a mode-0700 temporary directory. The real Codex
TUI (PID `80459`) connected with `--remote unix://<socket>` and stayed attached.
A second WebSocket client joined that same live server/thread. Unix transport
requires the HTTP Upgrade/WebSocket protocol; raw JSONL or a byte proxy alone
is not a JSON-RPC client for that listener.

The TUI created provider thread `01a0ad82-cf12-7bd0-844d-b6db4f423461`.
`thread/loaded/list` returned that single loaded thread; `thread/resume` on the
same server rejoined it. No second provider owner or conversation was started.

| Action | Observed result |
| --- | --- |
| Second client sends `turn/start` with client message ID `73a600c6-94f5-465a-8dd3-5bdf1d1a36be` | Acknowledged turn `01a0ad84-ed8b-7621-8206-da92067b9656`; completed with the requested marker in the original TUI; one corresponding provider turn |
| Start harmless sleep turn `01a0ad85-acd5-7032-a4ae-3476914a45fc`, wait for command activity, then interrupt it | `turn/interrupt` acknowledged; turn completed with status `interrupted`; server and TUI survived |
| Start next turn `01a0ad85-be38-72e1-b57d-c1364e018022`, then repeat interrupt carrying **previous** turn ID | **Gate failure:** server acknowledged `{}` and interrupted the newer turn |
| Send recovery prompt | Turn `01a0ad86-9b03-7c81-836f-94b501a851d1` completed; both original PIDs were still alive |

The stale interrupt request was structurally valid and carried the documented
`threadId` and `turnId` fields. Its old `turnId` did not protect the next turn in
this installed build. A client-side read-then-check cannot make that atomic when
the real TUI can concurrently start another turn. Safe interrupt capability
therefore remains disabled even for this experimentally shared hosting topology.

The probe establishes that a new shared-host session can accept a second
client's prompt and keep the real TUI attached. It does **not** establish complete
CLI command parity, safe delayed interruption, approval retirement, reconnect
idempotency, or queue semantics. The official transport is still described as
experimental. Existing sessions remain read-only. Opt-in shared-host launches
with only individually verified controls required an explicit architecture choice; the user subsequently authorized that new-session mode. No controls were enabled by the probe alone. The existing dogfood app was not rebuilt or replaced.

## Opt-in connected sessions: implementation in verification

The user's “keep going” authorizes a new-session mode. **New connected Codex
session** creates a new raw terminal and a dedicated authenticated loopback
app-server, then starts the original Codex TUI with `--remote`. It does not replace or adopt the currently selected ordinary CLI.
The TUI creates its new thread on that host; Chat binds only when the dedicated host reports exactly one loaded thread. Both clients use that same live owner.
The provider process, TUI process, provider thread, and PE identity remain distinct.

The implementation pins controls to empirically tested Codex 0.154.0. It uses a
random capability token in a private file, verifies that an unauthenticated
WebSocket handshake receives HTTP 401, and only then initializes its native
`URLSessionWebSocketTask`. The token is never sent through the webview bridge,
placed in argv, or passed into the provider host's tool environment. Native
WebSocket initialization was exercised successfully against the real provider.

| New connected session operation | Scope |
| --- | --- |
| Read conversation | Same exact-bound durable transcript adapter as ordinary Chat |
| Send follow-up | Provider-owned `thread/queue/add`, not idle `turn/start`; the real TUI drains the queue |
| Steer current turn | `turn/steer` with required expected turn ID; mismatched IDs are rejected by the tested provider |
| Interrupt | Terminal only; the stale-turn failure above remains open |
| Approval, question, queue editing/cancellation, settings | Terminal only; no synthetic answers or fabricated controls |
| Reconnect | Rejoin only the known, still-running dedicated host and loaded thread; reconcile IDs, never replay a mutation |
| App restore | Connected control ownership is not restored yet; ordinary transcript observation and Terminal remain the fallback |

A second disposable probe used host PID `13196` and thread
`01a0ad95-c517-7a00-9e8f-667a86807dea`. Ambient bmux routing variables were removed.
The TUI displayed `CONNECTED_READY_917`. Two queue-add requests carrying the
same client ID `d748cda4-e566-41c4-946f-e16475b07e14` produced **two** completed
turns (`01a0ad96-7f00-70a1-9eeb-0e3739e555f9` and
`01a0ad96-8806-7b70-bfc2-6795526388f2`). Client IDs are correlation evidence,
not an idempotency guarantee in this provider build.

During active turn `01a0ad99-4ff5-7c42-94d3-d9a042bbeee5`, steering with the old
turn ID was rejected with `-32600`; an explicit queue start was rejected because
a turn was active. Queue item `01a0ad99-4ff8-7112-8ba7-2672f8c35a52` survived a
client disconnect/rejoin and later became exactly one completed follow-up turn,
`01a0ad99-9e51-79b1-903e-6f2932655965`. The authoritative user message retained
client ID `60a66690-e988-41ea-adcd-e4d7af15054d`.

The native action owner reserves each request ID before sending. It keeps
pending, accepted, failed, and uncertain states independently of Chat mounting;
missing acknowledgments preserve drafts and block blind retries. Read-only
reconciliation can establish acceptance from a queued item or provider-authored
user-message client ID. A missing item is never treated as proof of non-delivery.
No optimistic conversation message is appended. Request tombstones outlive
retired prompt bodies, and both are bounded.

Five new transport/state tests cover one accepted action, duplicate requests,
wrong-thread rejection, stale-turn rejection, slash-command handling, uncertain
delivery, and reconciliation after a replacement connection without a resend.
Native tagged UI verification is in progress. An initial live launch exposed that Codex cannot resume an empty, unpersisted thread; startup now lets the TUI create its own thread, with no dummy prompt. A direct authenticated TUI-first test accepted one queued prompt and produced one completed turn. Subsequent macOS UI automation returned `cgWindowNotFound`, so the corrected application launch has not yet passed the UI gate. Approvals, provider restart, dark mode,
VoiceOver, and restored control ownership remain unaccepted gates.

For a connected host, fresh authenticated provider state and transcript availability
are separate. An empty TUI can accept a first queued prompt even before Codex has
created its durable rollout. Failed history reads stay unavailable/stale; they do
not masquerade as live history. A lost bridge response clears live control state.
The owning terminal's actual Ghostty process-exit signal additionally gates
controls. Multiple loaded threads or a changed selected thread fail closed rather
than routing to an arbitrary conversation. This conservative restriction can
also temporarily disable controls while a provider-created auxiliary thread is
loaded. The app does not adopt a thread based on repository directory or PID.


### Native control smoke evidence (Codex 0.154.0)

The product `Control/*.swift` implementation was compiled into a disposable
command-line harness, using an authenticated host and a real `codex --remote`
TUI in a temporary workspace. Host PID `79026` and TUI PID `79050` remained
alive throughout. The TUI created thread
`01a0adc0-3373-77a1-8383-3227e2d5b886` before either Chat-side action.

1. `thread/queue/add` acknowledged client request
   `3C976673-47F0-4F03-9A7D-04920059B662`; the harmless prompt requested a short
   sleep and a marker.
2. During turn `01a0adc1-15da-7e20-82fd-df91236c211f`, `turn/steer` acknowledged
   client request `9D7EE3B4-B376-4CDD-B7AC-E446B8EEFC9C` and that same turn ID.
3. The authoritative completed turn contained exactly those two user-message
   client IDs. The original TUI displayed the requested `STEER_ACCEPTED_917`
   marker. No second thread or provider owner was created.

Reproduce with the pinned CLI: create a private temporary directory and token
file, launch `codex app-server --listen ws://127.0.0.1:0 --ws-auth
capability-token --ws-token-file <private-file>`, and start the TUI using
`codex --remote <reported-loopback-url> --remote-auth-token-env <token-env-name>`.
Initialize a second authenticated WebSocket client with `experimentalApi: true`,
read the sole loaded thread, then issue the queue and expected-turn steering
requests above with fresh client IDs. Corroborate IDs in `thread/read` and the
marker in the original TUI. Never reuse client IDs as a provider deduplication
mechanism. Token values, credentials, and full transcripts are intentionally not
included here. This protocol smoke test does not substitute for the application
UI gate.

Verification: 214 shared-package tests, eight native bridge/ownership tests,
and 67 web state/DOM tests passed; TypeScript type checking and lint passed.
Native tests exercise wrong workspace/thread targeting, missing history with a
healthy control connection, actual terminal exit, ambiguous loaded threads, and
draft preservation. Drafts and action receipts survive webview reloads in native
memory; they are not persisted across application restart. Provider queue
ordering is provider-owned. Queue editing/cancellation and approval interaction
remain in Terminal and have not passed cross-view acceptance.


### Build 572 dogfood: Chat-to-Terminal delivery

On September 17 the user reported an empty Chat with “Multiple session bindings.”
Inspection of the running build 572 confirmed a connected host (PID 33141), its
original TUI (PID 33143), and exactly one loaded thread,
`01a0af03-7756-70a1-b7f4-80189f1dcb22`. Without restarting the app or provider,
Chat subsequently recovered the user's existing greeting and enabled its composer.
The precise cause and duration of the earlier binding failure remain unresolved;
this is not evidence that all startup/recovery UI gates pass.

A single UI submission requested `CHAT_CONNECTION_VERIFIED` without tools.
Chat displayed “Accepted by Codex.” Provider turn
`01a0af06-ae72-7e83-9799-c920203c1d96` completed with exactly one matching user
item, client ID `5AE5DA78-63A0-49FF-AF8B-4D7DD07EEAF9`. The original raw
Terminal and Chat both displayed the marker. No second conversation or process
restart occurred. This closes the basic UI delivery gate for build 572;
focus/typing behavior, startup ambiguity, broader recovery, and later draft
changes still need verification. The running app was not rebuilt or replaced.
