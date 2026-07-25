# Provenance Engine Reference Architecture

## Introduction

As Provenance Engine has evolved, the project has grown beyond a simple session recorder or developer library. It is becoming a platform whose purpose is to preserve engineering evidence, transform that evidence into reusable knowledge, and deliver the right context to engineers and AI agents at the moment they need it.

That evolution has introduced several major architectural concepts, including evidence adapters, shared evidence stores, the Knowledge Compiler, retrieval, and multiple consumers such as bmux, that are larger than any individual implementation task or roadmap milestone.

This document serves as the architectural reference for the entire platform.

It is intended to answer a single question:

> How does the Provenance Engine system fit together as a whole?

Unlike a roadmap, this document does not describe implementation order or project priorities.

Unlike an ADR, it does not justify one isolated architectural decision.

Unlike implementation documentation, it does not prescribe the internal design of individual components.

Instead, it defines the major subsystems of the platform, the responsibilities of each layer, the boundaries between them, and the flow of information from raw engineering evidence to evidence-backed knowledge retrieval.

This document should remain relatively stable as the project evolves. Individual implementations, APIs, storage technologies, compiler strategies, and deployment models will change over time, but they should continue to fit within the architectural principles defined here.

The goal is to provide engineers, contributors, and AI agents with a shared mental model of the platform so that future design decisions strengthen a coherent architecture rather than gradually creating disconnected features.

Provenance Engine is an engineering knowledge platform built to preserve the evidence of how software systems evolve and make that evidence useful to engineers and AI agents.

Its purpose is not merely to record activity.

It must support the full lifecycle from raw engineering evidence to trustworthy, context-efficient knowledge retrieval:

```text
Evidence Sources
        ->
Evidence Adapters
        ->
Evidence Store
        ->
Deterministic Current State
        ->
Knowledge Compiler
        ->
Knowledge Store
        ->
Retrieval Engine
        ->
Consumers
```

This document describes how those parts fit together.

It is not:

- a product roadmap
- an implementation plan
- an API specification
- an ADR for one isolated design choice
- a commitment to build every component immediately

It is the reference architecture for the system as a whole.

Roadmaps should describe when parts of this architecture are built.

ADRs should describe why specific architectural decisions were made.

Implementation documents should describe how particular components are constructed.

This document should remain the stable map that explains what the platform is becoming, what each major subsystem owns, and how information moves through the system.

## 1. Architectural Goal

The central goal of Provenance Engine is:

> Preserve granular engineering evidence continuously, compile it into useful knowledge, and retrieve only the minimum trustworthy context required for the current task.

This goal is based on two related principles.

### Project knowledge should grow continuously

As engineering work progresses, the system should accumulate:

- session history
- commands
- decisions
- artifacts
- repository changes
- pull requests
- reviews
- documents
- issue history
- release information
- ownership and subsystem evolution

The organization should become more knowledgeable over time.

### Agent context should not grow continuously

An engineer or agent should not need to load the entire history of a repository or organization into every working session.

Instead, Provenance Engine should retrieve a bounded evidence and knowledge package relevant to the task being performed.

Increasing project knowledge should improve agent effectiveness rather than increasing every agent's context size.

## 2. System Overview

The platform consists of seven major layers.

```text
+---------------------------------------------------------------+
|                        Evidence Sources                       |
| Git | GitHub | AI sessions | terminals | documents | issues   |
+------------------------------+--------------------------------+
                               |
                               v
+---------------------------------------------------------------+
|                       Evidence Adapters                       |
| Capture | normalize | identify | validate | checkpoint        |
+------------------------------+--------------------------------+
                               |
                               v
+---------------------------------------------------------------+
|                         Evidence Store                        |
| Immutable events | source records | relationships | lineage   |
+------------------------------+--------------------------------+
                               |
                               v
+---------------------------------------------------------------+
|                 Deterministic Current State                   |
| Present context | relationships | derived bounded views          |
+------------------------------+--------------------------------+
                               |
                               v
+---------------------------------------------------------------+
|                      Knowledge Compiler                       |
| Extract | correlate | summarize | classify | infer            |
+------------------------------+--------------------------------+
                               |
                               v
+---------------------------------------------------------------+
|                         Knowledge Store                       |
| Decisions | constraints | summaries | histories | ownership   |
+------------------------------+--------------------------------+
                               |
                               v
+---------------------------------------------------------------+
|                        Retrieval Engine                       |
| Search | rank | assemble | cite | budget | authorize          |
+------------------------------+--------------------------------+
                               |
                               v
+---------------------------------------------------------------+
|                           Consumers                           |
| bmux | agents | CLI | IDEs | organization services            |
+---------------------------------------------------------------+
```

