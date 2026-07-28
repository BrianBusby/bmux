export type DroppedFilePayload = {
  dataUrl?: string;
  label: string;
  mimeType?: string;
  path?: string;
};

type DataTransferLike = {
  files?: Iterable<FileLike> | ArrayLike<FileLike>;
  getData?: (format: string) => string;
  items?: Iterable<{ kind?: string }> | ArrayLike<{ kind?: string }>;
  types?: Iterable<string> | ArrayLike<string>;
};

type FileLike = {
  name?: string;
  path?: string;
  size?: number;
  type?: string;
  webkitRelativePath?: string;
};

export function dataTransferHasFiles(dataTransfer: DataTransferLike | null | undefined): boolean {
  if (!dataTransfer) {
    return false;
  }
  if (dataTransfer.files && Array.from(dataTransfer.files).length > 0) {
    return true;
  }
  if (dataTransfer.items && Array.from(dataTransfer.items).some((item) => item.kind === "file")) {
    return true;
  }
  return Array.from(dataTransfer.types ?? []).some((type) =>
    type === "Files" || type === "public.file-url" || type === "text/uri-list"
  );
}

export async function droppedFilePayloadsFromDataTransfer(
  dataTransfer: DataTransferLike,
  readAsDataURL: (file: FileLike) => Promise<string> = readFileAsDataURL,
): Promise<DroppedFilePayload[]> {
  const files = Array.from(dataTransfer.files ?? []);
  const uriPaths = [
    ...filePathsFromURIList(dataTransfer.getData?.("text/uri-list") ?? ""),
    ...filePathsFromURIList(dataTransfer.getData?.("public.file-url") ?? ""),
  ];
  const payloads = await Promise.all(files.map(async (file, index): Promise<DroppedFilePayload> => {
    const path = pathFromDroppedFile(file) ?? uriPaths[index];
    if (path) {
      return {
        label: file.name || basename(path),
        mimeType: file.type || undefined,
        path,
      };
    }

    const dataUrl = await readAsDataURL(file);
    return {
      dataUrl,
      label: file.name || "dropped-file",
      mimeType: file.type || mimeTypeFromDataURL(dataUrl),
    };
  }));

  if (files.length === 0) {
    for (const path of uriPaths) {
      payloads.push({
        label: basename(path),
        path,
      });
    }
  }

  return payloads;
}

export function filePathsFromURIList(uriList: string): string[] {
  return uriList
    .split(/\r\n|\n|\r/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0 && !line.startsWith("#"))
    .flatMap((line) => {
      const path = pathFromFileURL(line);
      return path ? [path] : [];
    });
}

export function pathFromDroppedFile(file: FileLike): string | null {
  const directPath = typeof file.path === "string" && file.path.trim().length > 0 ? file.path.trim() : null;
  if (directPath) {
    return directPath;
  }
  return typeof file.webkitRelativePath === "string" && file.webkitRelativePath.startsWith("/")
    ? file.webkitRelativePath
    : null;
}

export function pathFromFileURL(value: string): string | null {
  try {
    const url = new URL(value);
    if (url.protocol !== "file:") {
      return null;
    }
    return decodeURIComponent(url.pathname);
  } catch {
    return null;
  }
}

function readFileAsDataURL(file: FileLike): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.addEventListener("load", () => {
      if (typeof reader.result === "string") {
        resolve(reader.result);
      } else {
        reject(new Error("Native bridge request failed."));
      }
    });
    reader.addEventListener("error", () => reject(reader.error ?? new Error("Native bridge request failed.")));
    reader.readAsDataURL(file as Blob);
  });
}

function mimeTypeFromDataURL(dataUrl: string): string | undefined {
  const match = /^data:([^;,]+)/.exec(dataUrl);
  return match?.[1];
}

function basename(path: string): string {
  const segments = path.split("/").filter(Boolean);
  return segments[segments.length - 1] ?? path;
}
