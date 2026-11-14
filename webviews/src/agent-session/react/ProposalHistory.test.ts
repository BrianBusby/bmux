import { expect, test } from "bun:test";
import React from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { ProposalHistory } from "./SmartSessionSurface";
import type { SmartSessionFactual } from "../shared/types";

const base: SmartSessionFactual = { priorTurns: [], turnCount: 0 };
const observed = {
  id: "evidence-1", sequence: 1, timestamp: "2026-11-13T13:21:36Z", provider: "codex",
  source: "observed", origin: "codex-transcript", eventSchemaVersion: 1,
  providerSessionId: "thread", providerTurnId: "turn", providerItemId: "item", text: "Inspect and validate", truncated: false,
};

test("proposal history does not interpret an older snapshot as an empty scan", () => {
  const html = renderToStaticMarkup(React.createElement(ProposalHistory, { factual: base }));
  expect(html).toContain("Proposal history unavailable");
  expect(html).not.toContain("No proposal found");
});

test("proposal history displays evidence with partial coverage and rejects inferred records", () => {
  const factual: SmartSessionFactual = { ...base,
    proposedPlanCoverage: { scanWindowTruncated: true, omittedObservations: false },
    proposedPlanObservations: [observed, { ...observed, id: "inferred", source: "inferred", text: "Unsupported claim" }],
  };
  const html = renderToStaticMarkup(React.createElement(ProposalHistory, { factual }));
  expect(html).toContain("Proposal history is partial");
  expect(html).toContain("Inspect and validate");
  expect(html).toContain("codex-transcript");
  expect(html).toContain("evidence-1");
  expect(html).not.toContain("Unsupported claim");
});

test("proposal rendering bounds unexpectedly large text", () => {
  const factual: SmartSessionFactual = { ...base,
    proposedPlanCoverage: { scanWindowTruncated: false, omittedObservations: false },
    proposedPlanObservations: [{ ...observed, text: "x".repeat(12000) + "SENTINEL" }],
  };
  const html = renderToStaticMarkup(React.createElement(ProposalHistory, { factual }));
  expect(html).toContain("Proposal text was truncated.");
  expect(html).not.toContain("SENTINEL");
});

test("proposal history rejects malformed provider identity", () => {
  const factual: SmartSessionFactual = { ...base,
    proposedPlanCoverage: { scanWindowTruncated: false, omittedObservations: false },
    proposedPlanObservations: [{ ...observed, providerTurnId: " ", text: "Bad identity" }],
  };
  const html = renderToStaticMarkup(React.createElement(ProposalHistory, { factual }));
  expect(html).toContain("Proposal history is partial");
  expect(html).not.toContain("Bad identity");
});
