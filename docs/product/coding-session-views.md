# Coding Session Views

A coding-agent session has three complementary views. Switching views must not
create a conversation or transfer ownership of the provider process.

## Terminal

Terminal is the actual provider CLI in its original terminal. It retains provider
shortcuts, prompts, approvals, interrupts and debugging behavior. It remains
available when Chat, Session, or PE is unavailable.

## Chat

Chat is a styled chronological conversation with expandable tool activity.
Controls are available only when verified for the actual connection, provider,
session and turn. Ordinary CLI transcript observation is read-only: use
**Interact in Terminal** for input and approval handling. Transcript availability
is not control authority. Chat does not infer semantic progress or findings.

## Session

Session is the PE-backed work overview, progress, findings, related work and
inspectable evidence. Its previous-turn overview remains newest-first, separate
from Chat's oldest-first conversation. bmux renders PE meaning rather than
recreating semantic conclusions from raw provider events.

## Compatibility and ownership

Earlier documents called the provider terminal Native and the structured view
Terminal. Those labels must not be used to swap implementations. Existing
`react` and `solid` renderer values, panel kinds, preference keys and persisted
view identifiers retain their meanings. Displaying Chat in a terminal pane does
not turn that pane into the existing managed agent-session panel.

See [the control decision and capability matrix](shared-session-control-decision.md)
for tested limits, transport ownership and verification status. Workspace PR,
individual ticket, project and PR-owner links retain their current destinations
and selected-workspace behavior. No Knowledge Compiler work is included.
