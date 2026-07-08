import { describe, expect, mock, test } from "bun:test";

import { resolveBillingTeam } from "../services/billing/teamResolution";

describe("billing team resolution", () => {
  test("selectedTeam wins without listing teams", async () => {
    const listTeams = mock(async () => [
      paidTeam("team-paid"),
    ]);

    await expect(resolveBillingTeam({
      selectedTeam: freeTeam("team-selected"),
      listTeams,
    })).resolves.toMatchObject({ id: "team-selected" });
    expect(listTeams).not.toHaveBeenCalled();
  });

  test("uses the single listed team", async () => {
    await expect(resolveBillingTeam({
      selectedTeam: null,
      listTeams: async () => [freeTeam("team-only")],
    })).resolves.toMatchObject({ id: "team-only" });
  });

  test("returns null for multiple teams with no paid metadata", async () => {
    await expect(resolveBillingTeam({
      selectedTeam: null,
      listTeams: async () => [
        freeTeam("team-free"),
        { id: "team-empty", clientReadOnlyMetadata: { bmuxPlan: "" } },
      ],
    })).resolves.toBeNull();
  });

  test("preserves raw bmuxVmPlan masking before checking bmuxPlan", async () => {
    await expect(resolveBillingTeam({
      selectedTeam: null,
      listTeams: async () => [
        freeTeam("team-free"),
        { id: "team-masked", clientReadOnlyMetadata: { bmuxVmPlan: "", bmuxPlan: "team" } },
      ],
    })).resolves.toBeNull();
  });

  test("uses the only team paid through bmuxPlan", async () => {
    await expect(resolveBillingTeam({
      selectedTeam: null,
      listTeams: async () => [
        freeTeam("team-free"),
        { id: "team-paid", clientReadOnlyMetadata: { bmuxPlan: "team" } },
      ],
    })).resolves.toMatchObject({ id: "team-paid" });
  });

  test("uses the only team paid through bmuxVmPlan", async () => {
    await expect(resolveBillingTeam({
      selectedTeam: null,
      listTeams: async () => [
        freeTeam("team-free"),
        { id: "team-override", clientReadOnlyMetadata: { bmuxVmPlan: "pro" } },
      ],
    })).resolves.toMatchObject({ id: "team-override" });
  });

  test("prefers a real bmuxPlan subscription over a bmuxVmPlan override even with a larger id", async () => {
    await expect(resolveBillingTeam({
      selectedTeam: null,
      listTeams: async () => [
        { id: "team-z", clientReadOnlyMetadata: { bmuxPlan: "team" } },
        { id: "team-a", clientReadOnlyMetadata: { bmuxVmPlan: "pro" } },
      ],
    })).resolves.toMatchObject({ id: "team-z" });
  });

  test("picks the first team id deterministically when multiple teams have real subscriptions", async () => {
    await expect(resolveBillingTeam({
      selectedTeam: null,
      listTeams: async () => [
        { id: "team-z", clientReadOnlyMetadata: { bmuxPlan: "team" } },
        { id: "team-a", clientReadOnlyMetadata: { bmuxPlan: "team" } },
      ],
    })).resolves.toMatchObject({ id: "team-a" });
  });

  test("falls back to a bmuxVmPlan override team deterministically when no team has a real subscription", async () => {
    await expect(resolveBillingTeam({
      selectedTeam: null,
      listTeams: async () => [
        { id: "team-z", clientReadOnlyMetadata: { bmuxVmPlan: "pro" } },
        { id: "team-a", clientReadOnlyMetadata: { bmuxVmPlan: "enterprise" } },
      ],
    })).resolves.toMatchObject({ id: "team-a" });
  });

  test("returns null for zero teams", async () => {
    await expect(resolveBillingTeam({
      selectedTeam: null,
      listTeams: async () => [],
    })).resolves.toBeNull();
  });
});

function paidTeam(id: string) {
  return { id, clientReadOnlyMetadata: { bmuxPlan: "team" } };
}

function freeTeam(id: string) {
  return { id, clientReadOnlyMetadata: { bmuxPlan: "free" } };
}
