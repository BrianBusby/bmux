import Foundation

extension DockSplitStore {
    static func resolvedWorkingDirectory(_ cwd: String?, baseDirectory: String) -> String {
        guard let cwd, !cwd.isEmpty else { return baseDirectory }
        if cwd.hasPrefix("/") {
            return cwd
        }
        return (baseDirectory as NSString).appendingPathComponent(cwd)
    }

    static func shellStartupScript(command: String, workingDirectory: String) -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent(
            "bmux-dock-control-\(UUID().uuidString.lowercased()).sh"
        )
        let encodedCommand = Data(command.utf8).base64EncodedString()
        let encodedWorkingDirectory = Data(workingDirectory.utf8).base64EncodedString()
        let body = """
        #!/bin/sh
        bmux_dock_decode() { printf '%s' "$1" | base64 --decode 2>/dev/null || printf '%s' "$1" | base64 -D 2>/dev/null; }
        bmux_dock_login_shell() {
          bmux_dock_user="$(id -un 2>/dev/null || printf '%s' "${USER:-}")"
          bmux_dock_ds_shell="$(dscl . -read "/Users/$bmux_dock_user" UserShell 2>/dev/null | awk '{print $2; exit}')"
          if [ -n "$bmux_dock_ds_shell" ] && [ -x "$bmux_dock_ds_shell" ]; then printf '%s\\n' "$bmux_dock_ds_shell"
          elif [ -n "${SHELL:-}" ] && [ -x "${SHELL:-}" ]; then printf '%s\\n' "$SHELL"
          else printf '%s\\n' /bin/sh; fi
        }
        bmux_dock_command="$(bmux_dock_decode '\(encodedCommand)')"
        bmux_dock_working_directory="$(bmux_dock_decode '\(encodedWorkingDirectory)')"
        bmux_dock_shell="$(bmux_dock_login_shell)"
        bmux_dock_bundle_bin=""
        if [ -n "${BMUX_BUNDLED_CLI_PATH:-}" ]; then bmux_dock_bundle_bin="$(dirname "$BMUX_BUNDLED_CLI_PATH")"; fi
        export SHELL="$bmux_dock_shell"
        rm -f -- "$0" 2>/dev/null || true
        case "$(basename "$bmux_dock_shell")" in
          fish)
            BMUX_DOCK_BUNDLE_BIN="$bmux_dock_bundle_bin" BMUX_DOCK_START_COMMAND="$bmux_dock_command" BMUX_DOCK_START_DIRECTORY="$bmux_dock_working_directory" "$bmux_dock_shell" -l -c 'if test -n "$BMUX_DOCK_BUNDLE_BIN"; and not contains -- "$BMUX_DOCK_BUNDLE_BIN" $PATH; set -gx PATH "$BMUX_DOCK_BUNDLE_BIN" $PATH; end; if test -n "$BMUX_DOCK_START_DIRECTORY"; cd "$BMUX_DOCK_START_DIRECTORY"; end; eval "$BMUX_DOCK_START_COMMAND"'
            ;;
          *) BMUX_DOCK_BUNDLE_BIN="$bmux_dock_bundle_bin" BMUX_DOCK_START_COMMAND="$bmux_dock_command" BMUX_DOCK_START_DIRECTORY="$bmux_dock_working_directory" "$bmux_dock_shell" -lc 'if [ -n "${BMUX_DOCK_BUNDLE_BIN:-}" ]; then case ":${PATH:-}:" in *":$BMUX_DOCK_BUNDLE_BIN:"*) ;; *) PATH="$BMUX_DOCK_BUNDLE_BIN${PATH:+:$PATH}"; export PATH ;; esac; fi; cd "$BMUX_DOCK_START_DIRECTORY" 2>/dev/null || true; eval "$BMUX_DOCK_START_COMMAND"'
            ;;
        esac
        printf '\\n'
        exec "$bmux_dock_shell" -l
        """
        do {
            try body.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
            return scriptURL.path
        } catch {
            return "/bin/sh"
        }
    }
}
