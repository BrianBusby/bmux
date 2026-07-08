import AppKit
import BmuxWorkspaces
import Foundation

/// Opens workspace-group configuration and documentation surfaces.
enum SidebarWorkspaceGroupConfigOpener {
    /// Opens the bmux config file (`~/.config/bmux/bmux.json`) in the user's
    /// configured editor, materializing an empty config first if none exists.
    @MainActor
    static func openBmuxConfigInEditor() {
        let opener = PreferredEditorService(defaults: .standard)
        openBmuxConfigInEditor(
            home: FileManager.default.homeDirectoryForCurrentUser,
            open: { opener.open($0) }
        )
    }

    /// Testable seam: resolves the bmux config path under `home`, materializes
    /// an empty config if absent, then hands the file to `open`.
    ///
    /// The public ``openBmuxConfigInEditor()`` entry point passes
    /// `PreferredEditorService.open` so the config file honors
    /// `preferredEditorCommand` (with an OS-default fallback). Tests inject a
    /// capturing closure to assert the config file is routed through `open`.
    static func openBmuxConfigInEditor(home: URL, open: (URL) -> Void) {
        open(materializedBmuxConfigURL(home: home))
    }

    /// Resolves `~/.config/bmux/bmux.json` under `home`, materializing an empty
    /// config first if none exists. Shared by the external-editor path above and
    /// in-app openers (e.g. the plus-button menu's "Customize Workspace Layouts…").
    static func materializedBmuxConfigURL(
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        let configURL = home
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("bmux", isDirectory: true)
            .appendingPathComponent("bmux.json", isDirectory: false)
        if !FileManager.default.fileExists(atPath: configURL.path) {
            try? FileManager.default.createDirectory(
                at: configURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try? Data("{}\n".utf8).write(to: configURL, options: .atomic)
            // The config later holds saved actions (commands, URLs, env
            // values); keep it owner-only from the start.
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: configURL.path
            )
        }
        return configURL
    }

    static func openWorkspaceGroupsDocs() {
        guard let url = URL(
            string: "https://github.com/manaflow-ai/bmux/blob/main/docs/workspace-groups.md"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
