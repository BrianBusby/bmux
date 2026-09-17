import { expect, test } from "bun:test";
import { JSDOM } from "jsdom";
import { act } from "react";
import { createRoot } from "react-dom/client";
import { TerminalChatSurface } from "../src/agent-session/react/TerminalChatSurface";
import type { AgentSessionCopy, AppContext } from "../src/agent-session/shared/types";

test("read-only Chat renders authoritative content and only opens its terminal", async () => {
  const dom = new JSDOM("<!doctype html><div id='root'></div>", { url: "https://example.test" });
  const previousWindow = globalThis.window;
  const previousDocument = globalThis.document;
  Object.assign(globalThis, { window: dom.window, document: dom.window.document, IS_REACT_ACT_ENVIRONMENT: true });
  const calls: string[] = [];
  Object.assign(dom.window, { webkit: { messageHandlers: { agentSession: { postMessage: async (request: { method: string }) => {
    calls.push(request.method);
    return { ok: true, value: { status: "observed", sessionId: "thread", workspaceId: "workspace", surfaceId: "surface",
      history: { has_more: false, messages: [
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
    const fallback = [...dom.window.document.querySelectorAll("button")].find(button => button.textContent === "Interact in Terminal")!;
    await act(async () => fallback.click());
    expect(calls).toEqual(["terminalChat.snapshot", "terminalChat.openTerminal"]);
  } finally {
    await act(async () => root.unmount());
    dom.window.close();
    Object.assign(globalThis, { window: previousWindow, document: previousDocument, IS_REACT_ACT_ENVIRONMENT: false });
  }
});
