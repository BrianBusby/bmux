import { expect, test } from "bun:test";
import { JSDOM } from "jsdom";
import { act } from "react";
import { createRoot } from "react-dom/client";
import { ConnectedChatComposer } from "../src/agent-session/react/ConnectedChatComposer";
import type { AgentSessionCopy, AppContext } from "../src/agent-session/shared/types";
import type { ConnectedControl } from "../src/agent-session/shared/connectedChat";

test("reload restores an uncertain draft without resending, then reconciles acceptance", async () => {
  const dom = new JSDOM("<!doctype html><div id='root'></div>", { url: "https://example.test" });
  const previousWindow = globalThis.window;
  const previousDocument = globalThis.document;
  Object.assign(globalThis, { window: dom.window, document: dom.window.document, IS_REACT_ACT_ENVIRONMENT: true });
  const calls: string[] = [];
  Object.assign(dom.window, { webkit: { messageHandlers: { agentSession: { postMessage: async (request: { method: string }) => {
    calls.push(request.method); return { ok: true, value: {} };
  } } } } });
  const copy = { connectedPrompt: "Message Codex", connectedQueue: "Send follow-up", chatInteract: "Interact in Terminal",
    connectedUncertain: "Delivery uncertain", connectedAccepted: "Accepted", connectedQueuePolicy: "Provider queue" } as AgentSessionCopy;
  const context = { copy } as AppContext;
  const control: ConnectedControl = { threadId: "original", status: "connected", queueFollowUp: true,
    actions: [{ id: "request-1", threadID: "original", operation: "queue", text: "Inspect the build", delivery: "uncertain" }] };
  let root = createRoot(dom.window.document.getElementById("root")!);
  try {
    await act(async () => root.render(<ConnectedChatComposer context={context} control={control} enabled />));
    expect(dom.window.document.querySelector("textarea")?.value).toBe("Inspect the build");
    const send = [...dom.window.document.querySelectorAll("button")].find(button => button.textContent === "Send follow-up")!;
    expect(send.disabled).toBe(true);
    await act(async () => send.click());
    expect(calls).toEqual([]);
    expect(dom.window.document.body.textContent).toContain("Delivery uncertain");
    await act(async () => root.render(<ConnectedChatComposer context={context} control={{ ...control,
      actions: control.actions!.map(action => ({ ...action, delivery: "accepted" })) }} enabled />));
    expect(dom.window.document.querySelector("textarea")?.value).toBe("");
    expect(dom.window.document.body.textContent).toContain("Accepted");
    expect(calls).toEqual([]);
    await act(async () => root.unmount());
    root = createRoot(dom.window.document.getElementById("root")!);
    await act(async () => root.render(<ConnectedChatComposer context={context} control={{ ...control, draft: { revision: "restored-r1", text: "Inspect the build" },
      actions: control.actions!.map(action => ({ ...action, delivery: "accepted" })) }} enabled />));
    expect(dom.window.document.querySelector("textarea")?.value).toBe("Inspect the build");
    const terminal = [...dom.window.document.querySelectorAll("button")].find(button => button.textContent === "Interact in Terminal")!;
    await act(async () => terminal.click());
    expect(calls).toEqual(["terminalChat.openTerminal"]);
  } finally {
    await act(async () => root.unmount()); dom.window.close();
    Object.assign(globalThis, { window: previousWindow, document: previousDocument, IS_REACT_ACT_ENVIRONMENT: false });
  }
});