Each layer should have a clear responsibility.

No layer should quietly absorb the responsibilities of the others.

## 3. Evidence and Knowledge

The most important conceptual boundary in the architecture is the distinction between evidence and knowledge.

### 3.1 Evidence

Evidence is a durable record of something that occurred or existed.

Examples include:

- a session started
- a task was created
- an agent was spawned
- a command was executed
- a file was modified
- a commit was created
- a pull request was opened
- a reviewer left a comment
- a review thread was resolved
- a decision was explicitly recorded
- an artifact was generated
- a document contained a particular statement

Evidence should be preserved with enough source information to establish:

- where it came from
- when it occurred
- who or what produced it
- what project or organization it belongs to
- how it relates to other evidence
- whether it was observed directly or derived

Evidence should be treated as factual input, even when the content of that evidence contains an opinion, hypothesis, or mistaken statement.

For example, a review comment is evidence that the reviewer made that comment. It is not automatically proof that the comment was correct.

### 3.2 Knowledge

Knowledge is an interpretation compiled from one or more pieces of evidence.

Examples include:

- an architectural decision
- an engineering constraint
- a rejected alternative
- a subsystem summary
- a migration history
- an ownership summary
- an explanation of why a file exists
- a description of how a feature evolved
- a list of known risks
- a summary of unresolved work

Knowledge is useful because it reduces the amount of raw evidence a consumer must inspect.

Knowledge is not the source of truth by itself.

Every important knowledge artifact should retain links to the evidence supporting it.

### 3.3 Regeneration rule

Evidence should be durable.

Knowledge should be regenerable.

A newer compiler, better model, corrected algorithm, or changed organizational policy should be able to rebuild knowledge artifacts from preserved evidence.

The architecture must therefore avoid a design in which AI-generated summaries replace the underlying evidence.

## 4. Evidence Sources

Evidence sources are systems or activities that produce engineering information.

The platform should support multiple evidence origins without forcing them into identical semantics.

### 4.1 AI coding sessions

Examples:

- Codex
- Claude Code
- future coding agents
- child agent sessions
- orchestrated review agents

Potential evidence includes:

- session start and end
- user instructions
- task creation
- agent creation
- agent relationships
- tool activity
- command execution
- file changes
- explicit decisions
- generated artifacts
- session summaries
- errors and blocked work

AI-session evidence is especially valuable for understanding intent and reasoning that may never appear in Git history.

### 4.2 Terminal and local development activity

Potential evidence includes:

- commands
- exit status
- current working directory
- repository and worktree identity
- branch state
- test execution
- build execution
- generated files
- environment facts
- local experiments

Terminal evidence should be captured selectively and securely.

The platform should not assume that every byte of terminal output must be stored forever.

Capture policies should distinguish between:

- useful engineering evidence
- redundant output
- secrets
- personally sensitive data
- high-volume transient noise

### 4.3 Git repositories

Potential evidence includes:

- commits
- commit ancestry
- branches
- tags
- changed files
- diffs
- rename history
- authorship
- timestamps
- merge relationships
- release boundaries

Git provides implementation history and chronology.

It often shows what changed but not why it changed.

### 4.4 GitHub and code-hosting systems

Potential evidence includes:

- pull requests
- pull-request descriptions
- issue links
- submitted reviews
- inline review comments
- review threads
- thread resolution
- approvals
- requested changes
- merge state
- commit-to-PR relationships
- labels
- milestones
- release notes

Review conversations often contain architectural constraints, rejected approaches, and hidden design decisions that are not preserved in commit messages.

### 4.5 Issue and project-management systems

Examples:

- GitHub Issues
- Linear
- Jira
- internal project systems

Potential evidence includes:

- problem statements
- priorities
- acceptance criteria
- ownership
- status changes
- linked implementation work
- customer requests
- deferred work
- project milestones

### 4.6 Documents

Examples:

- ADRs
- design documents
- handoff documents
- technical plans
- operating procedures
- incident reports
- migration plans
- product specifications

Documents may contain both direct evidence and authored interpretation.

The adapter should preserve source identity, version, authorship, and timestamps where possible.

### 4.7 Communication systems

Examples:

- Slack
- email
- review discussions
- incident channels

These sources can contain important decisions and context, but they introduce significant concerns involving:

- authorization
- privacy
- retention
- discoverability
- duplication
- informal or contradictory statements

