export const comparePages = [
  {
    slug: "best-terminal-for-ai-coding-agents",
    key: "bestTerminalForAgents",
    lastModified: "2026-07-04",
  },
  {
    slug: "bmux-vs-alacritty",
    key: "bmuxVsAlacritty",
    lastModified: "2026-07-04",
  },
  {
    slug: "bmux-vs-conductor",
    key: "bmuxVsConductor",
    lastModified: "2026-07-04",
  },
  {
    slug: "bmux-vs-cursor",
    key: "bmuxVsCursor",
    lastModified: "2026-07-04",
  },
  {
    slug: "bmux-vs-devin",
    key: "bmuxVsDevin",
    lastModified: "2026-07-04",
  },
  {
    slug: "bmux-vs-ghostty",
    key: "bmuxVsGhostty",
    lastModified: "2026-07-04",
  },
  {
    slug: "bmux-vs-herdr",
    key: "bmuxVsHerdr",
    lastModified: "2026-07-04",
  },
  {
    slug: "bmux-vs-iterm2",
    key: "bmuxVsIterm2",
    lastModified: "2026-07-04",
  },
  {
    slug: "bmux-vs-kitty",
    key: "bmuxVsKitty",
    lastModified: "2026-07-04",
  },
  {
    slug: "bmux-vs-opencode",
    key: "bmuxVsOpencode",
    lastModified: "2026-07-04",
  },
  {
    slug: "bmux-vs-superset",
    key: "bmuxVsSuperset",
    lastModified: "2026-07-04",
  },
  {
    slug: "bmux-vs-tmux",
    key: "bmuxVsTmux",
    lastModified: "2026-07-04",
  },
  {
    slug: "bmux-vs-vscode",
    key: "bmuxVsVscode",
    lastModified: "2026-07-04",
  },
  {
    slug: "bmux-vs-warp",
    key: "bmuxVsWarp",
    lastModified: "2026-07-04",
  },
  {
    slug: "bmux-vs-wezterm",
    key: "bmuxVsWezterm",
    lastModified: "2026-07-04",
  },
  {
    slug: "bmux-vs-windsurf",
    key: "bmuxVsWindsurf",
    lastModified: "2026-07-04",
  },
  {
    slug: "bmux-vs-zed",
    key: "bmuxVsZed",
    lastModified: "2026-07-04",
  },
  {
    slug: "multiple-claude-code-agents-parallel",
    key: "multipleClaudeAgents",
    lastModified: "2026-07-04",
  },
] as const;

export type ComparePage = (typeof comparePages)[number];
export type ComparePageKey = ComparePage["key"];

export function comparePath(slug: string) {
  return `/compare/${slug}`;
}

export function comparePageForSlug(slug: string): ComparePage | undefined {
  return comparePages.find((page) => page.slug === slug);
}
