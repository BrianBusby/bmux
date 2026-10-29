import { test, expect } from "bun:test";
import { planChanges, stepState } from "../src/plan";
import type { Block } from "../src/session";

const plan = (steps: Extract<Block, { kind: "plan" }>["steps"]): Extract<Block, { kind: "plan" }> =>
  ({ kind: "plan", source: "codex-plan", at: 1, steps });

test("unrecognized status remains unknown", () => {
  expect(stepState("provider_paused")).toBe("unknown");
  expect(stepState("pending")).toBe("upcoming");
});

test("duplicate text does not assert a reopen or move after insertion", () => {
  const previous = plan([{ text: "Run suite", status: "completed" }, { text: "Run suite", status: "pending" }]);
  const latest = plan([{ text: "Prepare", status: "completed" }, { text: "Run suite", status: "pending" }, { text: "Run suite", status: "completed" }]);
  expect(planChanges(previous, latest)).toEqual([{ kind: "added", text: "Prepare" }]);
  expect(latest.steps).toHaveLength(3);
});

test("same-position replacement is added and removed", () => {
  expect(planChanges(plan([{ text: "Run suite", status: "pending" }]), plan([{ text: "Fix failure", status: "pending" }]))).toEqual([
    { kind: "added", text: "Fix failure" }, { kind: "removed", text: "Run suite" },
  ]);
});

import { projectTelemetryEnvelopeToAgentEvents } from "../executionTelemetryFanout";
import { groupTurns } from "../src/turns";

test("Codex plan projection preserves transcript chronology", async () => {
  Object.defineProperty(globalThis, "location", { configurable: true, value: { pathname: "/" } });
  const { foldEvent } = await import("../src/session");
  const events = projectTelemetryEnvelopeToAgentEvents({
    schema: "bmux.execution-event.v1", eventId: "e1", sessionId: "s1", sequence: 1,
    capturedAtMs: 2, source: "provider", provider: "codex",
    event: { type: "plan.updated", steps: [{ text: "Inspect", status: "inProgress" }] },
  });
  expect(events[0]?.kind).toBe("plan");
  const blocks = [
    { kind: "user" as const, text: "Fix it" }, ...events,
    { kind: "assistant" as const, text: "I found it" },
    { kind: "tool-start" as const, toolId: "t", name: "rg" },
    { kind: "tool-end" as const, toolId: "t", ok: false },
    { kind: "error" as const, message: "Command failed" },
    { kind: "assistant" as const, text: "Still working" },
  ].reduce(foldEvent, [] as Block[]);
  const turn = groupTurns(blocks, "running")[0];
  expect(turn.activity.map((block) => block.kind)).toEqual(["plan", "assistant", "tool", "error"]);
  expect(turn.assistant?.text).toBe("Still working");
  expect(turn.assistantPosition).toBe(turn.activity.length);
  expect(turn.activity.find((block) => block.kind === "tool")).toMatchObject({ status: "fail" });
});

import { groupConsecutiveReads } from "../src/turns";

test("read grouping stops at assistant, approval-like status, and error markers", () => {
  const entries = groupConsecutiveReads([
    { kind: "tool", toolId: "a", name: "cat", detail: "a", status: "ok" },
    { kind: "tool", toolId: "b", name: "rg", detail: "b", status: "ok" },
    { kind: "assistant", text: "Checking", open: false },
    { kind: "tool", toolId: "c", name: "ls", detail: "c", status: "ok" },
    { kind: "status", text: "Approval requested" },
    { kind: "tool", toolId: "d", name: "cat", detail: "d", status: "ok" },
    { kind: "error", text: "Failed" },
  ]);
  expect(entries.map((entry) => entry.blocks.length)).toEqual([2, 1, 1, 1, 1, 1]);
  expect(entries.map((entry) => entry.start)).toEqual([0, 2, 3, 4, 5, 6]);
});

test("rendered progress keeps unknown raw status and failed command separate", async () => {
  Object.defineProperty(globalThis, "navigator", { configurable: true, value: { language: "en-US" } });
  const { createElement } = await import("react");
  const { renderToStaticMarkup } = await import("react-dom/server");
  const { TurnProgress } = await import("../src/components/TurnProgress");
  const group = groupTurns([
    { kind: "user", text: "Fix it" },
    plan([{ text: "Wait for provider", status: "provider_paused" }]),
    { kind: "tool", toolId: "failed", name: "bun test", status: "fail" },
  ], "running")[0];
  const html = renderToStaticMarkup(createElement(TurnProgress, { group }));
  expect(html).toContain("Unknown: provider_paused");
  expect(html).toContain("Current activity");
  expect(html).not.toContain("waiting for you");
  expect(html).not.toContain("Upcoming: Wait for provider");
  expect(html).not.toContain("Blocked: Wait for provider");
});


test("assistant message keeps its chronology when tools follow it", () => {
  const turn = groupTurns([
    { kind: "user", text: "Fix it" },
    { kind: "assistant", text: "I found it", open: false },
    { kind: "tool", toolId: "a", name: "rg", status: "ok" },
    { kind: "approval", approvalId: "p", state: "requested" },
  ], "running")[0];
  expect(turn.assistantPosition).toBe(0);
  expect(turn.activity.map((block) => block.kind)).toEqual(["tool", "approval"]);
});