Communication ingestion should therefore be explicit, scoped, and policy-controlled.

### 4.8 Runtime and operational systems

Possible future sources include:

- CI systems
- deployment systems
- observability platforms
- incident-management tools
- feature-flag systems
- release systems

These can connect engineering intent to actual production outcomes.

## 5. Evidence Adapters

Evidence adapters connect external systems and local activities to the Provenance Engine evidence model.

An adapter is responsible for translating source-specific information into normalized evidence without erasing source-specific detail.

### 5.1 Adapter responsibilities

Each adapter should handle some or all of the following:

- authentication
- source discovery
- incremental synchronization
- checkpointing
- deduplication
- normalization
- source identity
- relationship extraction
- timestamp preservation
- origin and scope assignment
- deletion or tombstone handling
- validation
- rate-limit handling
- retry behavior
- sensitive-data filtering

### 5.2 Preserve source fidelity

Normalization must not flatten away important source semantics.

For example:

- a Git commit
- a GitHub review comment
- a Codex decision event
- a Slack message

should not all become an indistinguishable generic text record.

They may share common evidence fields, but their source-specific structure should remain available.

### 5.3 Adapter output

Adapters should produce:

1. normalized evidence records
2. relationships between evidence records
3. source checkpoints
4. adapter diagnostics
5. source-specific raw payload references where appropriate

### 5.4 Idempotency

Re-running an adapter over the same source range should not create duplicate evidence.

Every evidence source should have a stable external identity or a defensible deduplication strategy.

### 5.5 Local and shared adapters

Some adapters operate locally:

- terminal capture
- AI-session capture
- local Git state
- unpublished artifacts

Other adapters may operate centrally:

- organization GitHub ingestion
- shared issue ingestion
- company document ingestion
- organization Slack ingestion

The architecture must support both without requiring every engineer to independently ingest the same organizational evidence.

## 6. Evidence Store

The Evidence Store is the durable system of record for granular provenance data.

It should preserve enough information to reconstruct relationships, verify knowledge artifacts, and support future forms of analysis not anticipated when the evidence was collected.

### 6.1 Core properties

The Evidence Store should be:

- append-oriented
- durable
- queryable
- source-aware
- scope-aware
- relationship-aware
- auditable
- migration-safe
- capable of local and shared deployment

### 6.2 Immutability

Evidence should normally be immutable after ingestion.

Corrections should be represented through:

- superseding evidence
- tombstones
- source deletion records
- corrected metadata
- explicit invalidation

rather than silent destructive rewriting.

Strict physical immutability is not required in every storage implementation, but the logical evidence history must remain auditable.

### 6.3 Evidence identity

Each record should have a stable provenance identity.

Identity should account for:

- evidence type
- evidence origin
- source-system identity
- source record ID
- project or repository
- organizational scope
- version or revision where relevant

### 6.4 Evidence scope

Evidence should carry an ownership and visibility scope.

Possible scopes include:

- personal
- session
- workspace
- repository
- project
- team
- organization
- public

Scope is not merely descriptive metadata.

It becomes part of:

- authorization
- retrieval filtering
- sharing
- retention
- compilation boundaries

### 6.5 Relationships

The store should represent relationships explicitly.

Examples:

```text
session
  - created task
  - spawned agent
  - executed command
  - generated artifact

pull request
  - contains commits
  - changes files
  - received review
  - contains review thread
  - resolves issue

decision
  - supported by review comment
  - implemented by commit
  - discussed in session
```

The value of the platform depends heavily on its ability to connect evidence across systems.

### 6.6 Raw payloads

The system should distinguish between:

- normalized evidence fields required for core operation
- source-specific structured metadata
- optional raw source payloads

Raw payload storage should be deliberate.

Keeping every raw payload may improve future flexibility but can increase:

- storage cost
- privacy exposure
- schema complexity
- retention obligations

The architecture should support raw payload references or configurable retention rather than requiring one universal policy.

### 6.7 Personal and organizational stores

The platform may use separate physical stores for:

- local personal evidence
- shared repository evidence
- organization-wide evidence

These stores should still participate in a coherent logical architecture.

The system should not require all private local evidence to be uploaded to a central organization service before it can be useful.


### 6.7 Deterministic Current State

Current State is the canonical deterministic interpretation of engineering evidence.

It is derived only from accepted evidence and deterministic engine rules. It answers present-tense provenance questions such as which sessions are active, which work is current, which files have recent evidence, which checkpoints and validation runs are relevant, and where active contributions may overlap.

