import { describe, expect, test } from "bun:test";
import { initialTerminalChat, reconcileTerminalChat, terminalCapabilities, type TerminalChatSnapshot } from "./terminalChat";
const scope = { workspaceId: "workspace-a", panelId: "surface-a" };
const snapshot: TerminalChatSnapshot = { status: "observed", sessionId: "thread-a", workspaceId: scope.workspaceId, surfaceId: scope.panelId,
  history: { has_more: false, messages: [{ id: "tool-a", seq: 2, role: "agent", kind: { type: "terminal", command: "sleep 1", is_running: true } }, { id: "prompt-a", seq: 1, role: "user", kind: { type: "prose", text: "Hello" } }] } };
describe("ordinary CLI Chat contract", () => {
  test("transcript availability never enables control", () => {
    for (const available of [true, false]) {
      const capabilities = terminalCapabilities(available);
      expect(capabilities.readConversation.available).toBe(available);
      for (const [operation, capability] of Object.entries(capabilities)) {
        if (operation !== "readConversation") expect(capability).toEqual({ available: false, reason: "noAttachedControlTransport" });
      }
    }
  });
  test("replayed history is chronological and does not duplicate", () => {
    const first = reconcileTerminalChat(initialTerminalChat, snapshot, scope);
    expect(first.messages.map(m => m.id)).toEqual(["prompt-a", "tool-a"]);
    expect(reconcileTerminalChat(first, snapshot, scope)).toEqual(first);
  });
  test("late results replace the same activity and reset removes old rows", () => {
    const first = reconcileTerminalChat(initialTerminalChat, snapshot, scope);
    const completed = { ...snapshot, history: { has_more: false, messages: [{ ...first.messages[1]!, kind: { type: "terminal", output: "done", exit_code: 0 } }] } };
    const next = reconcileTerminalChat(first, completed, scope);
    expect(next.messages).toHaveLength(1);
    expect(next.messages[0]!.kind.output).toBe("done");
    expect(reconcileTerminalChat(next, { ...snapshot, history: { has_more: false, messages: [] } }, scope).messages).toEqual([]);
  });
  test("cross-workspace or cross-surface data is rejected", () => {
    for (const override of [{ workspaceId: "other" }, { surfaceId: "other" }]) {
      const result = reconcileTerminalChat(initialTerminalChat, { ...snapshot, ...override }, scope);
      expect(result.status).toBe("unavailable");
      expect(result.messages).toEqual([]);
    }
  });
  test("failed reads preserve cached content but never label it current", () => {
    const first = reconcileTerminalChat(initialTerminalChat, snapshot, scope);
    const failed = reconcileTerminalChat(first, { status: "unavailable" }, scope);
    expect(failed.status).toBe("stale");
    expect(failed.messages).toEqual(first.messages);
    expect(failed.messages[1]!.kind.is_running).toBe(true);
  });
  test("ambiguous replacement cannot present the previous session as selected", () => {
    const first = reconcileTerminalChat(initialTerminalChat, snapshot, scope);
    const result = reconcileTerminalChat(first, { status: "unavailable", reason: "ambiguous" }, scope);
    expect(result.messages).toEqual([]);
    expect(result.reason).toBe("ambiguous");
    expect(result.status).toBe("unavailable");
  });
  test("only provider turn state supplies lifecycle, and failed refresh is stale", () => {
    const observed = { ...snapshot, history: { ...snapshot.history!, observed_turn: { id: "turn-a", state: "working" as const } } };
    const first = reconcileTerminalChat(initialTerminalChat, observed, scope);
    expect(first.observedTurn?.state).toBe("working");
    expect(reconcileTerminalChat(first, observed, scope).observedTurn?.state).toBe("working");
    expect(reconcileTerminalChat(first, { status: "unavailable" }, scope).status).toBe("stale");
    expect(reconcileTerminalChat(first, snapshot, scope).observedTurn).toBeUndefined();
  });
  test("large history is bounded and explicitly partial", () => {
    const messages = Array.from({ length: 800 }, (_, seq) => ({ id: String(seq), seq, role: "user", kind: { type: "prose", text: "hello" } }));
    const result = reconcileTerminalChat(initialTerminalChat, { ...snapshot, history: { has_more: false, messages } }, scope);
    expect(result.messages).toHaveLength(500);
    expect(result.partial).toBe(true);
    expect(result.messages[0]!.seq).toBe(300);
  });
});
