import type { Block } from "./session";

export type PlanBlock = Extract<Block, { kind: "plan" }>;
export type PlanStep = PlanBlock["steps"][number];
export type StepState = "done" | "active" | "upcoming" | "blocked" | "skipped" | "unknown";

export function stepState(status: string): StepState {
  switch (status) {
    case "completed": return "done";
    case "in_progress":
    case "inProgress": return "active";
    case "pending": return "upcoming";
    case "blocked": return "blocked";
    case "skipped": return "skipped";
    default: return "unknown";
  }
}

function normalized(text: string): string {
  return text.trim().replace(/\s+/g, " ").toLocaleLowerCase();
}

export type PlanChange = { kind: "added" | "removed" | "reopened" | "moved" | "text changed"; text: string };

// Duplicate text can identify an occurrence for display, but cannot establish
// which occurrence changed after an insertion or reorder.
export function planChanges(previous: PlanBlock, latest: PlanBlock): PlanChange[] {
  const old = previous.steps;
  const next = latest.steps;
  const allIds = [...old, ...next].every((step) => Boolean(step.id));
  const key = (step: PlanStep) => allIds && step.id ? step.id : normalized(step.text);
  const oldCounts = new Map<string, number>();
  const newCounts = new Map<string, number>();
  for (const step of old) oldCounts.set(key(step), (oldCounts.get(key(step)) ?? 0) + 1);
  for (const step of next) newCounts.set(key(step), (newCounts.get(key(step)) ?? 0) + 1);
  const oldBuckets = new Map<string, number[]>();
  old.forEach((step, index) => oldBuckets.set(key(step), [...(oldBuckets.get(key(step)) ?? []), index]));
  const matched = new Set<number>();
  const changes: PlanChange[] = [];
  next.forEach((step, index) => {
    const identity = key(step);
    const prior = oldBuckets.get(identity)?.shift();
    if (prior === undefined) {
      changes.push({ kind: "added", text: step.text });
      return;
    }
    matched.add(prior);
    const unambiguous = oldCounts.get(identity) === 1 && newCounts.get(identity) === 1;
    if (allIds && old[prior].text !== step.text) changes.push({ kind: "text changed", text: step.text });
    if (unambiguous) {
      if (stepState(old[prior].status) === "done" && ["active", "upcoming"].includes(stepState(step.status))) {
        changes.push({ kind: "reopened", text: step.text });
      }
      if (prior !== index) changes.push({ kind: "moved", text: step.text });
    }
  });
  old.forEach((step, index) => {
    if (!matched.has(index)) changes.push({ kind: "removed", text: step.text });
  });
  return changes;
}
