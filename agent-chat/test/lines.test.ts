import { deepStrictEqual } from "node:assert/strict";
import { readLines } from "../adapters/lines";

const text = new TextEncoder().encode(" first \n猫\nlast");
const lines: string[] = [];
const closes: string[] = [];
const stream = new ReadableStream<Uint8Array>({
  start(controller) {
    controller.enqueue(text.slice(0, 9));
    controller.enqueue(text.slice(9, 10));
    controller.enqueue(text.slice(10));
    controller.close();
  },
});
await readLines(stream, (line) => lines.push(line), () => closes.push("closed"));
deepStrictEqual(lines, ["first", "猫", "last"]);
deepStrictEqual(closes, ["closed"]);

const interruptedLines: string[] = [];
const interruptedCloses: string[] = [];
const interrupted = new ReadableStream<Uint8Array>({
  pull(controller) {
    controller.error(new Error("synthetic stream interruption"));
  },
});
await readLines(interrupted, (line) => interruptedLines.push(line), () => interruptedCloses.push("closed"));
deepStrictEqual(interruptedLines, []);
deepStrictEqual(interruptedCloses, ["closed"]);
console.log("stream line reader: OK");
