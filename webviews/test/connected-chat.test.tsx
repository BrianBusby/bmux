import { expect, test } from "bun:test";
import { JSDOM } from "jsdom";
import { act } from "react";
import { createRoot } from "react-dom/client";
import { ConnectedChatComposer } from "../src/agent-session/react/ConnectedChatComposer";
import type { AgentSessionCopy, AppContext } from "../src/agent-session/shared/types";
import type { ConnectedControl } from "../src/agent-session/shared/connectedChat";
test("initial connected control without action or receipt mounts before a later receipt", async () => {
  const dom = new JSDOM("<!doctype html><div id='root'></div>", { url: "https://example.test" });
  const previousWindow = globalThis.window;
  const previousDocument = globalThis.document;
  Object.assign(globalThis, { window: dom.window, document: dom.window.document, IS_REACT_ACT_ENVIRONMENT: true });
  const context = { copy: {
    connectedPrompt: "Message Codex", connectedQueue: "Send follow-up", chatInteract: "Interact in Terminal",
    connectedUncertain: "Delivery uncertain", connectedAccepted: "Accepted", connectedQueuePolicy: "Provider queue"
  } as AgentSessionCopy } as AppContext;
  const control: ConnectedControl = { threadId: "original", status: "connected", queueFollowUp: true };
  const root = createRoot(dom.window.document.getElementById("root")!);
  try {
    await act(async () => root.render(<ConnectedChatComposer context={context} control={control} enabled />));
    expect(dom.window.document.querySelector("textarea")?.getAttribute("aria-label")).toBe("Message Codex");
    expect(dom.window.document.body.textContent).not.toContain("Accepted");
    await act(async () => root.render(<ConnectedChatComposer context={context} control={{ ...control,
      actions: [{ id: "receipt-1", threadID: "original", operation: "queue", text: "Later receipt", delivery: "accepted" }] }} enabled />));
    expect(dom.window.document.body.textContent).toContain("Accepted");
  } finally {
    await act(async () => root.unmount()); dom.window.close();
    Object.assign(globalThis, { window: previousWindow, document: previousDocument, IS_REACT_ACT_ENVIRONMENT: false });
  }
});

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
    expect(dom.window.document.querySelectorAll("button")).toHaveLength(0);
    await act(async () => dom.window.document.querySelector("textarea")!.dispatchEvent(
      new dom.window.KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true })));
    expect(calls).toEqual([]);
    expect(dom.window.document.body.textContent).toContain("Delivery uncertain");
    await act(async () => root.render(<ConnectedChatComposer context={context} control={{ ...control,
      actions: control.actions!.map(action => ({ ...action, delivery: "accepted" })) }} enabled />));
    expect(dom.window.document.querySelector("textarea")?.value).toBe("Inspect the build");
    expect(dom.window.document.body.textContent).toContain("Accepted");
    expect(calls).toEqual([]);
    await act(async () => root.unmount());
    root = createRoot(dom.window.document.getElementById("root")!);
    await act(async () => root.render(<ConnectedChatComposer context={context} control={{ ...control, draft: { revision: "restored-r1", text: "Inspect the build" },
      actions: control.actions!.map(action => ({ ...action, delivery: "accepted" })) }} enabled />));
    expect(dom.window.document.querySelector("textarea")?.value).toBe("Inspect the build");
    expect(dom.window.document.querySelectorAll("button")).toHaveLength(0);
    expect(calls).toEqual([]);
  } finally {
    await act(async () => root.unmount()); dom.window.close();
    Object.assign(globalThis, { window: previousWindow, document: previousDocument, IS_REACT_ACT_ENVIRONMENT: false });
  }
});


test("Enter submits once, preserves pending drafts, and respects queue and composition guards", async () => {
  const dom = new JSDOM("<!doctype html><div id='root'></div>", { url: "https://example.test" });
  const previousWindow = globalThis.window;
  const previousDocument = globalThis.document;
  Object.assign(globalThis, { window: dom.window, document: dom.window.document, IS_REACT_ACT_ENVIRONMENT: true });
  const calls: { method: string; params: { requestId: string; text: string; sessionId: string } }[] = [];
  let acknowledge!: (reply: unknown) => void;
  Object.assign(dom.window, { webkit: { messageHandlers: { agentSession: { postMessage: (request: typeof calls[number]) => {
    calls.push(request);
    return new Promise(resolve => { acknowledge = resolve; });
  } } } } });
  const context = { copy: { connectedPrompt: "Message Codex", connectedQueue: "Send",
    chatInteract: "Interact in Terminal", connectedAccepted: "Accepted" } as AgentSessionCopy } as AppContext;
  const control: ConnectedControl = { threadId: "original", status: "connected", queueFollowUp: true,
    draft: { revision: "draft-a", text: "Review the roof inspection" } };
  const root = createRoot(dom.window.document.getElementById("root")!);
  const press = (options: KeyboardEventInit = {}) => dom.window.document.querySelector("textarea")!.dispatchEvent(
    new dom.window.KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true, ...options }));
  try {
    await act(async () => root.render(<ConnectedChatComposer context={context} control={control} enabled />));
    expect(dom.window.document.querySelectorAll("button")).toHaveLength(0);
    for (const options of [{ shiftKey: true }, { altKey: true }, { isComposing: true }, { keyCode: 229 }]) {
      await act(async () => { expect(press(options)).toBe(true); });
    }
    expect(calls).toEqual([]);
    await act(async () => root.render(<ConnectedChatComposer context={context} control={{ ...control, queueFollowUp: false }} enabled />));
    await act(async () => { press(); });
    expect(calls).toEqual([]);
    await act(async () => root.render(<ConnectedChatComposer context={context} control={control} enabled={false} />));
    await act(async () => { press(); });
    expect(calls).toEqual([]);
    await act(async () => root.render(<ConnectedChatComposer context={context} control={control} enabled />));
    await act(async () => { expect(press()).toBe(false); press(); });
    expect(calls).toHaveLength(1);
    expect(calls[0].method).toBe("terminalChat.action");
    expect(calls[0].params.text).toBe("Review the roof inspection");
    expect(calls[0].params.sessionId).toBe("original");
    expect(dom.window.document.querySelector("textarea")?.value).toBe("Review the roof inspection");
    await act(async () => acknowledge({ ok: true, value: { id: calls[0].params.requestId,
      threadID: "original", operation: "queue", text: calls[0].params.text, delivery: "accepted" } }));
    expect(dom.window.document.querySelector("textarea")?.value).toBe("");
    expect(dom.window.document.body.textContent).toContain("Accepted");
    await act(async () => { press(); });
    expect(calls).toHaveLength(1);
  } finally {
    await act(async () => root.unmount()); dom.window.close();
    Object.assign(globalThis, { window: previousWindow, document: previousDocument, IS_REACT_ACT_ENVIRONMENT: false });
  }
});
