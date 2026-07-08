import { expect, test } from "bun:test";
import { promptMentionMarkdown, promptTextWithAutoContext } from "./promptMentions";

test("prompt mention serialization matches Codex markdown links", () => {
  expect(promptMentionMarkdown({
    kind: "at",
    label: "bmux",
    name: "bmux",
    path: "/Users/lawrence/fun/bmuxterm-hq",
  })).toBe("[bmux](/Users/lawrence/fun/bmuxterm-hq)");

  expect(promptMentionMarkdown({
    displayName: "Codex",
    kind: "agent",
    name: "codex",
    path: "provider://codex",
  })).toBe("[@Codex](provider://codex)");

  expect(promptMentionMarkdown({
    kind: "skill",
    name: "codex-review",
    path: "skill://codex-review",
  })).toBe("[$codex-review](skill://codex-review)");
});

test("prompt mention serialization escapes markdown labels and destinations", () => {
  expect(promptMentionMarkdown({
    kind: "at",
    label: "work [tree]",
    name: "work [tree]",
    path: "/tmp/work tree/(current)",
  })).toBe("[work \\[tree\\]](/tmp/work%20tree/\\(current\\))");
});

test("auto context prepends the workspace mention only when enabled and absent", () => {
  const mention = {
    kind: "at" as const,
    label: "bmux",
    name: "bmux",
    path: "/Users/lawrence/fun/bmuxterm-hq",
  };

  expect(promptTextWithAutoContext("fix ui", mention, true))
    .toBe("[bmux](/Users/lawrence/fun/bmuxterm-hq)\n\nfix ui");
  expect(promptTextWithAutoContext("fix ui", mention, false)).toBe("fix ui");
  expect(promptTextWithAutoContext("[bmux](/Users/lawrence/fun/bmuxterm-hq)\n\nfix ui", mention, true))
    .toBe("[bmux](/Users/lawrence/fun/bmuxterm-hq)\n\nfix ui");
});