Current State is not raw evidence. It is also not the Knowledge Compiler. It must not contain model-generated conclusions, semantic summaries, or AI-authored durable knowledge artifacts. Those belong to later compiler and retrieval layers.

Current State is rebuildable from the Evidence Store. If projection state is deleted or drifts from the ledger, the engine should be able to replay accepted evidence and reproduce the same bounded public query results. This makes the Evidence Store the durable system of record and Current State disposable derived state.

Current State powers V1 read APIs such as worktrees, session trees, file explanations, and current context. Producers do not compute it, and consumers should not reconstruct it from raw events or storage tables. The engine owns deterministic ordering, relationship derivation, evidence attribution, and bounded query behavior.

Ownership boundaries:

- Producers own observing activity, assigning stable source/domain identities, emitting observable or declared facts, and retrying failed or unacknowledged delivery where needed.
- Provenance Engine owns evidence validation, durable evidence storage, deterministic ordering and relationships, Current State derivation, projection rebuild, bounded provenance queries, and evidence attribution.
- Consumers own presentation, UI, CLI formatting, local fallback policy, live Git probing when explicitly outside persisted provenance, and product-specific interaction behavior.

## 7. Knowledge Compiler

The Knowledge Compiler transforms evidence into reusable engineering knowledge.

It is the interpretation layer of the system.

### 7.1 Compiler purpose

The compiler should answer questions that raw records alone do not answer efficiently.

Examples:

- Why was this design chosen?
- What alternatives were rejected?
- What constraints govern this subsystem?
- How did this file evolve?
- Which team appears to own this area?
- What work remains incomplete?
- Which decisions were later reversed?
- What changed during a migration?
- Which evidence should an agent inspect before modifying this code?

### 7.2 Compiler inputs

Compiler jobs may consume evidence from:

- one session
- one pull request
- one file
- one subsystem
- one repository
- a time range
- a release
- multiple related repositories
- an organization

### 7.3 Compiler outputs

Potential knowledge artifacts include:

- Pull Request Decision Summary
- Engineering Decision
- Rejected Alternative
- Engineering Constraint
- Deferred Work Item
- File Evolution Summary
- Subsystem Architecture Summary
- Migration Summary
- Ownership Summary
- Release Narrative
- Incident Learning Summary
- Current-State Project Summary
- Session Outcome Summary

### 7.4 Evidence-backed output

Every material assertion in a knowledge artifact should be traceable to supporting evidence.

A knowledge artifact should record:

- compiler type
- compiler version
- generation time
- evidence inputs
- confidence or uncertainty
- superseded artifacts
- scope
- authorization requirements

### 7.5 Deterministic work before model work

The compiler should use non-model processing wherever possible.

Examples:

- relationship construction
- timeline ordering
- commit-to-PR mapping
- file-history calculation
- ownership frequency
- thread resolution state
- changed-symbol extraction
- duplicate detection
- known-schema classification

Models should be reserved for tasks that genuinely require interpretation, such as:

- extracting implicit decisions
- distinguishing alternatives from conclusions
- explaining architectural intent
- identifying constraints
- summarizing disagreement
- connecting evidence across ambiguous references

### 7.6 Incremental compilation

The compiler should not repeatedly reprocess an entire organization whenever new evidence arrives.

It should support:

- incremental jobs
- dependency tracking
- invalidation
- targeted regeneration
- versioned artifacts
- changed-evidence detection

### 7.7 Multiple interpretations

Some evidence can support more than one reasonable interpretation.

The compiler should not manufacture certainty.

It should be able to preserve:

- uncertainty
- conflicting evidence
- competing interpretations
- unresolved questions
- changes in understanding over time

### 7.8 Human-authored knowledge

Not all knowledge must be AI-generated.

The platform should support:

- explicitly recorded decisions
- human-reviewed summaries
- manually curated constraints
- accepted architecture statements

Human-authored knowledge should still cite evidence and carry authorship and revision history.

## 8. Knowledge Store

The Knowledge Store contains compiled artifacts designed for reuse.

It is separate conceptually from the Evidence Store because derived knowledge has different lifecycle and consistency requirements.

### 8.1 Core properties

Knowledge artifacts should be:

- versioned
- evidence-linked
- regenerable
- searchable
- scope-aware
- confidence-aware
- replaceable
- comparable over time

### 8.2 Knowledge identity

A knowledge artifact should identify:

- artifact type
- subject
- scope
- compiler and version
- input evidence set
- generation timestamp
- validity or supersession status

