Bmux Context Efficiency and Thread Lifecycle System
Mission

Extend Bmux into a context-efficiency, thread-lifecycle, provenance, and handoff system for long-running Codex work.

The system should help answer and act on questions such as:

Where did a thread’s token usage come from?
How much context is being carried into each model call?
Which commands or events introduced the most persistent context?
When has a thread become structurally inefficient?
When would a fresh thread plus structured handoff be cheaper and safer?
What knowledge must survive a restart?
Which terminal output can be compressed before reaching Codex?
Is a thread making useful progress relative to its cost?
Are multiple sessions duplicating the same work?
How should thresholds and handoff policies improve as Bmux collects more data?

This is not merely a token counter. It is a causal profiler and lifecycle manager for agent work.

Important empirical findings

Use these findings as the initial motivation and calibration data, not as unquestionable universal rules.

A local Codex rollout analysis for one day found:

1,858 total model calls
244,848,460 total observed tokens
234,821,888 cached-input tokens
8,928,473 non-cached input tokens
709,226 output tokens
median cached input per call: 126,336 tokens
maximum cached input per call: 240,512 tokens
12 compaction model calls
74 suspicious low-information/high-context calls
the largest thread:
101,689,172 total tokens
97,093,888 cached-input tokens
737 calls
a simulated practical handoff policy using approximately 10K-token handoffs estimated:
central savings estimate: 129,257,102 tokens
estimated reduction: 52.8%
simulated restarts: 65

The dominant pattern was repeated processing of large thread contexts over hundreds of model calls. Raw output compression may help, but thread lifecycle and structured handoffs appear to be the larger opportunity.

Non-negotiable principles

Treat these as architectural invariants.

Inspect before designing
Do not assume Bmux currently has or lacks any subsystem.
First identify the existing implementations for session management, terminal capture, Codex integration, persistence, worktrees, reports, provenance, indexing, and UI windows.
Reuse and extend existing abstractions when reasonable.
Raw evidence is never destroyed
Bmux may compress, summarize, classify, or exclude content from model context.
Original terminal output, tool output, telemetry, and source events must remain available for inspection.
Observation must precede intervention
Build trustworthy telemetry and attribution before adding automatic thread interruption or output filtering.
Initial lifecycle policies must run in shadow mode.
No silent context loss
Any omitted or compressed evidence must be recoverable.
The user and agent should be able to request the original data.
Facts and inference must remain distinct
Persisted facts such as token counts, commands, files changed, commits, and tool results must be distinguishable from inferred labels such as “likely waste” or “thread may be looping.”
Correctness outranks token reduction
A policy that reduces tokens while increasing mistakes, rediscovery, or failed work is not successful.
Every recommendation must be explainable
A warning or handoff recommendation must state which conditions fired and show the underlying measurements.
User-authored decisions outrank inferred conclusions
Do not allow automatic summaries to silently overwrite explicit project decisions.
Policy changes must be versioned
Thresholds, scoring functions, classifiers, schemas, and handoff formats must have versions so historical evaluations remain reproducible.
Do not make the architecture Codex-specific when avoidable
Codex is the first supported agent.
Keep the event and lifecycle model extensible enough to support other terminal-based agents later.
Desired system architecture

Build toward these cooperating subsystems:

Codex / terminal process
        │
        ▼
PTY and process event capture
        │
        ├──────────────► Raw evidence store
        │
        ▼
Canonical event normalization
        │
        ├──────────────► Token telemetry ingestion
        ├──────────────► Command/output attribution
        └──────────────► Session/thread identity resolution
        │
        ▼
Work-phase and progress model
        │
        ├──────────────► Provenance / project knowledge model
        ├──────────────► Efficiency profiler
        ├──────────────► Loop and redundancy detection
        └──────────────► Build Story / activity narrative
        │
        ▼
Thread lifecycle policy engine
        │
        ├──────────────► Warnings
        ├──────────────► Handoff simulations
        ├──────────────► Handoff recommendations
        └──────────────► Eventually controlled automation
        │
        ▼
Structured handoff package
        │
        ├──────────────► New Codex thread
        ├──────────────► Existing related thread
        └──────────────► Durable project memory

RTK or native command-output compression should be integrated as a separate but connected layer:

Raw command output
        │
        ├──────────────► Durable raw evidence
        │
        ▼
Command-aware reducer
        │
        ▼
