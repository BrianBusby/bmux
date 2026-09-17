import { describe, expect, test } from "bun:test";
import { canUseConnectedControl } from "./connectedChat";

describe("connected session authority", () => {
  test("only the bound live provider connection can enable actions", () => {
    const control = { threadId: "original-thread", status: "connected" as const, queueFollowUp: true };
    expect(canUseConnectedControl(control, "original-thread")).toBe(true);
    expect(canUseConnectedControl(control, "another-thread")).toBe(false);
    expect(canUseConnectedControl(undefined, "original-thread")).toBe(false);
    expect(canUseConnectedControl({ ...control, status: "unavailable" }, "original-thread")).toBe(false);
  });
});

test("history availability and native connection authority are independent", async () => {
  const { reconcileTerminalChat, initialTerminalChat } = await import("./terminalChat");
  const scope = { workspaceId: "workspace-a", panelId: "surface-a" };
  const snapshot = { status: "unavailable" as const, reason: "historyUnavailable" as const,
    workspaceId: scope.workspaceId, surfaceId: scope.panelId, sessionId: "thread-a",
    control: { threadId: "thread-a", status: "connected" as const, queueFollowUp: true } };
  const connected = reconcileTerminalChat(initialTerminalChat, snapshot, scope);
  expect(connected.status).toBe("unavailable");
  expect(connected.messages).toEqual([]);
  expect(canUseConnectedControl(connected.control, connected.sessionId)).toBe(true);
  const wrongWorkspace = reconcileTerminalChat(initialTerminalChat, snapshot, { ...scope, workspaceId: "workspace-b" });
  expect(canUseConnectedControl(wrongWorkspace.control, wrongWorkspace.sessionId)).toBe(false);
  const lost = reconcileTerminalChat(connected, { status: "unavailable" }, scope);
  expect(canUseConnectedControl(lost.control, lost.sessionId)).toBe(false);
});