### 8.3 Supersession

Knowledge should evolve without erasing its history.

For example:

```text
Subsystem Summary v1
        -> superseded by
Subsystem Summary v2
        -> superseded by
Subsystem Summary v3
```

The current artifact may be preferred for retrieval, while earlier artifacts remain available for audit and historical analysis.

### 8.4 Staleness

The system should detect when a knowledge artifact may be stale because:

- new evidence was added
- underlying files changed
- a decision was reversed
- a PR was reopened
- an issue changed state
- a new compiler version became available

Staleness does not always require immediate regeneration, but it should be visible.

### 8.5 Knowledge graphs and indexes

The Knowledge Store may maintain indexes or graph relationships connecting:

- decisions
- constraints
- files
- symbols
- services
- repositories
- teams
- pull requests
- issues
- migrations
- releases

These structures exist to improve retrieval.

They should not become an opaque replacement for the evidence graph.

## 9. Retrieval Engine

The Retrieval Engine assembles the smallest useful and trustworthy context package for a consumer.

Its job is not simply to search.

Its job is to select, rank, explain, cite, and budget context.

### 9.1 Retrieval goals

A strong retrieval response should be:

- relevant to the current task
- bounded in size
- supported by evidence
- explicit about uncertainty
- aware of current repository state
- authorized for the requesting consumer
- structured for agent use

### 9.2 Retrieval inputs

A request may include:

- current task
- repository
- branch
- worktree
- files
- symbols
- issue
- pull request
- user
- session
- agent role
- context budget
- requested artifact types

### 9.3 Retrieval stages

A retrieval flow may include:

```text
Request understanding
        ->
Scope and authorization filtering
        ->
Candidate discovery
        ->
Relationship expansion
        ->
Freshness and confidence checks
        ->
Ranking
        ->
Context budgeting
        ->
Evidence citation
        ->
Response assembly
```

### 9.4 Knowledge first, evidence on demand

For many tasks, retrieval should prefer concise knowledge artifacts and include direct evidence where needed.

Example:

```text
Architecture constraint
    Supported by:
    - PR review thread
    - implementation commit
    - session decision
```

The consumer receives the constraint without reading hundreds of records, but can inspect the evidence when verification or deeper reasoning is necessary.

### 9.5 Retrieval modes

Potential modes include:

- current-task context
- explain this file
- explain this subsystem
- session awareness
- decision lookup
- migration history
- related prior work
- unresolved constraints
- ownership discovery
- evidence audit
- full timeline reconstruction

### 9.6 Token and context budgets

The retrieval engine should treat context as a limited resource.

It should support:

- maximum token budgets
- artifact prioritization
- evidence compression
- summary depth
- progressive disclosure
- follow-up expansion

The platform should not return all available knowledge merely because it exists.

### 9.7 Fresh state and historical knowledge

Retrieval should distinguish between:

- current repository facts
- historical evidence
- compiled interpretation
- speculative or uncertain conclusions

A consumer should be able to tell whether it is seeing:

- what is true now
- what was true at a particular time
- what an engineer believed
- what the compiler inferred

## 10. Consumers

Consumers use Provenance Engine to improve engineering work.

They should interact through public contracts rather than reading internal storage directly.

### 10.1 bmux

Bmux is a primary consumer and evidence producer.

It may use Provenance Engine for:

- recording sessions
- recording tasks and agent relationships
- recording commands and artifacts
- displaying session trees
- current-task context
- worktree awareness
- file explanations
- session handoffs
- cross-session awareness
- reports
- notifications
- remote session workflows

Bmux owns the user experience.

Provenance Engine owns reusable provenance capabilities and data contracts.

### 10.2 AI agents

Agents may use Provenance Engine to:

- understand prior work
- inspect architectural constraints
- avoid repeating failed approaches
- locate relevant decisions
- assemble task context
- verify assumptions
- understand repository evolution
- coordinate indirectly through shared project state

Agents should not receive direct dumps of other sessions' complete context.

They should receive bounded, purpose-specific retrieval results.

### 10.3 CLI

The CLI may support:

- recording evidence
- querying sessions
- explaining files
- inspecting decisions
- retrieving current context
- auditing evidence
- checking compiler status
- debugging adapters

### 10.4 IDE integrations

Future IDE integrations may provide:

- file and symbol history
- related decisions
- review context
- current ownership
- prior failed attempts
- relevant session summaries

### 10.5 Organization services

Future organization-level consumers may include:

