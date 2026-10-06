import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { JSDOM, VirtualConsole } from "jsdom";

const scenario = process.argv[2];
const html = await readFile(process.argv[3] ?? new URL("../../../Resources/agent-session-react/index.html", import.meta.url), "utf8");
const calls = [];
const keyboardScenario = ["keyboard", "queue-disabled", "disconnected", "uncertain"].includes(scenario);
let connected = scenario === "connected" || keyboardScenario;
let observer;
let dom;
let check;
const completed = new Promise((resolve, reject) => { check = { resolve, reject }; });
const deadline = setTimeout(() => check.reject(new Error(`Chat-first ${scenario} did not complete`)), 4000);
const virtualConsole = new VirtualConsole();
virtualConsole.on("jsdomError", error => check.reject(error));
const theme = { isDark: true, pageBackground: "#111", surfaceBackground: "#222", surfaceElevatedBackground: "#333",
  inputBackground: "#222", border: "#444", borderStrong: "#555", text: "#eee", mutedText: "#ccc",
  softText: "#aaa", accent: "#0af", accentSoft: "#08b", danger: "#f44", shadow: "#000" };
const copy = { chatConversation: "Conversation", chatReadOnly: "Read-only", chatInteract: "Interact in Terminal",
  connectedNewSession: "New connected session", connectedStartFailed: "Connection failed", startingStatus: "Connecting",
  connectedPrompt: "Prompt", connectedQueue: "Send", connectedQueuePolicy: "Queued for this session",
  connectedAccepted: "Accepted", connectedUnavailable: "Disconnected" };
