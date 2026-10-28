import type { ObservedMessage, ObservedTurn } from "./terminalChat";

export type ReportedStep = { text: string; status: string };
export type TurnProgressSnapshot = {
  plan?: { steps: ReportedStep[]; source: "codex" | "claude" };
  activity: ObservedMessage[];
  state: ObservedTurn["state"] | "unknown";
  partial: boolean;
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function reportedPlan(message: ObservedMessage): TurnProgressSnapshot["plan"] {
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
  return { source, steps };
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
  const plans = turn.map(reportedPlan).filter((plan): plan is NonNullable<TurnProgressSnapshot["plan"]> => plan !== undefined);
  const activity = turn.filter(message => ["terminal", "tool_use", "file_edit", "permission_request", "question"].includes(message.kind.type) && !reportedPlan(message));
  return { plan: plans.at(-1), activity, state: observedTurn?.state ?? "unknown", partial };
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