- engineering search
- onboarding tools
- architecture portals
- migration dashboards
- code ownership systems
- incident-learning systems
- compliance and audit workflows
- engineering leadership reporting

These consumers may require access to shared evidence without access to private personal evidence.

## 11. Deployment Model

The logical architecture should support several deployment stages.

### 11.1 Embedded local library

An early consumer may use Provenance Engine as an in-process package.

Advantages:

- simple adoption
- low operational overhead
- fast local access

Limitations:

- process coupling
- duplicated stores
- difficult cross-tool sharing
- harder organization-level ingestion

### 11.2 Local daemon or service

A local service may provide:

- one local evidence store
- multiple local consumers
- stable IPC or HTTP contracts
- background adapter work
- centralized local authorization
- independent engine upgrades

### 11.3 Shared organizational service

A shared service may provide:

- centralized repository evidence
- organization-wide knowledge compilation
- shared retrieval
- cross-repository relationships
- policy-controlled access
- reduced duplicate ingestion

### 11.4 Hybrid architecture

The likely long-term model is hybrid.

```text
Local Personal Evidence
        |
        +------------+
        |            |
        v            v
Local Retrieval    Shared Organizational Evidence
        |            |
        +-----+------+
              v
       Authorized Context Assembly
```

Personal unpublished work can remain local.

Shared repository knowledge can be compiled once and reused across the organization.

## 12. Authorization, Privacy, and Trust

A system that captures detailed engineering activity must treat authorization and privacy as architectural concerns, not later additions.

### 12.1 Authorization boundaries

Access decisions may depend on:

- user
- organization
- repository
- team
- project
- evidence origin
- evidence scope
- artifact sensitivity
- consumer type

### 12.2 Private evidence

Examples of potentially private evidence include:

- unpublished local work
- personal notes
- terminal output
- failed experiments
- credentials accidentally printed
- private agent conversations
- drafts
- sensitive organization discussions

Private evidence should not automatically become shared because it relates to a shared repository.

### 12.3 Secret handling

Adapters should support:

- redaction
- exclusion rules
- source allowlists
- path filters
- secret scanning
- configurable payload retention

The system should avoid recording secrets rather than relying solely on later deletion.

### 12.4 Trust and citations

Consumers should be able to inspect why a result was returned.

Important claims should include:

- supporting evidence
- compiler identity
- freshness
- confidence
- scope
- conflicting evidence where present

A trustworthy system should make it easy to verify its conclusions.

## 13. Failure Model

The architecture should degrade safely when individual layers fail.

### 13.1 Adapter failure

If an adapter fails:

- previously stored evidence remains available
- checkpoints identify the incomplete range
- retries do not duplicate evidence
- retrieval can report source staleness

### 13.2 Compiler failure

If compilation fails:

- raw evidence remains intact
- older knowledge artifacts may remain available
- stale status is visible
- compilation can resume or be rerun

### 13.3 Retrieval failure

If retrieval fails:

- evidence is not corrupted
- consumers receive a clear error
- direct lower-level queries may still be available
- the system does not fabricate context

### 13.4 Consumer failure

A failing consumer must not corrupt the evidence store.

Public write contracts should validate events before persistence.

### 13.5 Model failure

Model-generated knowledge may be incomplete or wrong.

The system should reduce this risk through:

- evidence citations
- bounded extraction tasks
- structured outputs
- confidence reporting
- deterministic preprocessing
- review workflows
- regeneration
- preservation of conflicting evidence

## 14. Architectural Invariants

The following invariants should guide implementation decisions.

### Invariant 1: Evidence is not replaced by summaries

Compiled knowledge may compress evidence, but it must not erase the evidence from which it was produced.

### Invariant 2: Knowledge is evidence-backed

Material knowledge claims should identify their supporting evidence.

### Invariant 3: Consumers do not depend on internal storage

Bmux, agents, CLIs, and future tools should use public contracts and APIs rather than reading Provenance Engine's SQLite schema directly.

### Invariant 4: Project knowledge can grow without unbounded agent context

Retrieval must remain selective and budget-aware.

### Invariant 5: Source-specific meaning is preserved

Normalization should enable shared behavior without destroying important source semantics.

### Invariant 6: Personal and shared evidence remain distinguishable

Local private evidence should not be silently promoted into organization-wide evidence.

### Invariant 7: Interpretation is regenerable

Knowledge artifacts should carry enough lineage to be rebuilt when compiler logic changes.

### Invariant 8: Models are used only where interpretation is required

Deterministic computation should handle deterministic work.