Reduced representation supplied to Codex
Phase 0: Repository discovery

Do not begin broad implementation before completing this phase.

Tasks

Inspect the Bmux repository and produce an architecture inventory covering:

application entry points;
Swift modules and major packages;
terminal and PTY integration;
Ghostty-related integration, if present;
process spawning and shell command handling;
Codex process launching and session handling;
session identity and persistence;
workspace and worktree representation;
database or filesystem persistence;
current report generation;
terminal scrollback handling;
window and tab architecture;
any existing separate coordination/reporting window;
any existing parser, summarizer, or structured event representation;
hooks, plugins, shell wrappers, and environment injection;
any RTK integration or experiments;
existing tests;
existing analytics or logging;
old session indexing or search;
provenance or work-contribution data structures;
project-level memory or evolving model work.

Search for both implemented code and planning documents.

Deliverable

Create:

docs/context-efficiency/current-architecture.md

Include:

what exists;
where it exists;
what is partial;
what is planned but unimplemented;
what can be reused;
what should be replaced;
important coupling risks;
unknowns requiring experiments.

Also produce a dependency map showing which existing components the new system should extend.

Stop condition

Before implementation, present the discovery report and a proposed change map. Do not create a parallel architecture where an existing suitable subsystem already exists.

Phase 1: Define the canonical data model

Create a stable internal vocabulary before building UI or automated policy.

Core entities

At minimum, model the following concepts.

Workspace

A Bmux workspace containing one or more terminal sessions, repositories, worktrees, or agent threads.

Suggested fields:

workspaceID
createdAt
updatedAt
displayName
repositoryIDs
activeWorkItemIDs
Repository
repositoryID
canonical path
remote origin
branch
current commit
metadata timestamps
Worktree
worktreeID
repository ID
path
branch
head commit
creation source
active or archived status
Agent thread

Represent a logical Codex conversation independently from the terminal tab.

threadID
external Codex thread identifier
model
reasoning level
start and end times
workspace, repository, and worktree associations
parent thread or handoff source
status
lifecycle state
cumulative token totals
current estimated context
compaction count
model-call count
Terminal session
terminalSessionID
PTY/process identity
tab/window identity
associated agent thread
start and end timestamps
process tree references

Do not assume one terminal session always equals one logical agent thread.

Model call
modelCallID
thread ID
timestamp
input tokens
cached-input tokens
output tokens
reasoning-output tokens when available
estimated context size
context-window capacity
call classification
nearby tool or shell events
telemetry source and confidence
Command execution
commandID
thread ID
terminal session ID
normalized executable and arguments
raw command text
working directory
start and completion time
exit status
raw stdout and stderr references
original byte and estimated-token counts
reduced byte and estimated-token counts
command category
files mentioned or affected
Evidence artifact

Used for raw terminal output, diffs, logs, test reports, screenshots, summaries, and analyzer outputs.

artifactID
type
storage location
content hash
byte count
estimated tokens
producer event
creation time
retention policy
Work item

A durable unit of intended work that may span threads and worktrees.

workItemID
objective
status
repository
related issue or task
parent work item
acceptance criteria
active threads
provenance links
Work contribution

Connect actual work to sessions and threads.

contributionID
work item
thread
worktree
files changed
commits
decisions
validations
time range
confidence and evidence
Decision
statement
rationale
status
author type: user, agent, inferred
supporting evidence
superseded decision
affected work items and files
Discovery

A technical fact discovered during work.

Failed approach
attempted approach
failure reason
supporting evidence
whether retry is appropriate
Invariant

A constraint future agents must preserve.

Open question
question
current hypotheses
owner
blocking status
Handoff
source thread
destination thread
trigger
policy version
summary schema version
included structured data
artifact references
estimated token size
actual token size when known
subsequent rediscovery metrics
outcome
Lifecycle intervention
intervention type
trigger measurements
recommendation
accepted, ignored, or deferred state
outcome
Deliverables

Create:

docs/context-efficiency/domain-model.md
docs/context-efficiency/event-schema.md

Use Swift types that can be serialized with explicit schema versions.

Avoid creating a large inheritance tree. Prefer composable value types and explicit relationships.

Phase 2: Local telemetry ingestion

Build the ability to reconstruct Codex usage without placing rollout logs into model context.

