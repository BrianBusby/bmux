import { expect, test } from "bun:test";
import { JSDOM } from "jsdom";
import { act } from "react";
import { createRoot } from "react-dom/client";
import { TerminalChatSurface } from "../src/agent-session/react/TerminalChatSurface";
import type { AgentSessionCopy, AppContext } from "../src/agent-session/shared/types";

test("read-only Chat renders authoritative content without terminal action buttons", async () => {
  const dom = new JSDOM("<!doctype html><div id='root'></div>", { url: "https://example.test" });
  const previousWindow = globalThis.window;
  const previousDocument = globalThis.document;
  Object.assign(globalThis, { window: dom.window, document: dom.window.document, IS_REACT_ACT_ENVIRONMENT: true });
  const calls: string[] = [];
  let sourceRevision = "original";
  Object.assign(dom.window, { webkit: { messageHandlers: { agentSession: { postMessage: async (request: { method: string }) => {
    calls.push(request.method);
    return { ok: true, value: { status: "observed", sessionId: "thread", workspaceId: "workspace", surfaceId: "surface",
      history: { has_more: false, source_revision: sourceRevision, messages: [
        { id: "prompt", seq: 1, role: "user", kind: { type: "prose", text: "Review the roof inspection" } },
        { id: "answer", seq: 2, role: "agent", kind: { type: "prose", text: "<script>unsafe()</script> Ready" } },
        { id: "tool", seq: 3, role: "agent", kind: { type: "terminal", command: "cat report.txt", output: "Inspection complete\n".repeat(1000), exit_code: 0 } },
      ] } } };
  } } } } });
  const copy = { showMore: "Show more", chatInteract: "Interact in Terminal", chatReadOnly: "Read-only", chatObserved: "Transcript updates", chatCompleted: "Completed", chatConversation: "Conversation", chatUser: "You", chatAssistant: "Assistant" } as AgentSessionCopy;
  const context = { workspaceId: "workspace", panelId: "surface", copy } as AppContext;
  const root = createRoot(dom.window.document.getElementById("root")!);
  try {
    await act(async () => root.render(<TerminalChatSurface context={context} />));
    expect(dom.window.document.body.textContent).toContain("Review the roof inspection");
    expect(dom.window.document.querySelector("script")).toBeNull();
    expect(dom.window.document.querySelector("textarea,input,[contenteditable=true]")).toBeNull();
    expect(dom.window.document.querySelector("details summary")?.textContent).toContain("Completed");
    expect(calls).toEqual(["terminalChat.snapshot"]);
    expect(dom.window.document.querySelector("pre")?.textContent?.length).toBe(8192);
    const more = [...dom.window.document.querySelectorAll("button")].find(button => button.textContent === "Show more")!;
    await act(async () => more.click());
    expect(dom.window.document.querySelector("pre")?.textContent?.length).toBe(20000);
    await act(async () => root.render(<TerminalChatSurface context={{ ...context }} />));
    expect(dom.window.document.querySelector("pre")?.textContent?.length).toBe(20000);
    sourceRevision = "replacement";
    await act(async () => root.render(<TerminalChatSurface context={{ ...context }} />));
    expect(dom.window.document.querySelector("pre")?.textContent?.length).toBe(8192);
    expect(dom.window.document.querySelectorAll("details")).toHaveLength(1);
    expect([...dom.window.document.querySelectorAll("button")].some(button => button.textContent === "Interact in Terminal")).toBe(false);
    expect(calls).toEqual(["terminalChat.snapshot", "terminalChat.snapshot", "terminalChat.snapshot"]);
  } finally {
    await act(async () => root.unmount());
    dom.window.close();
    Object.assign(globalThis, { window: previousWindow, document: previousDocument, IS_REACT_ACT_ENVIRONMENT: false });
  }
});


test("configured startup shows loading without offering a second launch", async () => {
  const dom = new JSDOM("<!doctype html><div id='root'></div>", { url: "https://example.test" });
  const previousWindow = globalThis.window;
  const previousDocument = globalThis.document;
  Object.assign(globalThis, { window: dom.window, document: dom.window.document, IS_REACT_ACT_ENVIRONMENT: true });
  const calls: string[] = [];
  Object.assign(dom.window, { webkit: { messageHandlers: { agentSession: { postMessage: async (request: { method: string }) => {
    calls.push(request.method);
    return { ok: true, value: { status: "loading" } };
  } } } } });
  const copy = { chatLoading: "Loading conversation", chatReadOnly: "Read-only", connectedNewSession: "New connected session" } as AgentSessionCopy;
  const context = { workspaceId: "workspace", panelId: "surface", canStartConnectedSession: true,
    automaticallyStartConnectedSession: false, copy } as AppContext;
  const root = createRoot(dom.window.document.getElementById("root")!);
  try {
    await act(async () => root.render(<TerminalChatSurface context={context} />));
    expect(dom.window.document.querySelector(".terminal-chat-footer")?.textContent).toBe("Loading conversation");
    expect(dom.window.document.querySelector(".terminal-chat-launch")).toBeNull();
    expect(calls).toEqual(["terminalChat.snapshot"]);
  } finally {
    await act(async () => root.unmount());
    dom.window.close();
    Object.assign(globalThis, { window: previousWindow, document: previousDocument, IS_REACT_ACT_ENVIRONMENT: false });
  }
});

const connectedSnapshot = {
  status: "unavailable", reason: "historyUnavailable", sessionId: "thread",
  workspaceId: "workspace", surfaceId: "surface",
  control: { status: "connected", threadId: "thread", queueFollowUp: true },
} satisfies import("../src/agent-session/shared/terminalChat").TerminalChatSnapshot;
const emptyHistory = { messages: [], has_more: false };

