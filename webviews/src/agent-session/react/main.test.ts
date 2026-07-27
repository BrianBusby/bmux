import { expect, test } from "bun:test";
import { composerSurfaceOverflowClass } from "./main";

test("multiline composer surface allows add-context menu overflow", () => {
  expect(composerSurfaceOverflowClass(true)).toBe("overflow-visible rounded-full");
  expect(composerSurfaceOverflowClass(false)).toBe("overflow-visible rounded-3xl");
});