let submitted = false;
let retried = false;
let acknowledge;
dom = new JSDOM(html, {
  url: "file:///bmux.app/Contents/Resources/agent-session-react/index.html", runScripts: "dangerously", virtualConsole,
  beforeParse(window) {
    observer = new window.MutationObserver(() => {
      try {
        if (scenario === "keyboard" && submitted && window.document.querySelector(".terminal-chat-composer output")?.textContent === copy.connectedAccepted) {
          assert.equal(window.document.querySelector("textarea").value, "");
          window.document.querySelector("textarea").dispatchEvent(new window.KeyboardEvent("keydown", { key: "Enter", bubbles: true }));
          assert.equal(calls.filter(call => call.method === "terminalChat.action").length, 1);
          check.resolve();
        } else if (scenario === "ordinary" && window.document.querySelector(".terminal-chat-footer")) {
          assert.equal(calls.filter(call => call.method === "terminalChat.startConnected").length, 0);
          assert.equal(window.document.querySelector(".terminal-chat-launch button")?.textContent, copy.connectedNewSession);
          check.resolve();
        } else if (scenario === "failed" && !retried && window.document.querySelector('[role="alert"]')) {
          assert.equal(window.document.querySelector('[role="alert"]').textContent, copy.connectedStartFailed);
          assert.equal(calls.filter(call => call.method === "terminalChat.startConnected").length, 1);
          const retry = window.document.querySelector(".terminal-chat-launch button");
          if (retry.disabled) return;
          retried = true;
          retry.click();
        } else if (connected && !submitted) {
          const input = window.document.querySelector("textarea");
          if (!input) return;
          submitted = true;
          assert.equal(window.document.querySelector("textarea")?.value, "Review the roof inspection");
          if (scenario === "keyboard") {
            for (const options of [{ shiftKey: true }, { altKey: true }, { isComposing: true }, { keyCode: 229 }]) {
              assert.equal(input.dispatchEvent(new window.KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true, ...options })), true);
            }
            assert.equal(calls.filter(call => call.method === "terminalChat.action").length, 0);
          }
          if (!["queue-disabled", "disconnected", "uncertain"].includes(scenario)) {
            assert.equal(window.document.querySelector(".terminal-chat-header button"), null);
            assert.equal(window.document.querySelector(".terminal-chat-composer-actions button"), null);
          }
          input.dispatchEvent(new window.KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true }));
          if (["queue-disabled", "disconnected", "uncertain"].includes(scenario)) {
            assert.equal(calls.filter(call => call.method === "terminalChat.action").length, 0);
            check.resolve();
          } else if (scenario === "keyboard") {
            input.dispatchEvent(new window.KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true }));
            assert.equal(calls.filter(call => call.method === "terminalChat.action").length, 1);
            assert.equal(input.value, "Review the roof inspection");
            acknowledge();
          }
        }
      } catch (error) { check.reject(error); }
    });
    observer.observe(window.document, { childList: true, subtree: true, characterData: true, attributes: true });
    Object.assign(window, { webkit: { messageHandlers: { agentSession: { postMessage: async request => {
      calls.push(request);
      switch (request.method) {
        case "app.context": return { ok: true, value: { readOnlyTerminalChat: true, canStartConnectedSession: true,
          automaticallyStartConnectedSession: scenario !== "ordinary", renderer: "react", initialProviderId: "codex",
          workspaceId: "workspace", panelId: "surface", theme, copy } };
        case "provider.list": return { ok: true, value: [] };
        case "terminalChat.snapshot":
          if (scenario === "source" && calls.some(call => call.method === "terminalChat.startConnected")) {
            // A real subsequent bridge read signals that the launch reply was
            // handled, even when the correct source DOM needs no mutation.
            try {
              assert.equal(window.document.querySelector(".terminal-chat-footer")?.textContent, copy.chatReadOnly);
              assert.equal(calls.filter(call => call.method === "terminalChat.startConnected").length, 1);
              check.resolve();
            } catch (error) { check.reject(error); }
          }
          return { ok: true, value: connected ? {
          status: "unavailable", reason: "historyUnavailable", workspaceId: "workspace", surfaceId: "surface", sessionId: "new-thread",
          control: { status: scenario === "disconnected" ? "disconnected" : "connected", threadId: "new-thread", queueFollowUp: scenario !== "queue-disabled",
            actions: scenario === "uncertain" ? [{ id: "pending", threadID: "new-thread", operation: "queue", text: "Review the roof inspection", delivery: "uncertain" }] : [],
            draft: { revision: "00000000-0000-0000-0000-000000000001", text: "Review the roof inspection" } },
        } : { status: "unavailable" } };
        case "terminalChat.startConnected":
          if (scenario === "failed" && !retried) return { ok: false, error: { code: "unavailable", userMessage: "Unavailable" } };
          // Native launch selects a new panel. The retained source remains
          // unconnected when the user returns to its original Chat view.
          connected = scenario !== "source";
          return { ok: true, value: { started: true } };
        case "terminalChat.action":
          assert.equal(["queue-disabled", "disconnected", "uncertain"].includes(scenario), false, "unavailable control submitted a prompt");
          assert.equal(request.params.sessionId, "new-thread");
          assert.equal(request.params.text, "Review the roof inspection");
          assert.equal(calls.filter(call => call.method === "terminalChat.startConnected").length, scenario === "connected" || keyboardScenario ? 0 : scenario === "failed" ? 2 : 1);
          assert.equal(calls.filter(call => call.method === "terminalChat.action").length, 1);
          assert.equal(calls.some(call => call.method === "provider.writeLine" || call.method === "terminalChat.openTerminal"), false);
          if (scenario === "keyboard") return new Promise(resolve => { acknowledge = () => resolve({ ok: true,
            value: { id: request.params.requestId, threadID: "new-thread", delivery: "accepted" } }); });
          check.resolve();
          return { ok: true, value: { id: request.params.requestId, threadID: "new-thread", delivery: "accepted" } };
        default: throw new Error(`Unexpected native request: ${request.method}`);
      }
    } } } } });
  },
});
try { await completed; } catch (error) { console.error(error.message); process.exitCode = 1; }
finally { clearTimeout(deadline); observer?.disconnect(); dom.window.close(); }