test.each([
  { name: "connected before history exists", snapshot: connectedSnapshot, expected: "Connected to Codex" },
  { name: "connected before transcript association", snapshot: { ...connectedSnapshot, reason: "unassociated" }, expected: "Connected to Codex" },
  { name: "connected with empty history", snapshot: { ...connectedSnapshot, status: "observed", reason: undefined, history: emptyHistory }, expected: "Connected to Codex" },
  { name: "Japanese connected copy", snapshot: connectedSnapshot, expected: "Codex に接続済み", connectedCopy: "Codex に接続済み" },
  { name: "missing connection", snapshot: { ...connectedSnapshot, control: undefined }, expected: "Conversation unavailable" },
  { name: "failed connection", snapshot: { ...connectedSnapshot, control: { ...connectedSnapshot.control, status: "unavailable" } }, expected: "Conversation unavailable" },
  { name: "different workspace", snapshot: { ...connectedSnapshot, workspaceId: "other-workspace" }, expected: "Conversation unavailable" },
  { name: "different thread", snapshot: { ...connectedSnapshot, control: { ...connectedSnapshot.control, threadId: "other-thread" } }, expected: "Conversation unavailable" },
  { name: "ambiguous association", snapshot: { ...connectedSnapshot, reason: "ambiguous" }, expected: "Multiple session bindings" },
  { name: "completed turn", snapshot: { ...connectedSnapshot, status: "observed", history: { ...emptyHistory, observed_turn: { id: "turn", state: "completed" } } }, expected: "Completed" },
  { name: "ended session", snapshot: { ...connectedSnapshot, status: "ended", history: emptyHistory }, expected: "Session ended" },
] satisfies { name: string; snapshot: import("../src/agent-session/shared/terminalChat").TerminalChatSnapshot; expected: string; connectedCopy?: string }[])("Chat omits its status header: $name", async ({ snapshot, expected, connectedCopy }) => {
  const dom = new JSDOM("<!doctype html><div id='root'></div>", { url: "https://example.test" });
  const previousWindow = globalThis.window;
  const previousDocument = globalThis.document;
  Object.assign(globalThis, { window: dom.window, document: dom.window.document, IS_REACT_ACT_ENVIRONMENT: true });
  Object.assign(dom.window, { webkit: { messageHandlers: { agentSession: { postMessage: async () => ({ ok: true, value: snapshot }) } } } });
  const copy: AgentSessionCopy = Object.assign({ chatUnavailable: "Conversation unavailable",
    chatObserved: "Observed transcript", chatAmbiguous: "Multiple session bindings", chatEnded: "Session ended",
    chatCompleted: "Completed", chatConversation: "Conversation", connectedPrompt: "Message Codex" } as AgentSessionCopy,
    { chatConnected: connectedCopy ?? "Connected to Codex" });
  const context = { workspaceId: "workspace", panelId: "surface", copy } as AppContext;
  const root = createRoot(dom.window.document.getElementById("root")!);
  try {
    await act(async () => root.render(<TerminalChatSurface context={context} />));
    expect(dom.window.document.querySelector("header")).toBeNull();
    if (snapshot.reason === "ambiguous") {
      expect(dom.window.document.querySelector(".terminal-chat-notice")?.textContent).toBe(expected);
    } else {
      expect(dom.window.document.body.textContent).not.toContain(expected);
    }
  } finally {
    await act(async () => root.unmount());
    dom.window.close();
    Object.assign(globalThis, { window: previousWindow, document: previousDocument, IS_REACT_ACT_ENVIRONMENT: false });
  }
});

test("connected control does not hide a failed history refresh", async () => {
  const dom = new JSDOM("<!doctype html><div id='root'></div>", { url: "https://example.test" });
  const previousWindow = globalThis.window;
  const previousDocument = globalThis.document;
  Object.assign(globalThis, { window: dom.window, document: dom.window.document, IS_REACT_ACT_ENVIRONMENT: true });
  let snapshot: import("../src/agent-session/shared/terminalChat").TerminalChatSnapshot = { ...connectedSnapshot, status: "observed", history: {
    has_more: false, messages: [{ id: "answer", seq: 1, role: "agent", kind: { type: "prose", text: "Ready for review" } }],
  } };
  Object.assign(dom.window, { webkit: { messageHandlers: { agentSession: { postMessage: async () => ({ ok: true, value: snapshot }) } } } });
  const copy: AgentSessionCopy = Object.assign({ chatStale: "Refresh failed · showing cached history",
    chatObserved: "Observed transcript", chatConversation: "Conversation", connectedPrompt: "Message Codex" } as AgentSessionCopy,
    { chatConnected: "Connected to Codex" });
  const context = { workspaceId: "workspace", panelId: "surface", copy } as AppContext;
  const root = createRoot(dom.window.document.getElementById("root")!);
  try {
    await act(async () => root.render(<TerminalChatSurface context={context} />));
    expect(dom.window.document.body.textContent).toContain("Ready for review");
    snapshot = connectedSnapshot;
    await act(async () => root.render(<TerminalChatSurface context={{ ...context }} />));
    expect(dom.window.document.querySelector("header")).toBeNull();
    expect(dom.window.document.querySelector(".terminal-chat-notice")?.textContent).toBe(copy.chatStale);
    expect(dom.window.document.body.textContent).toContain("Ready for review");
  } finally {
    await act(async () => root.unmount());
    dom.window.close();
    Object.assign(globalThis, { window: previousWindow, document: previousDocument, IS_REACT_ACT_ENVIRONMENT: false });
  }
});
