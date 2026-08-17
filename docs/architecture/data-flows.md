# Data Flows

## Coding-Agent Session Flow

```mermaid
flowchart TD
  provider["EXTERNAL: provider structured event"] --> adapter["CURRENT: bmux provider adapter"]
  adapter --> telemetry["CURRENT: normalized telemetry"]
  telemetry --> producer["CURRENT: bmux evidence producer"]
  producer --> evidence["CURRENT: PE evidence"]
  evidence --> factual["CURRENT: factual session projection"]
  factual --> sem["CURRENT: semantic inference"]
  sem --> messages["CURRENT: semantic messages"]
  messages --> swm["PLANNED: SessionWorkModel"]
  factual --> session["ACTIVE/PLANNED: React Session UI"]
  swm --> session
```

Evidence is what was accepted as observed. Factual projection is a deterministic,
rebuildable organization of those facts. Semantic inference is what those facts
appear to mean. Semantic messages are human-readable wording for that meaning.
A wrong inference and poor wording are different defect classes.

## Workspace Context Flow

```mermaid
flowchart TD
  observe["CURRENT: bmux observes workspace/repository state"] --> accepted["CURRENT: PE accepted workspace evidence"]
  accepted --> current["CURRENT: PE Current State"]
  current --> snapshot["CURRENT: bmux WorkspaceDisplayCurrentStateSnapshot"]
  snapshot --> presentation["CURRENT: tab/sidebar presentation"]
  presentation --> refresh["CURRENT: explicit refresh/observation triggers"]
  refresh --> observe
```

bmux owns observation and presentation. PE owns accepted evidence and deterministic
Current State. Missing observations do not clear known state; explicit clear
evidence is required.

## Knowledge Flow Target

```mermaid
flowchart TD
  evidence["CURRENT: evidence"] --> compiler["PLANNED: Knowledge Compiler"]
  compiler --> compiled["PLANNED: compiled engineering knowledge"]
  compiled --> store["PLANNED: Knowledge Store"]
  store --> retrieval["PLANNED: retrieval"]
  retrieval --> agent["PLANNED: future agent context"]
```

Session understanding explains active work. The Knowledge Compiler creates
durable engineering knowledge intended to survive the session and support later
retrieval. These are related, but not the same layer.

## Project Truth Flow

```mermaid
flowchart TD
  graph["CURRENT: canonical Project Truth\nproject/project-state.yaml + repo-status.yaml"] --> validate["CURRENT: validation and dependency readiness"]
  validate --> execution["CURRENT: execution state and active worktree checks"]
  execution --> generated["CURRENT: generated roadmap/status docs"]
  generated --> agents["CURRENT: agent planning and developer understanding"]
  generated --> ci["CURRENT: read-only CI gate"]
```

Dependency-ready, selected-next, active, and dependency-ready-but-not-selected
remain distinct. Readiness is derived from dependency state. Selection is an
execution decision, not a mutable readiness flag.

