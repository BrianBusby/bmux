import { expect, test } from "bun:test";
import { chronologicalActivity, reportedStepState, visibleStepIndexes } from "../src/agent-session/shared/terminalTurnProgress";
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