Requirements
Stream-parse persisted Codex JSONL files.
Never load an entire large rollout into memory.
Never print large raw payloads into an agent conversation.
Detect and skip duplicate token telemetry where cumulative totals have not advanced.
Preserve source file offsets or event references for forensic inspection.
Support incremental parsing so only newly appended events are processed.
Detect:
model calls;
token-count updates;
compaction calls;
tool calls;
shell commands;
tool outputs;
thread identifiers;
session timing;
model and context-window metadata when available.
Treat undocumented or unstable event fields defensively.
Record parser errors without halting ingestion of the rest of the file.
Version the parser and parsed schema.
Storage

Choose the repository’s existing persistence approach when suitable.

If there is no appropriate persistence layer, prefer a local SQLite database with:

migrations;
indexed timestamps;
indexed thread IDs;
indexed work item and worktree relationships;
normalized event tables;
content-addressed external storage for very large raw artifacts.

Do not put multi-megabyte terminal output directly into frequently queried rows.

Deliverables
incremental rollout parser;
persistence migration;
fixture-based tests using sanitized rollout fragments;
command-line diagnostic tool;
import status and error reporting.

Suggested diagnostic interface:

bmux-context import <rollout-path>
bmux-context inspect-thread <thread-id>
bmux-context summarize-day 2026-07-13

The actual integration should follow existing Bmux conventions rather than blindly introducing a separate CLI if unsuitable.

Phase 3: Terminal and command attribution

Token telemetry alone shows cost but not cause. Connect model calls to terminal activity.

Tasks

Capture and normalize:

command start;
command completion;
working directory;
exit status;
stdout and stderr byte counts;
elapsed time;
process identity;
command category;
related model-call interval;
raw evidence artifact;
reduced representation if filtering is active.

Classify common command families:

source search;
file reading;
git status;
git diff;
git log;
tests;
builds;
type checking;
linting;
package installation;
code generation;
server logs;
directory listing;
process monitoring;
arbitrary or unknown commands.
Attribution rules

Start with deterministic temporal attribution:

tool output produced between model call A and model call B is a candidate input contributor to B;
commands explicitly initiated by a tool call should be directly linked;
maintain confidence levels where attribution is ambiguous;
do not pretend exact token causality can be known when telemetry only provides aggregate counts.
Metrics

For each command, estimate:

raw output tokens;
reduced output tokens;
initial context contribution;
number of subsequent calls before compaction or handoff;
potential downstream repeated-context exposure;
whether the same command or output was repeated;
whether Codex later requested omitted details.

Do not label the downstream estimate as actual billed tokens unless exact evidence supports it.

Phase 4: Efficiency profiler

Build thread-, call-, command-, and work-item-level analysis.

Required metrics
Per call
cached input;
non-cached input;
output;
total;
cached-to-new ratio;
context-window utilization;
change from previous call;
time since previous call;
active work phase;
nearby command-output size.
Per thread
cumulative tokens;
cumulative cached input;
cumulative new input;
cumulative output;
call count;
median and peak context;
compaction count;
time active;
cost by work phase;
cost by command category;
number of repeated searches;
number of repeated file reads;
number of repeated failing commands;
total changed files;
commits;
validation events;
completed milestones;
interventions and outcomes.
Per work item

Aggregate across threads and worktrees:

total token usage;
total calls;
number of handoffs;
rediscovery after handoff;
duplicated work;
time to completion;
validations passed;
final outcome.
Initial heuristic signals

Implement these as configurable, versioned signals—not universal truths.

High context
cached input above 100K;
or estimated context above 70% of the model window.
Compaction ineffectiveness
compaction occurs;
the next normal call does not materially reduce cached input.

Define “materially” as a configurable percentage rather than hardcoding an unexplained constant.

Extreme cached-to-new ratio
cached input divided by new input is at least 50:1;
exclude or separately classify compaction calls;
avoid treating active tool-output processing as automatic waste.
Low-information/high-context call

Use a transparent initial heuristic combining:

high cached input;
very small new input;
very small output;
no meaningful tool result;
no detected state change;
no milestone or validation.
Repetition

Detect:

identical commands;
normalized command similarity;
repeated file reads;
repeated searches;
repeated diagnostics;
near-duplicate large outputs;
repeated investigation of settled questions.
Possible loop

Combine multiple signals over a time window:

repeated command clusters;
repeated failures;
low file-change progress;
high call count;
no new decision, discovery, validation, or milestone;
rising cumulative context.

