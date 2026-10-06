import { expect, test } from "bun:test";
import { fileURLToPath } from "node:url";

test.each([
  { locale: "English", conversation: "Conversation", interact: "Interact in Terminal", readOnly: "Read-only", user: "You" },
  { locale: "Japanese", conversation: "会話", interact: "ターミナルで操作", readOnly: "読み取り専用", user: "あなた" },
])("bundled Chat mounts the custom conversation in $locale", async (copy) => {
  // Node supplies the real vm contexts JSDOM uses to execute the self-contained
  // WKWebView resource. Bun's vm cannot execute JSDOM's Window proxy.
  const child = Bun.spawn([
    "node", fileURLToPath(new URL("./helpers/check-bundled-terminal-chat.mjs", import.meta.url)), JSON.stringify(copy),
  ], { stdout: "pipe", stderr: "pipe" });
  const [exitCode, errors] = await Promise.all([child.exited, new Response(child.stderr).text()]);
  expect(exitCode, errors).toBe(0);
});
