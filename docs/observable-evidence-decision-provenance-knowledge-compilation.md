# Observable Evidence, Decision Provenance, and Knowledge Compilation

Status: Architecture proposal

Audience: Provenance Engine

Related documents:

- `docs/reference-architecture.md`
- `docs/architecture.md`
- `docs/bmux-integration-roadmap.md`

## Introduction

As Provenance Engine evolves from a session recorder into a reusable engineering knowledge platform, it must establish a clear boundary between observable evidence and model reasoning.

Modern coding agents, including Codex, Claude, Gemini, and Cursor, expose a rich stream of observable actions, but they do not expose their complete internal reasoning process.

This is not a limitation of Provenance Engine.

It is an architectural constraint of the current AI ecosystem.

Provenance Engine should embrace this constraint rather than attempting to work around it.

Instead of attempting to record hidden reasoning, the engine should become the authoritative system for collecting observable engineering evidence and deriving reusable knowledge from that evidence.

This distinction strengthens the platform:

- The engine records only verifiable facts.
- Every conclusion remains traceable back to evidence.
- Future AI models can reinterpret the same evidence without losing fidelity.
- Retrieval becomes explainable instead of opaque.
- bmux and future clients remain simple capture systems rather than knowledge systems.

## Core Principle

Provenance Engine owns the meaning of captured information.

Clients own acquiring it.

Or stated another way:

- bmux answers: What happened?
- Provenance Engine answers: What does it mean?

This boundary should remain true regardless of how many clients eventually produce provenance.

## Observable Evidence

Provenance Engine should only treat information as evidence when it is directly observable.

Examples include:

- Session lifecycle.
- Prompts.
- Visible planning messages.
- Visible progress updates.
- Explicit engineering decisions.
- Tool invocations.
- Terminal commands.
- Command output.
- File modifications.
- Git activity.
- Artifacts.
- Pull requests.
- Review comments.
- Issue tracker activity.
- Validation results.
- CI run results.
- Deployment events.

These are facts. They are durable. They can always be replayed.

## Hidden Model Reasoning

Provenance Engine should explicitly consider hidden chain-of-thought unavailable.

It should never assume that internal reasoning, hidden planning, latent deliberation, or private intermediate conclusions are accessible or recoverable.

Accordingly, the engine should never model hidden reasoning as provenance.

This architectural boundary should be documented explicitly anywhere Provenance Engine describes evidence-backed knowledge, Knowledge Compiler behavior, or retrieval guarantees.

## Explicit Decisions

Sometimes an engineer or coding agent states a decision directly.

For example:

- Decision: Use the existing Current Context API.
- Reason: Consumer migration succeeds without expanding the public contract.
- Alternative considered: Introduce a new specialized API.

These should become first-class provenance records.

A future `DecisionRecord` may include:

- Author.
- Source.
- Timestamp.
- Decision.
- Rationale.
- Alternatives.
- Evidence references.
- Confidence.

These are explicit engineering knowledge because the decision was stated directly by an observable actor.

## Derived Decisions

Many engineering decisions are never stated directly.

Instead they emerge from evidence.

Examples include:

- Multiple abandoned implementations.
- Repeated validation failures.
- Reverted commits.
- Pull request discussion.
- Implementation changes.
- Architecture documents.

The future Knowledge Compiler should be able to infer:

- Probable decision.
- Supporting evidence.
- Confidence.
- Competing interpretations.

Derived decisions are not evidence.

They are knowledge products.

They must always reference supporting evidence.

## Evidence Attribution

Every derived knowledge object should retain attribution.

For example:

- Decision.
- Supported by Session 184.
- Supported by Commit abc123.
- Supported by PR #91.
- Supported by Validation Run 38.
- Supported by Architecture Review Slice D.

This allows future agents to inspect the original evidence rather than trusting summaries blindly.

## Current State vs. Knowledge

Current State and Knowledge solve different problems.

Current State answers:

- What is active?
- What changed?
- What failed?
- What branch is running?
- What session owns this work?

Knowledge answers:

- Why was this chosen?
- What alternatives were rejected?
- What constraints exist?
- What lessons were learned?

These should remain separate systems.

Current State should remain deterministic.

Knowledge may involve AI synthesis.

## Retrieval

Future retrieval should prioritize:

1. Current state.
2. Explicit decisions.
3. Derived knowledge.
4. Supporting evidence.

Raw transcripts should be considered a last resort.

Agents should receive concise knowledge, supporting evidence, confidence, and links back to original provenance rather than entire conversations.

## Responsibilities

### bmux

bmux is responsible for:

- Observing activity.
- Capturing evidence.
- Forwarding evidence.
- Reliable delivery.
- Rendering projections.

bmux is not responsible for:

- Interpreting engineering meaning.
- Inferring decisions.
- Generating knowledge.

### Provenance Engine

Provenance Engine is responsible for:

- Evidence validation.
- Evidence storage.
- Evidence relationships.
- Deterministic projections.
- Current state.
- Knowledge compilation.
- Decision inference.
- Retrieval.
- Confidence attribution.

## Future Clients

This architecture intentionally allows new clients to participate without changing Provenance Engine.

Examples include:

- Claude Code.
- Gemini CLI.
- Cursor.
- VS Code.
- JetBrains.
- GitHub.
- CI systems.
- Deployment pipelines.

Each client only needs to emit observable evidence.

Provenance Engine becomes the single place where engineering meaning is constructed.

## Long-Term Vision

Provenance Engine should become an evidence-backed engineering memory system.

It should not become:

- A transcript database.
- A chain-of-thought recorder.
- An opaque AI summary service.

Instead:

- Evidence is permanent.
- Current state is deterministic.
- Knowledge is reproducible.
- Every conclusion remains explainable.

Future models may improve.

The evidence should never need to change.

Only the interpretation of it should change.