Do not call a thread “stuck” based only on high token usage.

Phase 5: Work progress and provenance model

Efficiency cannot be judged without knowing whether useful work occurred.

Build an incremental project model

Track:

active objective;
work phase;
milestones;
files investigated;
files changed;
architectural decisions;
user decisions;
discoveries;
failed approaches;
open questions;
blockers;
invariants;
test and validation results;
commits;
current next action.

Use deterministic evidence where possible:

git status and diff;
commits;
test results;
command execution;
explicit agent statements;
explicit user instructions.

Use model-derived summaries only where needed, label them as inferred, and attach evidence references.

Work phases

Start with a small explicit taxonomy:

orientation;
investigation;
planning;
implementation;
debugging;
validation;
cleanup;
documentation;
waiting or blocked;
handoff preparation.

Allow unknown or mixed phases.

Important constraint

Do not repeatedly send entire raw session histories to a model to derive this state. Update the project model incrementally from bounded event batches and structured prior state.

Phase 6: Build Story and coordination UI

Extend the previously planned separate Bmux coordination window rather than crowding the normal terminal workspace.

Required views
Fleet view

Show all active Codex threads with:

objective;
repository and worktree;
lifecycle state;
current context estimate;
cumulative tokens;
cached-to-new ratio;
call count;
last meaningful progress;
current phase;
warnings;
recommended action.
Thread detail

Include:

token timeline;
context per call;
compactions;
commands and outputs;
progress events;
file and commit activity;
decisions;
discoveries;
failed approaches;
detected repetition;
lifecycle recommendations;
raw evidence links.
Work-item view

Combine all related threads and worktrees:

contributions;
overlaps;
conflicting edits;
decisions;
current owner;
duplicate investigation;
handoff history;
completion state.
Handoff preview

Before creating a new thread, show:

proposed handoff;
estimated token size;
included facts;
omitted raw evidence;
artifact references;
unresolved questions;
exact next action;
reason the handoff is recommended.

The user must be able to edit the handoff before sending it.

Policy explanation

For every warning:

Handoff suggested because:
- cached input has exceeded 100K for 38 calls
- the most recent compaction reduced the next call by only 4%
- cached-to-new ratio has remained above 50:1
- the thread has completed a stable implementation milestone

Avoid opaque “efficiency score: 62” interfaces without an explanation.

Phase 7: Structured handoff engine

The handoff system is the central intervention.

Handoff schema

Generate a bounded structured package containing:

Identity
project;
repository;
worktree;
branch;
current commit;
source thread;
work item.
Objective
original objective;
current narrowed objective;
acceptance criteria.
Completed work
milestones completed;
files changed;
commits;
key implementation details.
Current repository state
uncommitted changes;
failing tests;
active processes;
generated artifacts.
Decisions
explicit user decisions;
accepted architectural decisions;
rationale;
superseded decisions.
Discoveries and invariants
facts learned;
constraints that must be preserved;
relevant code locations.
Failed approaches
what was attempted;
why it failed;
whether it should be reconsidered.
Open questions and blockers
unresolved questions;
current hypotheses;
missing information.
Validation
tests run;
tests passed or failed;
commands required to reproduce.
Exact continuation instruction
next intended action;
files likely needed;
commands likely needed;
definition of done for the next milestone.
References
artifact IDs or paths for raw logs;
diffs;
reports;
detailed output not embedded in the handoff.
Size policy

Begin with a target around 10K tokens, but make it configurable.

Use prioritization rather than crude truncation:

explicit user decisions;
objective and acceptance criteria;
current repository state;
active blockers;
architectural invariants;
relevant files and changes;
validation state;
failed approaches;
lower-priority historical narrative.
Handoff validation

Before starting the new thread:

verify referenced paths still exist;
verify branch and commit;
verify worktree;
verify uncommitted state;
estimate handoff tokens;
flag unresolved ambiguity.

After starting the new thread, measure:

files reread;
questions repeated;
commands repeated;
decisions rediscovered;
time to useful progress;
tokens before first meaningful progress;
whether the handoff omitted required context.

This feedback should improve future handoff schemas.

Phase 8: Thread lifecycle policy engine

Implement policy stages gradually.

Stage A: Shadow mode

The system detects candidate intervention points but does nothing.

Log:

timestamp;
policy version;
conditions;
estimated current context;
estimated handoff size;
estimated savings;
confidence;
later actual thread outcome.

