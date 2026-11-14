import type { AgentSessionTheme } from "./types";

const cssVariables: Record<keyof AgentSessionTheme, string | null> = {
  isDark: null,
  pageBackground: "--agent-page-bg",
  surfaceBackground: "--agent-surface",
  surfaceElevatedBackground: "--agent-surface-elevated",
  inputBackground: "--agent-input-bg",
  border: "--agent-border",
  borderStrong: "--agent-border-strong",
  text: "--agent-text",
  mutedText: "--agent-muted",
  softText: "--agent-soft",
  accent: "--agent-accent",
  accentSoft: "--agent-accent-soft",
  danger: "--agent-danger",
  shadow: "--agent-shadow",
  terminalFontFamily: null,
  terminalFontSize: null,
};

export function applyAgentTheme(theme: AgentSessionTheme): void {
  if (typeof document === "undefined") {
    return;
  }
  const root = document.documentElement;
  root.dataset.theme = theme.isDark ? "dark" : "light";
  applyCodexDocumentMetadata();
  root.classList.toggle("dark", theme.isDark);
  root.classList.toggle("electron-dark", theme.isDark);
  root.classList.toggle("light", !theme.isDark);
  root.style.colorScheme = theme.isDark ? "dark" : "light";
  if (theme.terminalFontFamily && theme.terminalFontSize) {
    root.style.setProperty("--agent-terminal-font-family", `${JSON.stringify(theme.terminalFontFamily)}, monospace`);
    root.style.setProperty("--agent-terminal-font-size", `${theme.terminalFontSize}px`);
  } else {
    root.style.removeProperty("--agent-terminal-font-family");
    root.style.removeProperty("--agent-terminal-font-size");
  }
  for (const [key, variable] of Object.entries(cssVariables) as Array<
    [keyof AgentSessionTheme, string | null]
  >) {
    if (!variable) {
      continue;
    }
    root.style.setProperty(variable, String(theme[key]));
  }
}

export function applyCodexDocumentMetadata(): void {
  if (typeof document === "undefined") {
    return;
  }
  const root = document.documentElement;
  root.dataset.codexWindowType = "electron";
  root.dataset.windowType = "electron";
  root.dataset.codexOs = codexOs();
  if (document.body) {
    document.body.dataset.codexWindowType = "electron";
  }
}

function codexOs(): string {
  if (typeof navigator === "undefined") {
    return "unknown";
  }
  const maybeNavigator = navigator as Navigator & {
    userAgentData?: { platform?: string };
  };
  const platform = (
    maybeNavigator.userAgentData?.platform ??
    maybeNavigator.platform ??
    maybeNavigator.userAgent
  ).toLowerCase();
  if (platform.includes("win")) {
    return "win32";
  }
  if (platform.includes("mac") || platform.includes("darwin")) {
    return "darwin";
  }
  if (platform.includes("linux")) {
    return "linux";
  }
  return "unknown";
}
