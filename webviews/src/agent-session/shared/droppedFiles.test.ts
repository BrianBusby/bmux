import { expect, test } from "bun:test";
import {
  dataTransferHasFiles,
  droppedFilePayloadsFromDataTransfer,
  filePathsFromURIList,
  pathFromDroppedFile,
  pathFromFileURL,
} from "./droppedFiles";

test("dataTransferHasFiles accepts native file drags", () => {
  expect(dataTransferHasFiles({ types: ["Files"] })).toBe(true);
  expect(dataTransferHasFiles({ items: [{ kind: "file" }] })).toBe(true);
  expect(dataTransferHasFiles({ types: ["text/plain"] })).toBe(false);
});

test("filePathsFromURIList extracts local file paths", () => {
  expect(filePathsFromURIList("# comment\nfile:///Users/me/Desktop/photo%201.png\nhttps://example.test/nope")).toEqual([
    "/Users/me/Desktop/photo 1.png",
  ]);
});

test("pathFromDroppedFile reads WebKit and Electron path fields", () => {
  expect(pathFromDroppedFile({ name: "a.png", path: "/tmp/a.png" })).toBe("/tmp/a.png");
  expect(pathFromDroppedFile({ name: "b.png", webkitRelativePath: "/tmp/b.png" })).toBe("/tmp/b.png");
  expect(pathFromDroppedFile({ name: "c.png", webkitRelativePath: "folder/c.png" })).toBe(null);
});

test("pathFromFileURL ignores non-file URLs", () => {
  expect(pathFromFileURL("file:///Users/me/Desktop/photo.png")).toBe("/Users/me/Desktop/photo.png");
  expect(pathFromFileURL("https://example.test/photo.png")).toBe(null);
});

test("droppedFilePayloadsFromDataTransfer prefers paths and materializes pathless files", async () => {
  const payloads = await droppedFilePayloadsFromDataTransfer(
    {
      files: [
        { name: "local.png", path: "/Users/me/local.png", type: "image/png" },
        { name: "pasted.png", type: "image/png" },
      ],
    },
    async () => "data:image/png;base64,AAAA",
  );

  expect(payloads).toEqual([
    { label: "local.png", mimeType: "image/png", path: "/Users/me/local.png" },
    { dataUrl: "data:image/png;base64,AAAA", label: "pasted.png", mimeType: "image/png" },
  ]);
});

test("droppedFilePayloadsFromDataTransfer accepts public file URLs", async () => {
  const payloads = await droppedFilePayloadsFromDataTransfer({
    files: [{ name: "photo.png", type: "image/png" }],
    getData: (format) => (format === "public.file-url" ? "file:///Users/me/Desktop/photo.png" : ""),
  });

  expect(payloads).toEqual([
    { label: "photo.png", mimeType: "image/png", path: "/Users/me/Desktop/photo.png" },
  ]);
});