### Invariant 9: Cross-system relationships are first-class

The platform's value comes not only from storing records, but from connecting sessions, code, reviews, decisions, artifacts, and outcomes.

### Invariant 10: Current truth and historical truth are not conflated

The system should distinguish current state from past state, authored opinion, and compiler inference.

## 15. Reference Data Flow

The following example illustrates how evidence moves through the system.

### Example: pull-request design decision

A developer uses bmux and Codex to change authentication middleware.

During the work:

1. Bmux records the session and task.
2. Codex executes commands and modifies files.
3. The developer records an explicit design decision.
4. Git records the resulting commits.
5. GitHub records the pull request.
6. A reviewer objects to request-context coupling.
7. The implementation is revised.
8. The review thread is resolved.
9. The pull request is merged.

The adapters ingest:

- session events
- task relationships
- command facts
- decision evidence
- commits
- changed files
- PR body
- review comments
- resolution state

The Evidence Store preserves these records and their relationships.

The Knowledge Compiler produces:

```text
Engineering Constraint

Authentication middleware must remain usable outside HTTP request
contexts because CLI consumers also invoke the same authorization path.

Supporting evidence:
- review comment
- resolved review thread
- revised commit
- session decision
```

The Knowledge Store saves that artifact with compiler lineage.

Months later, an agent modifying the same middleware asks for current-task context.

The Retrieval Engine returns:

- the engineering constraint
- the affected files
- the latest implementation state
- the most relevant supporting review evidence
- a warning if later commits appear to conflict with the constraint

The agent receives useful context without loading the entire session, PR, and repository history.

## 16. Initial Knowledge Artifacts

The architecture supports many future artifacts, but implementation should begin with narrowly defined outputs whose value can be measured.

A strong first artifact is:

### Pull Request Decision Summary

Potential fields:

- purpose of the change
- accepted design
- alternatives considered
- rejected alternatives
- reviewer objections
- engineering constraints
- deferred work
- unresolved concerns
- implementation commits
- affected files and subsystems
- supporting evidence

This artifact is a useful first compiler target because pull requests naturally connect:

- intent
- implementation
- review
- disagreement
- resolution
- outcome

The first implementation should be treated as a validation of the evidence and compilation model, not as proof that all organizational knowledge should immediately be AI-compiled.

## 17. Evolution Strategy

The reference architecture describes the destination, but the platform should evolve through validated slices.

A sensible progression is:

```text
Reliable local evidence ledger
        ->
Stable public contracts
        ->
Real bmux adoption
        ->
Multiple provenance-powered workflows
        ->
External evidence ingestion spike
        ->
First evidence-backed compiler artifact
        ->
Knowledge-aware retrieval
        ->
Shared repository evidence
        ->
Organization-scale authorization and deployment
```

Every phase should validate the assumptions required by the next.

The system should not build an organization-scale knowledge compiler before proving:

- evidence quality
- relationship quality
- retrieval usefulness
- consumer integration
- trust and citation behavior

## 18. Relationship to Repository Plans

This document defines the architecture of the Provenance Engine platform.

The repository roadmaps define implementation sequence and ownership.

### provenance-engine roadmap

Owns the delivery sequence for:

- evidence contracts
- storage
- adapters
- compiler infrastructure
- knowledge storage
- retrieval
- deployment boundaries

### bmux roadmap

Owns the delivery sequence for:

- capture integration
- orchestration
- provenance-powered UX
- reports
- user workflows
- local consumer behavior

### shared integration roadmap

Owns:

- cross-repository adoption milestones
- compatibility gates
- rollback
- migration sequencing
- removal of duplicated behavior

Roadmaps should link to this document rather than reproducing its full architecture.

## 19. Current Implementation Mapping

This section maps the north-star architecture above to the current repository decisions. It is descriptive, not a milestone change.

### Implemented now

- The repository is an independent Swift package with `ProvenanceEngineContracts`, `ProvenanceEngineSDK`, and internal `ProvenanceEngineSQLite` modules.
- Public adopters construct clients through `ProvenanceEngineClientFactory` and interact through `any ProvenanceEngineClient`.
- The SQLite backend owns an append-oriented event ledger, schema migration metadata, validation, storage summaries, repair reports, bounded ledger reads, and rebuildable current-state projections.
- Current projections include repositories, worktrees, sessions, session relationships, file explanations, and current context records.
- Public contracts exist for event append, session lifecycle recording, worktree reads, session-tree reads, file explanations, current context, health, and storage summaries.
- New engine-owned local storage defaults to `~/.local/state/provenance-engine/provenance.sqlite`.
- Events can carry optional `ProvenanceEvidenceOrigin` and `ProvenanceEvidenceScope` metadata so the ledger is not hard-coded as personal-only evidence.
- The first bmux adoption path, `bmux provenance worktrees list`, has adopted the engine SDK and worktree read contract.

