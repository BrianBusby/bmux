import { expect, test } from "bun:test";
import type { TranscriptEntry } from "./sessionModel";
import { groupTranscriptEntries } from "./transcriptGroups";

test("groups adjacent commands between assistant messages", () => {
  const entries: TranscriptEntry[] = [
    { id: "assistant-1", role: "assistant", text: "Checking" },
    { id: "command-1", role: "activity", activityKind: "command", text: "exec" },
    { id: "command-2", role: "activity", activityKind: "command", text: "exec" },
    { id: "assistant-2", role: "assistant", text: "Found it" },
    { id: "command-3", role: "activity", activityKind: "command", text: "exec" },
    { id: "command-4", role: "activity", activityKind: "command", text: "exec" },
  ];
  const groups = groupTranscriptEntries(entries);
  expect(groups.map((group) => group.kind)).toEqual(["entry", "commands", "entry", "commands"]);
  expect(groups[1]).toMatchObject({ kind: "commands", entries: [entries[1], entries[2]] });
  expect(groups[3]).toMatchObject({ kind: "commands", entries: [entries[4], entries[5]] });
});

test("leaves single commands and other activity as individual rows", () => {
  const entries: TranscriptEntry[] = [
    { id: "command-1", role: "activity", activityKind: "command", text: "exec" },
    { id: "file-1", role: "activity", activityKind: "fileChange", text: "Edited file" },
    { id: "command-2", role: "activity", activityKind: "command", text: "exec" },
  ];
  expect(groupTranscriptEntries(entries)).toEqual(entries.map((entry) => ({ kind: "entry", entry, id: entry.id })));
});