The UI may show a passive marker.

Stage B: Recommendation mode

Display:

why the handoff is recommended;
estimated continuation cost;
estimated restart cost;
confidence interval where possible;
handoff preview.

The user decides.

Stage C: Assisted handoff

Bmux:

generates the handoff;
creates or selects the destination thread;
prepares the prompt;
verifies worktree state;
asks the user to approve the transition.
Stage D: Narrow automatic behavior

Only after adequate validation, allow opt-in automation for tightly constrained cases, such as:

thread has crossed a configured critical threshold;
a stable milestone has completed;
repository state is clean or explicitly captured;
handoff validation succeeds;
confidence is high;
user has enabled automatic handoffs.

Never automatically kill a thread merely because it is expensive.

Phase 9: RTK and command-output reduction

Integrate RTK or build compatible command-aware reduction behind an abstraction.

First determine
whether Bmux already wraps commands;
whether Codex executes commands through a controllable shell boundary;
whether interception can occur before output enters Codex;
whether RTK can be integrated without breaking interactive commands;
whether Bmux currently duplicates or reinjects terminal output.
Requirements

For each supported command:

preserve complete raw output;
produce a reduced representation;
record compression ratio;
record estimated tokens removed;
indicate that content was omitted;
provide a deterministic way for Codex to request the full artifact;
avoid filtering interactive TUI applications;
fall back safely for unknown commands.
Initial command strategies
Tests

Preserve:

failing test names;
relevant assertion output;
concise stack traces;
summary counts;
execution status.

Collapse large successful-test output.

Builds and type checks

Preserve:

errors;
relevant warnings;
file locations;
final status.

Collapse repeated progress output and duplicated diagnostics.

Search

Preserve:

matching file paths;
relevant matched lines;
total counts;
truncation indicator.

Avoid flooding context with hundreds of equivalent matches.

Git diff

Prefer:

file summary first;
targeted hunks;
full diff available by artifact reference.

Do not hide unresolved conflicts or changed generated files.

Logs

Deduplicate repeated lines and group repeated patterns while retaining timestamps and first/last occurrence.

Evaluation

Measure:

raw versus reduced size;
downstream token usage;
frequency of requests for omitted evidence;
failures attributable to missing detail;
command categories with the greatest net benefit.

RTK savings must be measured separately from handoff savings.

Phase 10: Adaptive policy learning

Do not begin with a self-modifying black-box system.

Initial approach

Use versioned, interpretable statistical calibration.

Learn parameters such as:

ideal warning threshold by model;
ideal handoff point by repository and task type;
expected handoff rediscovery cost;
expected continuation cost;
optimal handoff size;
which command output reductions are safe;
which signals best predict loops;
which handoff fields are routinely reused.
Hierarchical calibration

Use this precedence:

global defaults;
model-specific calibration;
repository-specific calibration;
task-type calibration;
user-specific behavior.

Sparse categories should inherit higher-level defaults rather than overfitting.

Candidate outcome measures
total tokens to completed milestone;
elapsed time;
number of model calls;
human intervention;
tests passing;
correctness;
repeated work;
files reread;
omitted evidence requested;
regression or rollback;
user acceptance of recommendation;
handoff success.
Policy promotion

A proposed parameter change should:

be calculated offline or in shadow mode;
show the historical sessions it would have affected;
compare outcomes;
include confidence and sample count;
be approved before becoming active, at least in early versions;
remain reversible.

Avoid reinforcement based only on lower token totals.

Phase 11: Forensic analysis tools

Preserve and productize the existing one-day analyzer concept.

Required analyses
daily usage summary;
top threads;
top calls;
cached versus new input;
context timeline;
compaction effectiveness;
top commands by output;
repeated commands;
repeated file reads;
suspected loops;
thread lifecycle simulation;
handoff policy simulation;
RTK reduction simulation;
cross-thread duplication.
Reports

Produce machine-readable JSON plus human-readable Markdown and CSV exports.

Use deterministic scripts for large-data analysis. Models may explain compact outputs but should not ingest entire rollout logs.

Phase 12: Testing strategy
Unit tests

Cover:

JSONL incremental parsing;
duplicate token-event handling;
malformed event recovery;
token delta calculation;
command normalization;
event attribution;
compaction detection;
threshold policy evaluation;
handoff prioritization;
schema migration;
artifact retrieval.
Fixture tests

