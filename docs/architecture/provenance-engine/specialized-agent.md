# Provenance Engine Specialized Agent Architecture

Status: future architecture horizon; implementation should follow useful local Knowledge Compiler output, evidence-aware retrieval validation, and then shared knowledge validation where organization-specific training is desired.

## Goal

Use Provenance Engine-derived knowledge and structured session observations to support increasingly specialized engineering agents without prematurely training a new model on raw session exhaust.

The recommended progression is:

```text
PE-backed specialist agent
  -> curated PE-derived behavior/training corpus
  -> PE-trained specialization layer
  -> organization-specific engineering agent
```

The first useful version should be retrieval-backed rather than newly trained.

## Stage 1: PE-Backed Specialist Agent

Start with a strong general coding/reasoning model whose task context is assembled from PE.

```text
current task/session
      |
      v
PE evidence-aware retrieval
      |
      +-- architecture knowledge
      +-- contracts / invariants
      +-- prior decisions
      +-- relevant milestones
      +-- blocker / approach-change patterns
      +-- code and component relationships
      +-- provenance references
      |
      v
bounded specialist context
      |
      v
engineering agent
```

This agent should gain specialization from current PE knowledge rather than from a frozen model checkpoint. Repository knowledge can therefore evolve without retraining whenever the codebase or architecture changes.

PE owns retrieval and context assembly. bmux or another consumer should not independently rebuild the knowledge graph into prompts.

## Initial Agent Role

The most differentiated PE-backed agent is not necessarily another general implementation agent.

A useful specialization is an engineering-work intelligence agent that can:

- interpret what a coding agent is currently doing;
- retrieve the smallest relevant set of project knowledge;
- identify current milestones and likely next transitions;
- detect blockers, approach changes, repeated loops, or context drift;
- compare the current session with similar historical work;
- surface architectural constraints and prior decisions before they are violated;
- recommend when additional context or evidence should be retrieved;
- explain recommendations through PE provenance.

Codex, Claude, or another coding agent may remain the primary implementation agent while the PE-backed specialist provides persistent engineering intelligence around it.

## Stage 2: Curated PE-Derived Training Corpus

Do not train directly on the complete raw PE event stream.

Raw session data contains abandoned approaches, incorrect assumptions, secrets, source snippets, transient failures, duplicated activity, and behavior that should not be imitated.

Instead derive training examples only after PE has enough semantic structure to distinguish evidence from interpretation and successful behavior from superseded or incorrect behavior.

A conceptual example:

```text
Situation:
  coding agent changed files A/B/C and repeatedly retried failing tests

Evidence:
  test failures
  command sequence
  milestone state
  elapsed blocker period
  relevant architecture / environment facts

Validated interpretation:
  agent is blocked on generated-schema mismatch rather than implementation logic

Useful intervention:
  validate generated schema version before changing application code

Provenance:
  supporting sessions / milestones / commits / evidence revisions
```

Useful future training targets include:

- task and milestone classification;
- blocker recognition;
- approach-change detection;
- architecture-impact inference;
- next-action recommendation;
- retrieval/context-selection quality;
- detection of unproductive loops or session drift;
- intervention timing;
- explanation selection and presentation.

## Training Data Quality Boundary

A PE-derived example should be eligible for training only when policy and evidence quality requirements are satisfied.

Possible requirements include:

- sufficient supporting evidence;
- semantic interpretation is current rather than superseded;
- no unresolved contradiction that materially changes the label;
- sensitive content has been removed or transformed according to policy;
- organization/repository visibility permits the intended training use;
- the example can retain provenance metadata without exposing private raw content;
- outcome quality is known well enough to avoid teaching failed behavior as preferred behavior.

The exact acceptance policy is deferred until real compiler output exists.

## Stage 3: PE-Trained Specialization Layer

Once a high-quality corpus exists, evaluate whether training or fine-tuning measurably improves tasks that retrieval alone handles poorly.

Training should focus on reusable behavior and interpretation patterns rather than memorizing fast-changing repository facts.

Good candidates for learned specialization:

```text
recognize blocker pattern
recognize approach change
estimate whether current progress is unusual
choose which PE knowledge to retrieve next
classify milestone transition
select an intervention strategy
```

