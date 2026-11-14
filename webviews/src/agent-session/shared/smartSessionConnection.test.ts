import { expect, test } from "bun:test";
import React from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { SmartSessionSurface } from "../react/SmartSessionSurface";

test("an unavailable session does not imply a live connection", () => {
  const html = renderToStaticMarkup(React.createElement(SmartSessionSurface, { isActive: false }));
  expect(html).toContain("Unavailable");
  expect(html).not.toContain("focus-connected-dot");
});

test("an unavailable session does not claim verified workspace identity", () => {
  const html = renderToStaticMarkup(React.createElement(SmartSessionSurface, { isActive: false }));
  expect(html).not.toContain("Verified workspace identity");
});
