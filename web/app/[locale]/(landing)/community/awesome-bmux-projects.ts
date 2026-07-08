export type AwesomeBmuxProject = {
  name: string;
  url: string;
  agent?: string;
  descriptionKey: string;
  language?: string;
  stars?: number;
  categories: readonly string[];
};

export const awesomeBmuxSourceUrl = "https://github.com/manaflow-ai/awesome-bmux";
export const awesomeBmuxCuratedProjectRows = 150;

export const awesomeBmuxCategoryOrder = [
  "Sidebar & Status Pills",
  "Progress Bars & Estimation",
  "Sidebar Logs & Activity Feed",
  "Desktop Notifications",
  "Multi-Agent Orchestration",
  "Browser Automation",
  "Worktrees & Workspace Management",
  "Monitoring & Session Restore",
  "Remote & Mobile Access",
  "Themes, Layouts & Config",
  "Claude Code",
  "Pi",
  "OpenCode",
  "Copilot & Amp",
  "Multi-Agent / Agent-Agnostic",
  "Build & Distribution"
] as const;

export const awesomeBmuxProjects = [
  {
    "name": "Yeachan-Heo/oh-my-claudecode",
    "url": "https://github.com/Yeachan-Heo/oh-my-claudecode",
    "agent": "Claude Code",
    "descriptionKey": "p001",
    "language": "TypeScript",
    "stars": 32659,
    "categories": [
      "Multi-Agent Orchestration",
      "Sidebar Logs & Activity Feed",
      "Claude Code"
    ]
  },
  {
    "name": "kdcokenny/opencode-worktree",
    "url": "https://github.com/kdcokenny/opencode-worktree",
    "agent": "OpenCode",
    "descriptionKey": "p002",
    "language": "TypeScript",
    "stars": 504,
    "categories": [
      "Worktrees & Workspace Management",
      "OpenCode"
    ]
  },
  {
    "name": "HazAT/pi-interactive-subagents",
    "url": "https://github.com/HazAT/pi-interactive-subagents",
    "agent": "Multi",
    "descriptionKey": "p003",
    "language": "TypeScript",
    "stars": 429,
    "categories": [
      "Progress Bars & Estimation",
      "Multi-Agent Orchestration",
      "Monitoring & Session Restore",
      "Pi",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "kdcokenny/opencode-workspace",
    "url": "https://github.com/kdcokenny/opencode-workspace",
    "agent": "OpenCode",
    "descriptionKey": "p004",
    "language": "TypeScript",
    "stars": 402,
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Worktrees & Workspace Management",
      "OpenCode"
    ]
  },
  {
    "name": "aannoo/hcom",
    "url": "https://github.com/aannoo/hcom",
    "agent": "Multi",
    "descriptionKey": "p005",
    "language": "Rust",
    "stars": 252,
    "categories": [
      "Multi-Agent Orchestration",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "kdcokenny/opencode-notify",
    "url": "https://github.com/kdcokenny/opencode-notify",
    "agent": "OpenCode",
    "descriptionKey": "p006",
    "language": "TypeScript",
    "stars": 184,
    "categories": [
      "Desktop Notifications",
      "OpenCode"
    ]
  },
  {
    "name": "espennilsen/pi",
    "url": "https://github.com/espennilsen/pi",
    "agent": "Pi",
    "descriptionKey": "p007",
    "language": "TypeScript",
    "stars": 102,
    "categories": [
      "Sidebar & Status Pills",
      "Multi-Agent Orchestration",
      "Pi"
    ]
  },
  {
    "name": "w-winter/dot314",
    "url": "https://github.com/w-winter/dot314",
    "agent": "Pi",
    "descriptionKey": "p008",
    "language": "TypeScript",
    "stars": 95,
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Multi-Agent Orchestration",
      "Pi"
    ]
  },
  {
    "name": "burggraf/pi-teams",
    "url": "https://github.com/burggraf/pi-teams",
    "agent": "Pi",
    "descriptionKey": "p009",
    "language": "TypeScript",
    "stars": 91,
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Pi"
    ]
  },
  {
    "name": "0xCaso/opencode-bmux",
    "url": "https://github.com/0xCaso/opencode-bmux",
    "agent": "OpenCode",
    "descriptionKey": "p010",
    "language": "TypeScript",
    "stars": 42,
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Desktop Notifications",
      "OpenCode"
    ]
  },
  {
    "name": "hummer98/using-bmux",
    "url": "https://github.com/hummer98/using-bmux",
    "agent": "Claude Code",
    "descriptionKey": "p011",
    "language": "Shell",
    "stars": 33,
    "categories": [
      "Progress Bars & Estimation",
      "Desktop Notifications",
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "drolosoft/bmux-resurrect",
    "url": "https://github.com/drolosoft/bmux-resurrect",
    "descriptionKey": "p012",
    "language": "Go",
    "stars": 31,
    "categories": [
      "Monitoring & Session Restore",
      "Themes, Layouts & Config"
    ]
  },
  {
    "name": "AtAFork/ghostty-claude-code-session-restore",
    "url": "https://github.com/AtAFork/ghostty-claude-code-session-restore",
    "agent": "Claude Code",
    "descriptionKey": "p013",
    "language": "Python",
    "stars": 23,
    "categories": [
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "azu/bmux-hub",
    "url": "https://github.com/azu/bmux-hub",
    "agent": "Claude Code",
    "descriptionKey": "p014",
    "language": "TypeScript",
    "stars": 23,
    "categories": [
      "Sidebar & Status Pills",
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "untra/operator",
    "url": "https://github.com/untra/operator",
    "agent": "Multi",
    "descriptionKey": "p015",
    "language": "Rust",
    "stars": 17,
    "categories": [
      "Multi-Agent Orchestration",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "javiermolinar/pi-bmux",
    "url": "https://github.com/javiermolinar/pi-bmux",
    "agent": "Pi",
    "descriptionKey": "p016",
    "language": "TypeScript",
    "stars": 16,
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Desktop Notifications",
      "Browser Automation",
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config",
      "Pi"
    ]
  },
  {
    "name": "gonzaloserrano/streamdeck-bmux",
    "url": "https://github.com/gonzaloserrano/streamdeck-bmux",
    "descriptionKey": "p017",
    "language": "TypeScript",
    "stars": 14,
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Monitoring & Session Restore"
    ]
  },
  {
    "name": "sasha-computer/pi-bmux",
    "url": "https://github.com/sasha-computer/pi-bmux",
    "agent": "Pi",
    "descriptionKey": "p018",
    "language": "TypeScript",
    "stars": 14,
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Browser Automation",
      "Pi"
    ]
  },
  {
    "name": "hummer98/bmux-team",
    "url": "https://github.com/hummer98/bmux-team",
    "agent": "Claude Code",
    "descriptionKey": "p019",
    "language": "TypeScript",
    "stars": 10,
    "categories": [
      "Progress Bars & Estimation",
      "Multi-Agent Orchestration",
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "joelhooks/pi-bmux",
    "url": "https://github.com/joelhooks/pi-bmux",
    "agent": "Pi",
    "descriptionKey": "p020",
    "language": "TypeScript",
    "stars": 10,
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Multi-Agent Orchestration",
      "Pi"
    ]
  },
  {
    "name": "jasonraz/bmux-browser-mcp",
    "url": "https://github.com/jasonraz/bmux-browser-mcp",
    "agent": "Claude Code",
    "descriptionKey": "p021",
    "language": "JavaScript",
    "stars": 8,
    "categories": [
      "Browser Automation",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "darkspock/bmux-skill",
    "url": "https://github.com/darkspock/bmux-skill",
    "agent": "Multi",
    "descriptionKey": "p022",
    "language": "Markdown",
    "stars": 7,
    "categories": [
      "Browser Automation",
      "Claude Code",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "yigitkonur/bmux-claude-pro",
    "url": "https://github.com/yigitkonur/bmux-claude-pro",
    "agent": "Claude Code",
    "descriptionKey": "p023",
    "language": "TypeScript",
    "stars": 7,
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Desktop Notifications",
      "Claude Code"
    ]
  },
  {
    "name": "hummer98/bmux-remote",
    "url": "https://github.com/hummer98/bmux-remote",
    "descriptionKey": "p024",
    "language": "TypeScript",
    "stars": 6,
    "categories": [
      "Remote & Mobile Access"
    ]
  },
  {
    "name": "mikasalikh/bmux-wf",
    "url": "https://github.com/mikasalikh/bmux-wf",
    "agent": "Claude Code",
    "descriptionKey": "p025",
    "language": "Shell",
    "stars": 6,
    "categories": [
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "EtanHey/bmuxlayer",
    "url": "https://github.com/EtanHey/bmuxlayer",
    "agent": "Multi",
    "descriptionKey": "p026",
    "language": "TypeScript",
    "stars": 5,
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "itsmaleen/bmux-companion",
    "url": "https://github.com/itsmaleen/bmux-companion",
    "descriptionKey": "p027",
    "language": "Go / Swift",
    "stars": 5,
    "categories": [
      "Desktop Notifications",
      "Remote & Mobile Access"
    ]
  },
  {
    "name": "monzou/mo-bmux",
    "url": "https://github.com/monzou/mo-bmux",
    "agent": "Claude Code",
    "descriptionKey": "p028",
    "language": "Shell",
    "stars": 5,
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "ttalkkag/bmux-agent",
    "url": "https://github.com/ttalkkag/bmux-agent",
    "agent": "Multi",
    "descriptionKey": "p029",
    "language": "Python",
    "stars": 5,
    "categories": [
      "Multi-Agent Orchestration",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "0xNekr/bmux-bus",
    "url": "https://github.com/0xNekr/bmux-bus",
    "agent": "Multi",
    "descriptionKey": "p030",
    "language": "Shell",
    "categories": [
      "Multi-Agent Orchestration",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "alaasdk/bmux-ctl",
    "url": "https://github.com/alaasdk/bmux-ctl",
    "agent": "Claude Code",
    "descriptionKey": "p031",
    "language": "Python",
    "categories": [
      "Multi-Agent Orchestration",
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "albertlieyingadrian/bmux-multiplexer",
    "url": "https://github.com/albertlieyingadrian/bmux-multiplexer",
    "agent": "Claude Code",
    "descriptionKey": "p032",
    "language": "Python",
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Claude Code"
    ]
  },
  {
    "name": "alevental/cccp",
    "url": "https://github.com/alevental/cccp",
    "agent": "Claude Code",
    "descriptionKey": "p033",
    "language": "TypeScript",
    "categories": [
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "anhoder/homebrew-repo",
    "url": "https://github.com/anhoder/homebrew-repo",
    "descriptionKey": "p034",
    "language": "Ruby",
    "categories": [
      "Build & Distribution"
    ]
  },
  {
    "name": "aschreifels/cwt",
    "url": "https://github.com/aschreifels/cwt",
    "agent": "Claude Code",
    "descriptionKey": "p035",
    "language": "Go",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Desktop Notifications",
      "Worktrees & Workspace Management",
      "Claude Code"
    ]
  },
  {
    "name": "Attamusc/copilot-bmux",
    "url": "https://github.com/Attamusc/copilot-bmux",
    "agent": "Copilot",
    "descriptionKey": "p036",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Desktop Notifications",
      "Copilot & Amp"
    ]
  },
  {
    "name": "Attamusc/opencode-bmux",
    "url": "https://github.com/Attamusc/opencode-bmux",
    "agent": "OpenCode",
    "descriptionKey": "p037",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Desktop Notifications",
      "OpenCode"
    ]
  },
  {
    "name": "Attamusc/pi-bmux",
    "url": "https://github.com/Attamusc/pi-bmux",
    "agent": "Pi",
    "descriptionKey": "p038",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Desktop Notifications",
      "Pi"
    ]
  },
  {
    "name": "baixianger/claude-orchestration-in-bmux",
    "url": "https://github.com/baixianger/claude-orchestration-in-bmux",
    "agent": "Claude Code",
    "descriptionKey": "p039",
    "language": "Markdown",
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Claude Code"
    ]
  },
  {
    "name": "basedcorp99/claude-worktree-zsh",
    "url": "https://github.com/basedcorp99/claude-worktree-zsh",
    "agent": "Multi",
    "descriptionKey": "p040",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "bhandeland/fleet",
    "url": "https://github.com/bhandeland/fleet",
    "agent": "Claude Code",
    "descriptionKey": "p041",
    "language": "Shell",
    "categories": [
      "Worktrees & Workspace Management",
      "Claude Code"
    ]
  },
  {
    "name": "bjacobso/pimux",
    "url": "https://github.com/bjacobso/pimux",
    "agent": "Pi",
    "descriptionKey": "p042",
    "language": "TypeScript",
    "categories": [
      "Desktop Notifications",
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Pi"
    ]
  },
  {
    "name": "block/bmux-amp",
    "url": "https://github.com/block/bmux-amp",
    "agent": "Amp",
    "descriptionKey": "p043",
    "language": "TypeScript",
    "categories": [
      "Desktop Notifications",
      "Monitoring & Session Restore",
      "Copilot & Amp"
    ]
  },
  {
    "name": "bocktae80/bmux-pilot",
    "url": "https://github.com/bocktae80/bmux-pilot",
    "agent": "Claude Code",
    "descriptionKey": "p044",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Multi-Agent Orchestration",
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "budah1987/bmux-script",
    "url": "https://github.com/budah1987/bmux-script",
    "agent": "Claude Code",
    "descriptionKey": "p045",
    "language": "Shell",
    "categories": [
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "budah1987/homebrew-tools",
    "url": "https://github.com/budah1987/homebrew-tools",
    "agent": "Claude Code",
    "descriptionKey": "p046",
    "language": "Ruby",
    "categories": [
      "Themes, Layouts & Config",
      "Claude Code",
      "Build & Distribution"
    ]
  },
  {
    "name": "chsm04/bmux-tower",
    "url": "https://github.com/chsm04/bmux-tower",
    "agent": "Claude Code",
    "descriptionKey": "p047",
    "language": "Shell",
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "dd7200/pomo-tui",
    "url": "https://github.com/dd7200/pomo-tui",
    "descriptionKey": "p048",
    "language": "Go",
    "categories": [
      "Desktop Notifications"
    ]
  },
  {
    "name": "dmallory42/pi-bmux",
    "url": "https://github.com/dmallory42/pi-bmux",
    "agent": "Pi",
    "descriptionKey": "p049",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Desktop Notifications",
      "Browser Automation",
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config",
      "Pi"
    ]
  },
  {
    "name": "dongsik93/crosstalk",
    "url": "https://github.com/dongsik93/crosstalk",
    "agent": "Multi",
    "descriptionKey": "p050",
    "language": "Shell",
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "doublezz10/figure-viewer",
    "url": "https://github.com/doublezz10/figure-viewer",
    "agent": "OpenCode",
    "descriptionKey": "p051",
    "language": "JavaScript",
    "categories": [
      "Browser Automation"
    ]
  },
  {
    "name": "earchibald/bmux-layout",
    "url": "https://github.com/earchibald/bmux-layout",
    "descriptionKey": "p052",
    "language": "Swift",
    "categories": [
      "Themes, Layouts & Config"
    ]
  },
  {
    "name": "eduwass/cru",
    "url": "https://github.com/eduwass/cru",
    "agent": "Claude Code",
    "descriptionKey": "p053",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "ensarkovankaya/bmux-mirror",
    "url": "https://github.com/ensarkovankaya/bmux-mirror",
    "descriptionKey": "p054",
    "language": "Python",
    "categories": [
      "Monitoring & Session Restore",
      "Remote & Mobile Access"
    ]
  },
  {
    "name": "erikhazzard/bmux-remote",
    "url": "https://github.com/erikhazzard/bmux-remote",
    "descriptionKey": "p055",
    "language": "TypeScript",
    "categories": [
      "Remote & Mobile Access"
    ]
  },
  {
    "name": "eunjae-lee/bmux-worktree",
    "url": "https://github.com/eunjae-lee/bmux-worktree",
    "descriptionKey": "p056",
    "language": "TypeScript",
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config"
    ]
  },
  {
    "name": "EverybodyBusiness/bmux-browser-first",
    "url": "https://github.com/EverybodyBusiness/bmux-browser-first",
    "agent": "Claude Code",
    "descriptionKey": "p057",
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "goddaehee/bmux-claude-skill",
    "url": "https://github.com/goddaehee/bmux-claude-skill",
    "agent": "Claude Code",
    "descriptionKey": "p058",
    "language": "Markdown",
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "gomipapa/bmux-sidecar",
    "url": "https://github.com/gomipapa/bmux-sidecar",
    "agent": "Multi",
    "descriptionKey": "p059",
    "language": "Shell",
    "categories": [
      "Browser Automation",
      "Themes, Layouts & Config",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "halindrome/bmux-tmux-mapping-for-cc",
    "url": "https://github.com/halindrome/bmux-tmux-mapping-for-cc",
    "agent": "Claude Code",
    "descriptionKey": "p060",
    "language": "Shell",
    "categories": [
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "hashangit/bmux-skill",
    "url": "https://github.com/hashangit/bmux-skill",
    "agent": "Claude Code",
    "descriptionKey": "p061",
    "language": "Shell",
    "categories": [
      "Desktop Notifications",
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "hoonkim/bmux-skills-plugin",
    "url": "https://github.com/hoonkim/bmux-skills-plugin",
    "agent": "Claude Code",
    "descriptionKey": "p062",
    "language": "Markdown",
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "hopchouinard/bmux-plugin",
    "url": "https://github.com/hopchouinard/bmux-plugin",
    "agent": "Claude Code",
    "descriptionKey": "p063",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Desktop Notifications",
      "Browser Automation",
      "Worktrees & Workspace Management",
      "Claude Code"
    ]
  },
  {
    "name": "Islanders-Treasure0969/claude-pilot",
    "url": "https://github.com/Islanders-Treasure0969/claude-pilot",
    "agent": "Claude Code",
    "descriptionKey": "p064",
    "language": "JavaScript",
    "categories": [
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "JacianLiu/bmux-claude-session",
    "url": "https://github.com/JacianLiu/bmux-claude-session",
    "agent": "Claude Code",
    "descriptionKey": "p065",
    "language": "Shell",
    "categories": [
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "jacobtellep/bmux-setup",
    "url": "https://github.com/jacobtellep/bmux-setup",
    "agent": "Claude Code",
    "descriptionKey": "p066",
    "language": "Shell",
    "categories": [
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "jaequery/bmux-diff",
    "url": "https://github.com/jaequery/bmux-diff",
    "agent": "Claude Code",
    "descriptionKey": "p067",
    "language": "TypeScript",
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "jhta/bmux-skill",
    "url": "https://github.com/jhta/bmux-skill",
    "agent": "Claude Code",
    "descriptionKey": "p068",
    "language": "Shell",
    "categories": [
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "Joehoel/opencode-bmux",
    "url": "https://github.com/Joehoel/opencode-bmux",
    "agent": "OpenCode",
    "descriptionKey": "p069",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Desktop Notifications",
      "OpenCode"
    ]
  },
  {
    "name": "KyleJamesWalker/cc-bmux-plugin",
    "url": "https://github.com/KyleJamesWalker/cc-bmux-plugin",
    "agent": "Claude Code",
    "descriptionKey": "p070",
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "KyubumShin/bmux-skills",
    "url": "https://github.com/KyubumShin/bmux-skills",
    "agent": "Claude Code",
    "descriptionKey": "p071",
    "language": "JavaScript",
    "categories": [
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "LattyCat/bmux-workspace",
    "url": "https://github.com/LattyCat/bmux-workspace",
    "agent": "Multi",
    "descriptionKey": "p072",
    "language": "Shell",
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "lawrencecchen/bmux-proxy",
    "url": "https://github.com/lawrencecchen/bmux-proxy",
    "descriptionKey": "p073",
    "language": "Rust",
    "categories": [
      "Remote & Mobile Access"
    ]
  },
  {
    "name": "Lumiwealth/bmux-agent-recovery",
    "url": "https://github.com/Lumiwealth/bmux-agent-recovery",
    "agent": "Multi",
    "descriptionKey": "p074",
    "language": "Python",
    "categories": [
      "Monitoring & Session Restore",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "madlouse/homebrew-ghostty",
    "url": "https://github.com/madlouse/homebrew-ghostty",
    "descriptionKey": "p075",
    "language": "Ruby",
    "categories": [
      "Build & Distribution"
    ]
  },
  {
    "name": "manaflow-ai/chromium",
    "url": "https://github.com/manaflow-ai/chromium",
    "descriptionKey": "p076",
    "language": "Obj-C++",
    "categories": [
      "Build & Distribution"
    ]
  },
  {
    "name": "manaflow-ai/bmux-skills",
    "url": "https://github.com/manaflow-ai/bmux-skills",
    "agent": "Multi",
    "descriptionKey": "p077",
    "language": "Python",
    "categories": [
      "Multi-Agent Orchestration",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "manaflow-ai/homebrew-bmux",
    "url": "https://github.com/manaflow-ai/homebrew-bmux",
    "descriptionKey": "p078",
    "language": "Ruby",
    "categories": [
      "Build & Distribution"
    ]
  },
  {
    "name": "mangledmonkey/bmux-skills",
    "url": "https://github.com/mangledmonkey/bmux-skills",
    "agent": "Claude Code",
    "descriptionKey": "p079",
    "language": "Shell",
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "mangledmonkey/devmux",
    "url": "https://github.com/mangledmonkey/devmux",
    "agent": "Claude Code",
    "descriptionKey": "p080",
    "language": "Shell",
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Claude Code"
    ]
  },
  {
    "name": "Marmalade118/gsd-wmux",
    "url": "https://github.com/Marmalade118/gsd-wmux",
    "agent": "Pi",
    "descriptionKey": "p081",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Desktop Notifications",
      "Themes, Layouts & Config",
      "Pi"
    ]
  },
  {
    "name": "mastertyko/pi-bmux-preview",
    "url": "https://github.com/mastertyko/pi-bmux-preview",
    "agent": "Pi",
    "descriptionKey": "p082",
    "language": "TypeScript",
    "categories": [
      "Browser Automation",
      "Pi"
    ]
  },
  {
    "name": "mateusduraes/ramo",
    "url": "https://github.com/mateusduraes/ramo",
    "descriptionKey": "p083",
    "language": "Go",
    "categories": [
      "Worktrees & Workspace Management"
    ]
  },
  {
    "name": "meengi07/bmux-agent-observer-skill",
    "url": "https://github.com/meengi07/bmux-agent-observer-skill",
    "agent": "Multi",
    "descriptionKey": "p084",
    "language": "Shell",
    "categories": [
      "Multi-Agent Orchestration",
      "Monitoring & Session Restore",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "Michael-Z-Freeman/antigravity-bmux-notify",
    "url": "https://github.com/Michael-Z-Freeman/antigravity-bmux-notify",
    "agent": "Antigravity",
    "descriptionKey": "p085",
    "language": "Shell",
    "categories": [
      "Desktop Notifications",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "mikecfisher/bmux-skill",
    "url": "https://github.com/mikecfisher/bmux-skill",
    "agent": "Claude Code",
    "descriptionKey": "p086",
    "language": "Markdown",
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "Minoo7/bmux-hooks",
    "url": "https://github.com/Minoo7/bmux-hooks",
    "agent": "Multi",
    "descriptionKey": "p087",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Monitoring & Session Restore",
      "Remote & Mobile Access",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "miraoto/bmux-cheatsheet",
    "url": "https://github.com/miraoto/bmux-cheatsheet",
    "descriptionKey": "p088",
    "language": "Shell",
    "categories": [
      "Themes, Layouts & Config"
    ]
  },
  {
    "name": "Mirksen/bmux-toolkit",
    "url": "https://github.com/Mirksen/bmux-toolkit",
    "agent": "Claude Code",
    "descriptionKey": "p089",
    "language": "Shell",
    "categories": [
      "Browser Automation",
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "morrisclay/ws",
    "url": "https://github.com/morrisclay/ws",
    "agent": "Claude Code",
    "descriptionKey": "p090",
    "language": "Shell",
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "mspiegel31/opencode-bmux",
    "url": "https://github.com/mspiegel31/opencode-bmux",
    "agent": "OpenCode",
    "descriptionKey": "p091",
    "language": "TypeScript",
    "categories": [
      "Desktop Notifications",
      "Browser Automation",
      "OpenCode"
    ]
  },
  {
    "name": "multiagentcognition/bmux-agent-mcp",
    "url": "https://github.com/multiagentcognition/bmux-agent-mcp",
    "agent": "Multi",
    "descriptionKey": "p092",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "n-filatov/bmux-workspace",
    "url": "https://github.com/n-filatov/bmux-workspace",
    "agent": "Multi",
    "descriptionKey": "p093",
    "language": "TypeScript",
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "NewTurn2017/bmux-remote",
    "url": "https://github.com/NewTurn2017/bmux-remote",
    "agent": "Multi",
    "descriptionKey": "p094",
    "language": "Swift",
    "categories": [
      "Remote & Mobile Access",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "niaeee/bmux_skill",
    "url": "https://github.com/niaeee/bmux_skill",
    "agent": "Claude Code",
    "descriptionKey": "p095",
    "categories": [
      "Sidebar & Status Pills",
      "Multi-Agent Orchestration",
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "ogallotti/bmux-tmux-shim",
    "url": "https://github.com/ogallotti/bmux-tmux-shim",
    "agent": "Claude Code",
    "descriptionKey": "p096",
    "language": "Shell",
    "categories": [
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "owizdom/context-brdige-for-bmux",
    "url": "https://github.com/owizdom/context-brdige-for-bmux",
    "agent": "Multi",
    "descriptionKey": "p097",
    "language": "Go",
    "categories": [
      "Multi-Agent Orchestration",
      "Monitoring & Session Restore",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "pallidev/bmux-relay",
    "url": "https://github.com/pallidev/bmux-relay",
    "agent": "Multi",
    "descriptionKey": "p098",
    "language": "TypeScript",
    "categories": [
      "Remote & Mobile Access",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "rappdw/zen-term",
    "url": "https://github.com/rappdw/zen-term",
    "agent": "Claude Code",
    "descriptionKey": "p099",
    "language": "Shell",
    "categories": [
      "Desktop Notifications",
      "Remote & Mobile Access",
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "richardhowes/bmux-jump",
    "url": "https://github.com/richardhowes/bmux-jump",
    "descriptionKey": "p100",
    "language": "Shell",
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config"
    ]
  },
  {
    "name": "richardhowes/bmux-mobile",
    "url": "https://github.com/richardhowes/bmux-mobile",
    "descriptionKey": "p101",
    "language": "TypeScript",
    "categories": [
      "Desktop Notifications",
      "Remote & Mobile Access"
    ]
  },
  {
    "name": "Ridgeio/swarm",
    "url": "https://github.com/Ridgeio/swarm",
    "agent": "Multi",
    "descriptionKey": "p102",
    "language": "TypeScript",
    "categories": [
      "Multi-Agent Orchestration",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "flotilla-org/flotilla",
    "url": "https://github.com/flotilla-org/flotilla",
    "agent": "Multi",
    "descriptionKey": "p103",
    "language": "Rust",
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Monitoring & Session Restore",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "RyoHirota68/bmux-pencil-preview",
    "url": "https://github.com/RyoHirota68/bmux-pencil-preview",
    "agent": "Claude Code",
    "descriptionKey": "p104",
    "language": "Shell",
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "RyoHirota68/difit-bmux",
    "url": "https://github.com/RyoHirota68/difit-bmux",
    "agent": "Claude Code",
    "descriptionKey": "p105",
    "language": "Shell",
    "categories": [
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "sanurb/pi-bmux",
    "url": "https://github.com/sanurb/pi-bmux",
    "agent": "Pi",
    "descriptionKey": "p106",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Pi"
    ]
  },
  {
    "name": "sanurb/pi-bmux-browser",
    "url": "https://github.com/sanurb/pi-bmux-browser",
    "agent": "Pi",
    "descriptionKey": "p107",
    "language": "TypeScript",
    "categories": [
      "Browser Automation",
      "Pi"
    ]
  },
  {
    "name": "sanurb/pi-bmux-workflows",
    "url": "https://github.com/sanurb/pi-bmux-workflows",
    "agent": "Pi",
    "descriptionKey": "p108",
    "language": "TypeScript",
    "categories": [
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Pi"
    ]
  },
  {
    "name": "sdgranger/will-public-claude",
    "url": "https://github.com/sdgranger/will-public-claude",
    "agent": "Claude Code",
    "descriptionKey": "p109",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "Seungwoo321/bmux-setup",
    "url": "https://github.com/Seungwoo321/bmux-setup",
    "descriptionKey": "p110",
    "language": "TypeScript",
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config"
    ]
  },
  {
    "name": "simonjohansson/pi-bmux",
    "url": "https://github.com/simonjohansson/pi-bmux",
    "agent": "Pi",
    "descriptionKey": "p111",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Sidebar Logs & Activity Feed",
      "Pi"
    ]
  },
  {
    "name": "Stealinglight/bmux-claude-code-skill",
    "url": "https://github.com/Stealinglight/bmux-claude-code-skill",
    "agent": "Claude Code",
    "descriptionKey": "p112",
    "language": "Shell",
    "categories": [
      "Browser Automation",
      "Worktrees & Workspace Management",
      "Claude Code"
    ]
  },
  {
    "name": "stegmannb/pi-agent-bmux",
    "url": "https://github.com/stegmannb/pi-agent-bmux",
    "agent": "Pi",
    "descriptionKey": "p113",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Pi"
    ]
  },
  {
    "name": "stevenocchipinti/raycast-bmux",
    "url": "https://github.com/stevenocchipinti/raycast-bmux",
    "descriptionKey": "p114",
    "language": "TypeScript",
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config"
    ]
  },
  {
    "name": "storelayer/pi-bmux-browser",
    "url": "https://github.com/storelayer/pi-bmux-browser",
    "agent": "Pi",
    "descriptionKey": "p115",
    "language": "JavaScript",
    "categories": [
      "Browser Automation",
      "Pi"
    ]
  },
  {
    "name": "STRML/bmux-restore",
    "url": "https://github.com/STRML/bmux-restore",
    "agent": "Claude Code",
    "descriptionKey": "p116",
    "language": "Shell",
    "categories": [
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "tadashi-aikawa/copilot-plugin-notify",
    "url": "https://github.com/tadashi-aikawa/copilot-plugin-notify",
    "agent": "Copilot",
    "descriptionKey": "p117",
    "language": "Shell",
    "categories": [
      "Desktop Notifications",
      "Copilot & Amp"
    ]
  },
  {
    "name": "taichiiwamoto-s/bmux-context",
    "url": "https://github.com/taichiiwamoto-s/bmux-context",
    "agent": "Claude Code",
    "descriptionKey": "p118",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "take0x/bmux-skills",
    "url": "https://github.com/take0x/bmux-skills",
    "agent": "Claude Code",
    "descriptionKey": "p119",
    "language": "Shell",
    "categories": [
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "tasuku43/kra",
    "url": "https://github.com/tasuku43/kra",
    "descriptionKey": "p120",
    "language": "Go",
    "categories": [
      "Worktrees & Workspace Management"
    ]
  },
  {
    "name": "Th3Sp3ct3R/bmux-claude-agents",
    "url": "https://github.com/Th3Sp3ct3R/bmux-claude-agents",
    "agent": "Claude Code",
    "descriptionKey": "p121",
    "language": "Shell",
    "categories": [
      "Desktop Notifications",
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "theodaguier/wt",
    "url": "https://github.com/theodaguier/wt",
    "agent": "Claude Code",
    "descriptionKey": "p122",
    "language": "Shell",
    "categories": [
      "Worktrees & Workspace Management",
      "Claude Code"
    ]
  },
  {
    "name": "TimoKruth/bmux-t3code",
    "url": "https://github.com/TimoKruth/bmux-t3code",
    "agent": "Multi",
    "descriptionKey": "p123",
    "categories": [
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Worktrees & Workspace Management",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "tslateman/bmux-claude-code",
    "url": "https://github.com/tslateman/bmux-claude-code",
    "agent": "Claude Code",
    "descriptionKey": "p124",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Desktop Notifications",
      "Claude Code"
    ]
  },
  {
    "name": "tully-8888/opencode-bmux-notify-plugin",
    "url": "https://github.com/tully-8888/opencode-bmux-notify-plugin",
    "agent": "OpenCode",
    "descriptionKey": "p125",
    "language": "Shell",
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "OpenCode"
    ]
  },
  {
    "name": "umitaltintas/bmux-agent-toolkit",
    "url": "https://github.com/umitaltintas/bmux-agent-toolkit",
    "agent": "Claude Code",
    "descriptionKey": "p126",
    "language": "Markdown",
    "categories": [
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "wangyuxinwhy/agent-skills",
    "url": "https://github.com/wangyuxinwhy/agent-skills",
    "agent": "Multi",
    "descriptionKey": "p127",
    "categories": [
      "Multi-Agent Orchestration",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "webkaz/bmux-intel-builds",
    "url": "https://github.com/webkaz/bmux-intel-builds",
    "descriptionKey": "p128",
    "categories": [
      "Build & Distribution"
    ]
  },
  {
    "name": "wwaIII/proj",
    "url": "https://github.com/wwaIII/proj",
    "agent": "Claude Code",
    "descriptionKey": "p129",
    "language": "Rust",
    "categories": [
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "ygrec-app/offload-task-skill",
    "url": "https://github.com/ygrec-app/offload-task-skill",
    "agent": "Claude Code",
    "descriptionKey": "p130",
    "language": "Markdown",
    "categories": [
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "ygrec-app/supreme-leader-skill",
    "url": "https://github.com/ygrec-app/supreme-leader-skill",
    "agent": "Claude Code",
    "descriptionKey": "p131",
    "language": "Markdown",
    "categories": [
      "Multi-Agent Orchestration",
      "Claude Code"
    ]
  },
  {
    "name": "feritzcan2/termloop",
    "url": "https://github.com/feritzcan2/termloop",
    "agent": "Multi",
    "descriptionKey": "p132",
    "language": "Swift",
    "stars": 29,
    "categories": [
      "Build & Distribution",
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Remote & Mobile Access",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "sanghun0724/bmux-claude-skills",
    "url": "https://github.com/sanghun0724/bmux-claude-skills",
    "agent": "Claude Code",
    "descriptionKey": "p133",
    "language": "Python",
    "stars": 28,
    "categories": [
      "Browser Automation",
      "Monitoring & Session Restore",
      "Themes, Layouts & Config",
      "Claude Code"
    ]
  },
  {
    "name": "pawel-cell/bmux-ai-agents-bundle",
    "url": "https://github.com/pawel-cell/bmux-ai-agents-bundle",
    "agent": "Multi",
    "descriptionKey": "p134",
    "language": "Shell / Python",
    "stars": 20,
    "categories": [
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "ericblue/bmux-session-manager",
    "url": "https://github.com/ericblue/bmux-session-manager",
    "agent": "Claude Code",
    "descriptionKey": "p135",
    "language": "Python",
    "stars": 12,
    "categories": [
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "freestyle-sh/rigkit",
    "url": "https://github.com/freestyle-sh/rigkit",
    "agent": "Multi",
    "descriptionKey": "p136",
    "language": "TypeScript",
    "stars": 7,
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "ph3on1x/claude-bmux-skill",
    "url": "https://github.com/ph3on1x/claude-bmux-skill",
    "agent": "Claude Code",
    "descriptionKey": "p137",
    "language": "Markdown",
    "stars": 7,
    "categories": [
      "Sidebar & Status Pills",
      "Multi-Agent Orchestration",
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "sinozu/bmux-git-diff",
    "url": "https://github.com/sinozu/bmux-git-diff",
    "descriptionKey": "p138",
    "language": "Go",
    "stars": 5,
    "categories": [
      "Browser Automation"
    ]
  },
  {
    "name": "jiahao-shao1/bmux-skill",
    "url": "https://github.com/jiahao-shao1/bmux-skill",
    "agent": "Claude Code",
    "descriptionKey": "p139",
    "language": "Markdown",
    "stars": 5,
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Browser Automation",
      "Claude Code"
    ]
  },
  {
    "name": "devnazim/pi-bmux",
    "url": "https://github.com/devnazim/pi-bmux",
    "agent": "Pi",
    "descriptionKey": "p140",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Pi"
    ]
  },
  {
    "name": "Catdaemon/pi-extensions",
    "url": "https://github.com/Catdaemon/pi-extensions",
    "agent": "Pi",
    "descriptionKey": "p141",
    "language": "TypeScript",
    "stars": 3,
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "Pi"
    ]
  },
  {
    "name": "flyflor/bmux-codex-worktree",
    "url": "https://github.com/flyflor/bmux-codex-worktree",
    "agent": "Codex",
    "descriptionKey": "p142",
    "language": "Shell",
    "stars": 3,
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management"
    ]
  },
  {
    "name": "tanabee/bmux.vim",
    "url": "https://github.com/tanabee/bmux.vim",
    "agent": "Multi",
    "descriptionKey": "p143",
    "language": "Vim Script",
    "stars": 3,
    "categories": [
      "Browser Automation",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "alpeshvas/bmuxinator",
    "url": "https://github.com/alpeshvas/bmuxinator",
    "agent": "Multi",
    "descriptionKey": "p144",
    "language": "Rust",
    "stars": 2,
    "categories": [
      "Worktrees & Workspace Management",
      "Themes, Layouts & Config",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "sttts/skills",
    "url": "https://github.com/sttts/skills",
    "agent": "Multi",
    "descriptionKey": "p145",
    "language": "Shell",
    "stars": 2,
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "yigitkonur/bmux-codex",
    "url": "https://github.com/yigitkonur/bmux-codex",
    "agent": "Codex",
    "descriptionKey": "p146",
    "language": "TypeScript",
    "stars": 1,
    "categories": [
      "Sidebar & Status Pills",
      "Progress Bars & Estimation",
      "Sidebar Logs & Activity Feed",
      "Desktop Notifications"
    ]
  },
  {
    "name": "mimen/claude-sessions",
    "url": "https://github.com/mimen/claude-sessions",
    "agent": "Claude Code",
    "descriptionKey": "p147",
    "language": "TypeScript",
    "categories": [
      "Monitoring & Session Restore",
      "Claude Code"
    ]
  },
  {
    "name": "tanaka-yui/yui-cc-plugins",
    "url": "https://github.com/tanaka-yui/yui-cc-plugins",
    "agent": "Multi",
    "descriptionKey": "p148",
    "language": "TypeScript",
    "stars": 2,
    "categories": [
      "Multi-Agent Orchestration",
      "Worktrees & Workspace Management",
      "Remote & Mobile Access",
      "Multi-Agent / Agent-Agnostic"
    ]
  },
  {
    "name": "talldan/bmux-opencode-agent-comm",
    "url": "https://github.com/talldan/bmux-opencode-agent-comm",
    "agent": "OpenCode",
    "descriptionKey": "p149",
    "language": "TypeScript",
    "categories": [
      "Multi-Agent Orchestration",
      "OpenCode"
    ]
  },
  {
    "name": "LuisUrrutia/opencode-bmux",
    "url": "https://github.com/LuisUrrutia/opencode-bmux",
    "agent": "OpenCode",
    "descriptionKey": "p150",
    "language": "TypeScript",
    "categories": [
      "Sidebar & Status Pills",
      "Desktop Notifications",
      "OpenCode"
    ]
  }
] as const satisfies readonly AwesomeBmuxProject[];