Repository facts such as current architecture, APIs, ownership, and invariants should normally remain retrieval-backed because they change over time and benefit from provenance/revision semantics.

This yields a deliberate split:

```text
TRAINING
  learns how to interpret engineering work
  learns how to retrieve and reason about PE knowledge
  learns intervention patterns

PE RETRIEVAL
  supplies what is currently true about this repository/project
  supplies current evidence and provenance
  supplies revisioned organizational knowledge
```

## Stage 4: Organization-Specific Engineering Agent

After shared PE knowledge is proven useful and privacy/access boundaries are validated, an organization may evaluate a specialization trained on curated cross-engineer derived observations.

That agent could learn organization-specific work patterns such as:

- common failure modes in a subsystem;
- typical successful implementation sequences;
- architectural constraints repeatedly relevant to certain tasks;
- task classes that commonly require additional context;
- blocker patterns that recur across engineers or coding agents;
- which intervention strategies historically restore progress.

Organization-specific training must remain additive to shared PE retrieval. It must not replace retrieval of current revisioned knowledge.

## Relationship to Shared Knowledge

The shared PE layer provides two distinct assets:

1. revisioned shared project knowledge used directly at retrieval time;
2. normalized, policy-approved observations that may eventually contribute to curated training datasets.

These should not be conflated. A record may be useful for retrieval but inappropriate for training, or vice versa.

Training export therefore requires its own explicit policy and derivation boundary.

## Privacy and Governance

Do not create an organizational training corpus by simply centralizing engineers' raw prompts, reasoning, transcripts, source snippets, or command history.

Prefer:

- derived and normalized examples;
- explicit visibility/training eligibility;
- removal of secrets and unnecessary source content;
- aggregate/pseudonymous patterns where identity is irrelevant;
- provenance retained for auditability;
- deletion/revocation semantics where organization policy requires them;
- evaluation against engineering-assistance outcomes rather than employee ranking.

PE-derived training should improve agents and team knowledge, not become an employee-surveillance dataset.

## Evaluation Before Training

Before training a specialized model, establish a retrieval-backed baseline and measure whether training adds value.

Useful comparisons include:

- PE retrieval-backed general model versus general model alone;
- retrieval-backed agent versus fine-tuned agent without retrieval;
- retrieval-backed plus specialization versus retrieval alone;
- blocker/milestone classification accuracy;
- time to useful intervention;
- false-positive intervention rate;
- context-token usage;
- task completion quality and rework;
- ability to explain conclusions using PE provenance.

Do not assume model training is worthwhile merely because a dataset exists.

## Recommended Sequencing

```text
factual evidence
  -> semantic inference / SessionWorkModel
  -> milestone + blocker + code + architecture relationships
  -> local Knowledge Compiler
  -> evidence-aware retrieval
  -> PE-backed specialist agent
  -> context/intervention effectiveness experiments
  -> shared knowledge validation
  -> curated PE-derived training corpus
  -> specialization experiment
  -> organization-specific specialization, if justified
```

The PE-backed agent can begin before shared cloud knowledge exists. Organization-specific training should follow successful shared-knowledge governance and usefulness validation.

## Non-Goals / Guardrails

Do not:

- train a new model before measuring what retrieval-backed specialization can accomplish;
- train directly on uncurated raw PE session exhaust;
- encode fast-changing repository facts only in model weights;
- remove provenance simply because an example has been converted into training data;
- let training eligibility implicitly follow knowledge-sharing eligibility;
- optimize primarily for employee productivity scoring or ranking;
- make organization-specific training a prerequisite for local PE usefulness;
- assume fine-tuning is preferable to prompting/retrieval without evaluation evidence.

## Future Questions

Validate later:

- which specialist-agent responsibilities produce meaningful improvements over the implementation agent alone;
- which semantic judgments are reliable enough to become training labels;
- how outcomes should be scored when multiple implementation approaches are valid;
- whether training mainly improves interpretation, retrieval selection, intervention timing, or all three;
- how to prevent superseded architectural knowledge from contaminating training examples;
- what organization-level privacy and consent rules should govern derived training datasets;
- whether models should be specialized per organization, per repository family, or around provider-neutral engineering-work behaviors;
- how often a specialization needs refresh as PE's semantic model evolves.
