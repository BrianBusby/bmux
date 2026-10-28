import type { ObservedMessage, ObservedTurn } from "./terminalChat";

export type ReportedStep = { id?: string; text: string; status: string };
export type ReportedPlan = { steps: ReportedStep[]; source: "codex" | "claude"; explanation?: string; messageId: string; timestamp?: string };
export type TurnProgressSnapshot = {
  plan?: ReportedPlan;
  plans: ReportedPlan[];
  activity: ObservedMessage[];
  timeline: ObservedMessage[];
  startedAt?: string;
  state: ObservedTurn["state"] | "unknown" | "ended";
  partial: boolean;
  stale: boolean;
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function reportedPlan(message: ObservedMessage): ReportedPlan | undefined {
  const { kind } = message;
  if (kind.type !== "tool_use" || typeof kind.input_detail !== "string") return undefined;
  const source = kind.tool_name === "update_plan" ? "codex" : kind.tool_name === "TodoWrite" ? "claude" : undefined;
  if (!source) return undefined;
  let input: unknown;
  try { input = JSON.parse(kind.input_detail); } catch { return undefined; }
  if (!isRecord(input)) return undefined;
  const raw = source === "codex" ? input.plan : input.todos;
  if (!Array.isArray(raw)) return undefined;
  const steps = raw.flatMap((item): ReportedStep[] => {
    if (!isRecord(item)) return [];
    const text = source === "codex" ? item.step : item.content;
    if (typeof text !== "string" || !text.trim()) return [];
    return [{ id: typeof item.id === "string" ? item.id : undefined, text, status: typeof item.status === "string" ? item.status : "unknown" }];
  });
  return {
    source, steps, messageId: message.id, timestamp: message.timestamp,
    explanation: typeof input.explanation === "string" ? input.explanation : undefined,
  };
}

export function latestUserPromptIndex(messages: ObservedMessage[]): number {
  for (let index = messages.length - 1; index >= 0; index--) {
    if (messages[index]?.role === "user" && messages[index]?.kind.type === "prose") return index;
  }
  return -1;
}

export function currentTurnProgress(messages: ObservedMessage[], observedTurn: ObservedTurn | undefined, partial: boolean): TurnProgressSnapshot | undefined {
  return turnProgressReports(messages, observedTurn, partial).at(-1)?.progress;
}

export function turnProgressReports(messages: ObservedMessage[], observedTurn: ObservedTurn | undefined, _partial: boolean): { promptIndex: number; endIndex: number; progress: TurnProgressSnapshot }[] {
  const prompts = messages.flatMap((message, index) => message.role === "user" && message.kind.type === "prose" ? [index] : []);
  return prompts.map((promptIndex, position) => {
    const nextPrompt = prompts[position + 1];
    const turn = messages.slice(promptIndex + 1, nextPrompt);
    const plans = turn.map(reportedPlan).filter((plan): plan is ReportedPlan => plan !== undefined);
    const activity = turn.filter(message => ["terminal", "tool_use", "file_edit", "permission_request", "question"].includes(message.kind.type) && !reportedPlan(message));
    const timeline = turn.filter(message => message.kind.type !== "thought" && (message.kind.type !== "status" || message.kind.event === "interrupted"));
    const interrupted = timeline.some(message => message.kind.type === "status" && message.kind.event === "interrupted");
    const state = nextPrompt === undefined ? observedTurn?.state ?? "unknown" : interrupted ? "interrupted" : "ended";
    const latestPlan = plans.at(-1);
    const interruptionIndex = turn.map(message => message.kind.type === "status" && message.kind.event === "interrupted").lastIndexOf(true);
    const planIndex = latestPlan ? turn.findIndex(message => message.id === latestPlan.messageId) : -1;
    const stale = state === "working" && planIndex >= 0 && interruptionIndex > planIndex
      && turn.slice(interruptionIndex + 1).some(message => message.kind.type !== "status");
    return { promptIndex, endIndex: (nextPrompt ?? messages.length) - 1, progress: { plan: latestPlan, plans, activity, timeline, startedAt: messages[promptIndex]?.timestamp, state, partial: false, stale } };
  });
}

export function reportedStepState(status: string): "done" | "active" | "upcoming" | "blocked" | "skipped" | "unknown" {
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

/** Only adjacent read, search, or list tools can share one Activity row. */
export function chronologicalActivity(timeline: ObservedMessage[]): ObservedMessage[][] {
  const groups: ObservedMessage[][] = [];
  for (const message of timeline) {
    const previous = groups.at(-1);
    if (isReadOnly(message) && previous?.every(isReadOnly)) previous.push(message);
    else groups.push([message]);
  }
  return groups;
}

function isReadOnly(message: ObservedMessage): boolean {
  const { kind } = message;
  if (kind.type !== "terminal" && kind.type !== "tool_use") return false;
  const command = (kind.command ?? kind.tool_name ?? "").trim().toLowerCase();
  return /^(cat|sed|rg|grep|ls|find|read|search|list|open)(\s|$)/.test(command);
}

/** A status is never inferred from order or from the number of plan steps. */
export function visibleStepIndexes(steps: ReportedStep[]): number[] {
  if (steps.length <= 7) return steps.map((_, index) => index);
  const active = steps.flatMap((step, index) => reportedStepState(step.status) === "active" ? [index] : []);
  const first = active[0] ?? steps.findIndex(step => reportedStepState(step.status) !== "done");
  const anchor = first < 0 ? steps.length - 1 : first;
  const start = Math.max(0, anchor - 1);
  const end = Math.min(steps.length, (active.at(-1) ?? anchor) + 3);
  return steps.flatMap((_, index) => index >= start && index < end ? [index] : []);
}

/** Counts only defensible changes; duplicate text never gets a claimed identity. */
export function planChangeCounts(before: ReportedPlan, after: ReportedPlan): { added: number; removed: number; textChanged: number } {
  const withIDs = [...before.steps, ...after.steps].every(step => step.id !== undefined)
    && new Set(before.steps.map(step => step.id)).size === before.steps.length
    && new Set(after.steps.map(step => step.id)).size === after.steps.length;
  if (withIDs) {
    const prior = new Map(before.steps.map(step => [step.id, step]));
    const next = new Map(after.steps.map(step => [step.id, step]));
    return {
      added: after.steps.filter(step => !prior.has(step.id)).length,
      removed: before.steps.filter(step => !next.has(step.id)).length,
      textChanged: after.steps.filter(step => prior.has(step.id) && prior.get(step.id)?.text !== step.text).length,
    };
  }
  const count = (steps: ReportedStep[]) => {
    const values = new Map<string, number>();
    for (const step of steps) {
      const text = step.text.trim().replace(/\s+/g, " ").toLocaleLowerCase();
      values.set(text, (values.get(text) ?? 0) + 1);
    }
    return values;
  };
  const prior = count(before.steps);
  const next = count(after.steps);
  return {
    added: [...next].reduce((total, [text, quantity]) => total + Math.max(0, quantity - (prior.get(text) ?? 0)), 0),
    removed: [...prior].reduce((total, [text, quantity]) => total + Math.max(0, quantity - (next.get(text) ?? 0)), 0),
    textChanged: 0,
  };
}
