import { expect, test } from "bun:test";
import { chronologicalActivity, planChangeCounts, reportedStepState, turnProgressReports, visibleStepIndexes } from "../src/agent-session/shared/terminalTurnProgress";
import type { ObservedMessage } from "../src/agent-session/shared/terminalChat";

const message = (id: string, type: string, command?: string): ObservedMessage => ({ id, seq: Number(id), role: "agent", kind: { type, command } });

test("activity groups only adjacent read commands and keeps intervening conversation and approvals", () => {
  const timeline = [message("1", "terminal", "rg foo"), message("2", "terminal", "cat file"), message("3", "prose"), message("4", "permission_request"), message("5", "terminal", "ls"), message("6", "terminal", "git status")];
  expect(chronologicalActivity(timeline).map(group => group.map(item => item.id))).toEqual([["1", "2"], ["3"], ["4"], ["5"], ["6"]]);
});

test("unknown provider step status stays unknown and long plan window does not infer completion", () => {
  expect(reportedStepState("new_provider_state")).toBe("unknown");
  const steps = Array.from({ length: 11 }, (_, index) => ({ text: `Step ${index}`, status: index === 5 ? "in_progress" : "new_provider_state" }));
  expect(visibleStepIndexes(steps)).toEqual([4, 5, 6, 7]);
});

test("reports stay attached to each prompt and only the latest observed turn is active", () => {
  const messages: ObservedMessage[] = [
    { id: "p1", seq: 1, role: "user", kind: { type: "prose", text: "First" } },
    { id: "a1", seq: 2, role: "agent", kind: { type: "prose", text: "Done" } },
    { id: "p2", seq: 3, role: "user", kind: { type: "prose", text: "Second" } },
    { id: "t2", seq: 4, role: "agent", kind: { type: "terminal", command: "rg status" } },
  ];
  const reports = turnProgressReports(messages, { id: "second", state: "working" }, false);
  expect(reports.map((report: { promptIndex: number; progress: { state: string } }) => [report.promptIndex, report.progress.state])).toEqual([[0, "ended"], [2, "working"]]);
  expect(reports[0].progress.timeline.map((item: ObservedMessage) => item.id)).toEqual(["a1"]);
  expect(reports[1].progress.timeline.map((item: ObservedMessage) => item.id)).toEqual(["t2"]);
});


test("plan history counts text additions and removals without attributing duplicate identities", () => {
  const before = { source: "codex" as const, messageId: "a", steps: [{ text: "Run suite", status: "completed" }, { text: "Run suite", status: "pending" }] };
  const after = { source: "codex" as const, messageId: "b", steps: [{ text: "Run suite", status: "in_progress" }, { text: "Fix fold ordering", status: "pending" }] };
  expect(planChangeCounts(before, after)).toEqual({ added: 1, removed: 1, textChanged: 0 });
});

test("a plan is marked potentially stale only after an interruption and later observed work", () => {
  const messages: ObservedMessage[] = [
    { id: "prompt", seq: 1, role: "user", kind: { type: "prose", text: "Fix issue" } },
    { id: "plan", seq: 2, role: "agent", kind: { type: "tool_use", tool_name: "update_plan", input_detail: JSON.stringify({ plan: [{ step: "Inspect", status: "in_progress" }] }) } },
    { id: "interrupt", seq: 3, role: "agent", kind: { type: "status", event: "interrupted" } },
    { id: "tool", seq: 4, role: "agent", kind: { type: "terminal", command: "rg issue" } },
  ];
  expect(turnProgressReports(messages, { id: "turn", state: "working" }, false)[0].progress.stale).toBe(true);
  expect(turnProgressReports(messages.slice(0, 3), { id: "turn", state: "interrupted" }, false)[0].progress.stale).toBe(false);
});
