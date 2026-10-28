import type { ObservedMessage, ObservedTurn } from "./terminalChat";

export type ReportedStep = { text: string; status: string };
export type ReportedPlan = { steps: ReportedStep[]; source: "codex" | "claude"; explanation?: string; messageId: string; timestamp?: string };
export type TurnProgressSnapshot = {
  plan?: ReportedPlan;
  plans: ReportedPlan[];
  activity: ObservedMessage[];
  timeline: ObservedMessage[];
  startedAt?: string;
  state: ObservedTurn["state"] | "unknown";
  partial: boolean;
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
    return [{ text, status: typeof item.status === "string" ? item.status : "unknown" }];
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
  const promptIndex = latestUserPromptIndex(messages);
  if (promptIndex < 0) return undefined;
  const turn = messages.slice(promptIndex + 1);
  const plans = turn.map(reportedPlan).filter((plan): plan is ReportedPlan => plan !== undefined);
  const activity = turn.filter(message => ["terminal", "tool_use", "file_edit", "permission_request", "question"].includes(message.kind.type) && !reportedPlan(message));
  const timeline = turn.filter(message => message.kind.type !== "thought" && (message.kind.type !== "status" || message.kind.event === "interrupted"));
  return { plan: plans.at(-1), plans, activity, timeline, startedAt: messages[promptIndex]?.timestamp, state: observedTurn?.state ?? "unknown", partial };
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