Create sanitized fixtures representing:

normal short thread;
long high-context thread;
repeated tool output;
compaction that succeeds;
compaction that fails to reduce context;
duplicated telemetry;
repeated commands;
interrupted command;
multiple threads in one terminal workspace;
handoff to a fresh thread.
Replay tests

Allow recorded event streams to be replayed through new policy versions. This is necessary for validating evolving thresholds.

Integration tests

Test:

live Codex session detection;
token telemetry ingestion;
terminal command capture;
UI updates;
handoff generation;
new thread creation;
worktree preservation;
raw artifact recovery.
Regression requirements

No feature may:

corrupt Codex rollout files;
modify raw session history;
leak full logs into prompts;
break interactive terminal behavior;
silently omit output without a recovery path;
misassociate work from different repositories or worktrees.
Phase 13: Privacy, retention, and security

This system will collect sensitive development data.

Implement:

local-only operation by default;
clear storage locations;
configurable retention;
secure deletion;
content hashing;
repository exclusions;
redaction hooks;
no automatic external telemetry;
visible indication when capture is active;
ability to disable content capture while preserving aggregate metrics;
explicit export controls.

Separate:

usage metrics;
source-code content;
command output;
model conversation content.

Allow different retention policies for each.

Suggested implementation order

Do not attempt all phases simultaneously.

Milestone 1: Discovery and schemas

Deliver:

architecture inventory;
integration map;
canonical event and domain schemas;
implementation plan grounded in the real repository.
Milestone 2: Read-only telemetry

Deliver:

incremental Codex rollout ingestion;
thread and call token timelines;
local persistence;
forensic reports;
no intervention.
Milestone 3: Attribution

Deliver:

terminal command capture;
command-output artifacts;
model-call correlation;
command-category reporting.
Milestone 4: Coordination UI

Deliver:

fleet view;
thread details;
token/context timelines;
warning explanations;
raw evidence links.
Milestone 5: Structured project model

Deliver:

work items;
contributions;
decisions;
discoveries;
invariants;
validation state;
incremental Build Story.
Milestone 6: Shadow lifecycle engine

Deliver:

heuristic signals;
handoff-point simulation;
policy-version logging;
no automatic interruption.
Milestone 7: Assisted handoffs

Deliver:

handoff generation;
preview and editing;
new-thread launch;
post-handoff evaluation.
Milestone 8: RTK/output reduction experiment

Deliver:

command-aware output reducer;
raw evidence preservation;
opt-in operation;
measured reduction and correctness impact.
Milestone 9: Adaptive calibration

Deliver:

replay framework;
policy comparisons;
repository/task-specific recommendations;
manual policy promotion.
Immediate first assignment

Start with repository discovery only.

Perform the following:

Inspect the entire Bmux repository structure.
Find every existing subsystem relevant to:
Codex sessions;
terminal capture;
PTY and process execution;
workspaces;
tabs and windows;
worktrees;
session persistence;
reports;
provenance;
terminal-output parsing;
summarization;
old-session search;
RTK;
SQLite or other persistence;
analytics.
Search planning documents and unfinished implementations.
Identify where our previous Bmux work already supports this roadmap.
Identify the smallest coherent vertical slice.
Write:
docs/context-efficiency/current-architecture.md
docs/context-efficiency/proposed-integration.md
docs/context-efficiency/domain-model.md
docs/context-efficiency/milestones.md
Do not begin broad implementation until those documents exist.
You may create small investigative scripts or tests where necessary to verify assumptions.
Clearly mark:
confirmed behavior;
inferred behavior;
unknowns;
architectural risks;
decisions that require user input.
End with a proposed Milestone 2 implementation plan listing exact files expected to change.
Working behavior expected from Codex

While working:

narrate the current phase and intent;
explain why each inspected subsystem matters;
avoid dumping raw command output;
summarize search results and link them to conclusions;
update the plan when repository evidence contradicts assumptions;
preserve local patterns and conventions;
avoid opportunistic unrelated refactors;
make small, reviewable commits;
run focused tests after each vertical slice;
keep a running decision log;
record unresolved questions instead of guessing;
explicitly distinguish completed work from proposed work.

The final result should not be a collection of disconnected analytics features. It should become one coherent Bmux capability:

Observe agent work, preserve its evidence and knowledge, explain its cost, detect when its current thread has become inefficient, and safely continue the work in a better context.
