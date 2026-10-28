import { expect, test } from "bun:test";
import { currentTurnProgress, reportedStepState } from "./terminalTurnProgress";
import type { ObservedMessage } from "./terminalChat";

const prompt = (seq: number): ObservedMessage => ({ id: `prompt-${seq}`, seq, role: "user", kind: { type: "prose", text: "Review" } });
const plan = (seq: number, steps: unknown[]): ObservedMessage => ({ id: `plan-${seq}`, seq, role: "agent", kind: { type: "tool_use", tool_name: "update_plan", input_detail: JSON.stringify({ plan: steps }) } });

test("latest reported plan wins without inferring duplicate step history", () => {
  const progress = currentTurnProgress([
    prompt(1), plan(2, [{ step: "Check", status: "completed" }, { step: "Check", status: "pending" }]),
    plan(3, [{ step: "Check", status: "pending" }, { step: "Check", status: "completed" }]),
  ], { id: "turn", state: "working" }, false);
  expect(progress?.plan?.steps.map(step => step.status)).toEqual(["pending", "completed"]);
  expect(progress?.activity).toEqual([]);
  expect(reportedStepState("provider_paused")).toBe("unknown");
});

test("the latest user prompt bounds current activity and preserves no-plan state", () => {
  const previous: ObservedMessage = { id: "old", seq: 2, role: "agent", kind: { type: "terminal", command: "old command", status: "failed" } };
  const current: ObservedMessage = { id: "current", seq: 4, role: "agent", kind: { type: "terminal", command: "new command", is_running: true } };
  const progress = currentTurnProgress([prompt(1), previous, prompt(3), current], { id: "turn", state: "working" }, false);
  expect(progress?.plan).toBeUndefined();
  expect(progress?.activity.map(message => message.id)).toEqual(["current"]);
});
