# Coding Session Views

One coding-agent session should support three complementary views. These views
share session identity but answer different user questions.

## Native

Question: what does the provider itself expose?

Native is the fidelity and escape-hatch surface. It should preserve provider
specific behavior, debugging access, and features bmux has not normalized yet.

## Terminal

Question: what is happening live, and how do I interact with the coding agent?

Terminal is the React live interaction surface built from `agent-chat`. It owns
streaming conversation, tool activity, provider metadata, model controls,
reasoning effort display, collaboration mode controls, approvals, sandbox state,
interrupts, skills/commands, working directory display, and live session
lifecycle interaction.

Terminal may consume ephemeral provider/runtime events directly. It is not the
semantic reasoning layer.

## Session

Question: what does the work mean and how is this session progressing?

Session is a React smart summary surface backed by PE factual and semantic
models. It should not duplicate the transcript. It should eventually expose:

- session goal,
- current phase,
- current turn,
- current activity,
- current plan,
- completed turns,
- work completed,
- files affected,
- validations and results,
- blockers,
- approach changes,
- milestones,
- architecture affected,
- progress.

Completed turns should be compact and individually inspectable, with factual,
semantic, and provenance detail available on demand.

## Boundary

bmux presents the views and owns interaction. PE owns accepted evidence,
deterministic factual projection, semantic records, semantic messages, and the
future `SessionWorkModel`. React should render PE-owned meaning, not recreate
that meaning from raw provider events.