### Partially implemented

- The Evidence Store exists as a local SQLite implementation, but shared project and organization stores are not implemented.
- Evidence scope currently supports the accepted V1 coarse scopes: personal, project, and organization. Finer-grained scopes such as session, workspace, team, repository, and public remain architectural concepts unless added through future contracts.
- Cross-system relationships are represented for current local session/worktree projections, but Git, GitHub, review, issue, document, and communication relationships are not implemented.
- Bmux is both a current adopter and a likely evidence producer, but V1 adoption is intentionally limited to one path at a time.
- Current context and file explanation contracts exist, but evidence-aware retrieval and compiled knowledge retrieval do not exist.
- Storage validation, replay, and repair support the current local ledger, but source deletion propagation, raw payload retention policy, and organization-level audit policy are not implemented.

### Planned after V1

- External evidence model validation beyond the current origin and scope fields.
- Shared evidence-store design for personal, project, and organization evidence.
- Raw GitHub ingestion of objective evidence such as commits, pull requests, reviews, review threads, merge state, changed files, and commit-to-PR relationships.
- The first Knowledge Compiler artifact, expected to be Pull Request Decision Summary after the GitHub ingestion spike validates evidence shape.
- Evidence-aware retrieval that prefers compiled knowledge plus minimal supporting evidence.
- Daemon or service transport after in-process adoption proves the public contracts.
- Organization-scale deployment, authorization enforcement, compatibility policy, and shared retrieval.

### Intentionally unresolved

- Local daemon transport and shared service transport.
- Evidence-store technology beyond the current local SQLite implementation.
- Knowledge-store technology, graph representation, search strategy, ranking strategy, and embedding usage.
- Compiler orchestration, invalidation, review workflows, model-provider abstraction, and cost controls.
- Organization tenancy, authorization policy, private-to-shared promotion rules, source deletion propagation, and evidence and knowledge retention policy.
- Slack, email, and other communication ingestion policies.
- GitHub authentication and cross-repository identity.
- The long-term split between bmux-owned capture adapters and Provenance Engine-owned reusable adapter contracts.

### Conflicts and ambiguities found

No direct conflict was found between this north-star architecture and the current V1 repository decisions.

The main ambiguity is ownership of capture adapters over time. Current cross-repository plans keep bmux-owned product capture policy and rollout behavior in bmux, while Provenance Engine owns reusable provenance capabilities, storage, and public data contracts. Future adapter work should make that boundary explicit before moving capture policy into this repository.

The architecture names finer-grained evidence scopes than the current V1 contract exposes. This is not a current conflict, but future scope expansion should be handled as an explicit contract decision rather than inferred from this document alone.

## 20. Open Architectural Decisions

This document intentionally does not resolve every future implementation choice.

The following decisions should be addressed through focused ADRs or design work when they become active:

- local daemon transport
- shared service transport
- evidence-store technology beyond the current local implementation
- knowledge-store technology
- graph representation
- search and ranking strategy
- embedding usage
- compiler orchestration
- artifact invalidation
- organization tenancy
- authorization policy
- private-to-shared promotion rules
- raw payload retention
- source deletion propagation
- Slack and communication ingestion
- GitHub authentication
- cross-repository identity
- shared deployment model
- human review of compiled knowledge
- model-provider abstraction
- cost controls
- evidence and knowledge retention policy

These should remain explicit open decisions rather than being resolved accidentally inside unrelated implementation work.

## 21. North-Star Definition

Provenance Engine should ultimately make it possible for an engineer or agent to ask:

> What do I need to understand before safely doing this work?

and receive a concise, current, evidence-backed answer assembled from the accumulated history of the project.

The platform succeeds when:

- granular evidence is preserved
- engineering knowledge improves over time
- decisions and constraints remain discoverable
- agents avoid repeating prior mistakes
- context remains bounded
- claims remain verifiable
- multiple tools can share the same project understanding
- organizational knowledge survives individual sessions and employees

The long-term transformation is:

```text
From:
Record engineering activity

To:
Compile trustworthy engineering knowledge

To:
Deliver the right knowledge at the moment of work
```

That is the architectural purpose of Provenance Engine.
