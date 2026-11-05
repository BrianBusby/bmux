import type { ObservedMessage } from "./terminalChat";

type TerminalChatRow =
  | { kind: "message"; id: string; message: ObservedMessage }
  | { kind: "commands"; id: string; messages: ObservedMessage[] }
  | { kind: "report"; id: string; index: number };

function isCommand(message: ObservedMessage): boolean {
  if (message.kind.type === "terminal") return true;
  if (message.kind.type !== "tool_use") return false;
  const name = (message.kind.tool_name ?? "").toLowerCase();
  return name === "exec" || name === "exec_command" || name.endsWith(".exec") || name.endsWith(".exec_command");
}

function isVisible(message: ObservedMessage): boolean {
  return message.kind.type !== "thought" && (message.kind.type !== "status" || message.kind.event === "interrupted");
}

/** Preserve conversation order while collecting adjacent visible commands. */
export function terminalChatRows(messages: ObservedMessage[], reportEndIndexes: ReadonlySet<number>): TerminalChatRow[] {
  const rows: TerminalChatRow[] = [];
  let commands: ObservedMessage[] = [];
  const flushCommands = () => {
    if (commands.length > 1) rows.push({ kind: "commands", id: commands[0].id, messages: commands });
    else if (commands.length === 1) rows.push({ kind: "message", id: commands[0].id, message: commands[0] });
    commands = [];
  };
  messages.forEach((message, index) => {
    if (isVisible(message)) {
      if (isCommand(message)) commands.push(message);
      else {
        flushCommands();
        rows.push({ kind: "message", id: message.id, message });
      }
    }
    if (reportEndIndexes.has(index)) {
      flushCommands();
      rows.push({ kind: "report", id: `report-${message.id}`, index });
    }
  });
  flushCommands();
  return rows;
}
