import type { TranscriptEntry } from "./sessionModel";

type TranscriptGroup =
  | { kind: "entry"; id: string; entry: TranscriptEntry }
  | { kind: "commands"; id: string; entries: TranscriptEntry[] };

/** Group only adjacent commands; every message or other activity is a boundary. */
export function groupTranscriptEntries(entries: TranscriptEntry[]): TranscriptGroup[] {
  const groups: TranscriptGroup[] = [];
  for (const entry of entries) {
    if (entry.role === "activity" && entry.activityKind === "command") {
      const last = groups.at(-1);
      if (last?.kind === "commands") {
        last.entries.push(entry);
      } else if (last?.kind === "entry" && last.entry.role === "activity" && last.entry.activityKind === "command") {
        groups[groups.length - 1] = { kind: "commands", id: last.id, entries: [last.entry, entry] };
      } else {
        groups.push({ kind: "entry", id: entry.id, entry });
      }
    } else {
      groups.push({ kind: "entry", id: entry.id, entry });
    }
  }
  return groups;
}
