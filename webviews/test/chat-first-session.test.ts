import { expect, test } from "bun:test";
import { fileURLToPath } from "node:url";

test.each(["fresh", "ordinary", "connected", "failed", "source"])("bundled Chat-first startup: %s", async scenario => {
  const child = Bun.spawn([
    "node", fileURLToPath(new URL("./helpers/check-chat-first-session.mjs", import.meta.url)), scenario,
  ], { stdout: "pipe", stderr: "pipe" });
  const [exitCode, errors] = await Promise.all([child.exited, new Response(child.stderr).text()]);
  expect(exitCode, errors).toBe(0);
});
