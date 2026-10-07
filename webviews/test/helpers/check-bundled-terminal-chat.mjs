import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { JSDOM, VirtualConsole } from "jsdom";

async function checkBundledChat(copy) {
  const html = await readFile(new URL("../../../Resources/agent-session-react/index.html", import.meta.url), "utf8");
  const calls = [];
  const virtualConsole = new VirtualConsole();
  let observer;
  let didMount;
  let didFail;
  const mounted = new Promise((resolve, reject) => {
    didMount = resolve;
    didFail = reject;
  });
  virtualConsole.on("jsdomError", (error) => didFail(error));
  // A deadline bounds a broken mount; DOM mutations signal successful rendering.
  const deadline = setTimeout(() => didFail(new Error("Bundled Chat did not mount")), 3000);
  const dom = new JSDOM(html, {
    url: "file:///bmux.app/Contents/Resources/agent-session-react/index.html",
    runScripts: "dangerously",
    virtualConsole,
    beforeParse(window) {
      observer = new window.MutationObserver(() => {
        if (window.document.querySelector(".terminal-chat-prose")?.textContent === "Review the roof inspection") {
          didMount();
        }
      });
      observer.observe(window.document, { childList: true, subtree: true, characterData: true });
      Object.assign(window, {
        webkit: { messageHandlers: { agentSession: { postMessage: async (request) => {
          calls.push(request.method);
          switch (request.method) {
            case "app.context":
              return { ok: true, value: {
                readOnlyTerminalChat: true, renderer: "react", initialProviderId: "codex",
                workspaceId: "workspace", panelId: "surface",
                theme: { isDark: true, pageBackground: "#111", surfaceBackground: "#222",
                  surfaceElevatedBackground: "#333", inputBackground: "#222", border: "#444",
                  borderStrong: "#555", text: "#eee", mutedText: "#ccc", softText: "#aaa",
                  accent: "#0af", accentSoft: "#08b", danger: "#f44", shadow: "#000" },
                copy: { chatConversation: copy.conversation, chatInteract: copy.interact,
                  chatReadOnly: copy.readOnly, chatUser: copy.user, chatObserved: "Transcript updates" },
              } };
            case "provider.list":
              return { ok: true, value: [] };
            case "terminalChat.snapshot":
              return { ok: true, value: { status: "observed", sessionId: "thread",
                workspaceId: "workspace", surfaceId: "surface",
                history: { has_more: false, source_revision: "original", messages: [
                  { id: "prompt", seq: 1, role: "user", kind: { type: "prose", text: "Review the roof inspection" } },
                ] },
              } };
            case "terminalChat.openTerminal":
              return { ok: true, value: {} };
            default:
              throw new Error(`Unexpected native request: ${request.method}`);
          }
        } } } },
      });
    },
  });
  try {
    await mounted;
    assert.equal(dom.window.document.querySelector(".terminal-chat-history")?.getAttribute("aria-label"), copy.conversation);
    assert.equal(dom.window.document.querySelector(".terminal-chat-role")?.textContent, copy.user);
    assert.equal(dom.window.document.querySelector(".terminal-chat-footer")?.textContent, copy.readOnly);
    assert.equal(dom.window.document.querySelector("textarea,input,[contenteditable=true]"), null);
    assert.equal(dom.window.document.querySelector(".terminal-chat-header button"), null);
    assert.deepEqual(calls, ["app.context", "provider.list", "terminalChat.snapshot"]);
  } finally {
    clearTimeout(deadline);
    observer?.disconnect();
    dom.window.close();
  }
}

try {
  await checkBundledChat(JSON.parse(process.argv[2]));
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
