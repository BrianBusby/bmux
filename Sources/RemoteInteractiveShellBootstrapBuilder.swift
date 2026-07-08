import Foundation

enum RemoteInteractiveShellBootstrapBuilder {
    static func script(
        remoteRelayPort: Int,
        shellFeatures: String,
        terminfoSource: String? = nil,
        bundledZshIntegration: String? = nil,
        bundledBashIntegration: String? = nil,
        bundledFishIntegration: String? = nil
    ) -> String {
        let shellStateDir = shellStateDirForRemoteRelayPort(remoteRelayPort)
        let commonShellExportLines = commonShellLines(
            remoteRelayPort: remoteRelayPort,
            shellStateDir: shellStateDir,
            shellFeatures: shellFeatures,
            terminfoSource: terminfoSource
        )
        var zshShellLines = commonShellExportLines
        zshShellLines.append(
            #"if [ "${BMUX_SHELL_INTEGRATION:-1}" != "0" ] && [ -r "${BMUX_SHELL_INTEGRATION_DIR}/bmux-zsh-integration.zsh" ]; then . "${BMUX_SHELL_INTEGRATION_DIR}/bmux-zsh-integration.zsh"; fi"#
        )
        var bashShellLines = commonShellExportLines
        bashShellLines.append(
            #"if [ "${BMUX_SHELL_INTEGRATION:-1}" != "0" ] && [ -r "${BMUX_SHELL_INTEGRATION_DIR}/bmux-bash-integration.bash" ]; then . "${BMUX_SHELL_INTEGRATION_DIR}/bmux-bash-integration.bash"; fi"#
        )
        let zshBootstrap = RemoteRelayZshBootstrap(shellStateDir: shellStateDir)
        let relayWarmupLines = relayWarmupLines(remoteRelayPort: remoteRelayPort)

        var outerLines: [String] = [
            "mkdir -p \"$HOME/.bmux/relay\"",
            "bmux_shell_dir=\"\(shellStateDir)\"",
            "mkdir -p \"$bmux_shell_dir\"",
        ]
        if let bundledZshIntegration {
            outerLines += [
                "cat > \"$bmux_shell_dir/bmux-zsh-integration.zsh\" <<'BMUXBMUXZSH'",
                bundledZshIntegration,
                "BMUXBMUXZSH",
            ]
        }
        if let bundledBashIntegration {
            outerLines += [
                "cat > \"$bmux_shell_dir/bmux-bash-integration.bash\" <<'BMUXBMUXBASH'",
                bundledBashIntegration,
                "BMUXBMUXBASH",
            ]
        }
        if let bundledFishIntegration {
            outerLines += [
                "mkdir -p \"$bmux_shell_dir/fish\"",
                "cat > \"$bmux_shell_dir/fish/config.fish\" <<'BMUXBMUXFISH'",
                bundledFishIntegration,
                "BMUXBMUXFISH",
            ]
        }
        outerLines.append(contentsOf: commonShellExportLines)
        outerLines += [
            "BMUX_LOGIN_SHELL=\"${SHELL:-/bin/zsh}\"",
            "case \"${BMUX_LOGIN_SHELL##*/}\" in",
            "  zsh)",
            "    cat > \"$bmux_shell_dir/.zshenv\" <<'BMUXZSHENV'",
        ]
        outerLines.append(contentsOf: zshBootstrap.zshEnvLines)
        outerLines += [
            "BMUXZSHENV",
            "    cat > \"$bmux_shell_dir/.zprofile\" <<'BMUXZSHPROFILE'",
        ]
        outerLines.append(contentsOf: zshBootstrap.zshProfileLines)
        outerLines += [
            "BMUXZSHPROFILE",
            "    cat > \"$bmux_shell_dir/.zshrc\" <<'BMUXZSHRC'",
        ]
        outerLines.append(contentsOf: zshBootstrap.zshRCLines(commonShellLines: zshShellLines))
        outerLines += [
            "BMUXZSHRC",
            "    cat > \"$bmux_shell_dir/.zlogin\" <<'BMUXZSHLOGIN'",
        ]
        outerLines.append(contentsOf: zshBootstrap.zshLoginLines)
        outerLines += [
            "BMUXZSHLOGIN",
            "    chmod 600 \"$bmux_shell_dir/.zshenv\" \"$bmux_shell_dir/.zprofile\" \"$bmux_shell_dir/.zshrc\" \"$bmux_shell_dir/.zlogin\" >/dev/null 2>&1 || true",
        ]
        outerLines.append(contentsOf: relayWarmupLines.map { "    " + $0 })
        outerLines += [
            "    export BMUX_REAL_ZDOTDIR=\"${ZDOTDIR:-$HOME}\"",
            "    export ZDOTDIR=\"$bmux_shell_dir\"",
            "    exec \"$BMUX_LOGIN_SHELL\" -il",
            "    ;;",
            "  bash)",
            "    cat > \"$bmux_shell_dir/.bashrc\" <<'BMUXBASHRC'",
        ]
        outerLines.append(contentsOf: [
            "if [ -f \"$HOME/.bash_profile\" ]; then",
            "  . \"$HOME/.bash_profile\"",
            "elif [ -f \"$HOME/.bash_login\" ]; then",
            "  . \"$HOME/.bash_login\"",
            "elif [ -f \"$HOME/.profile\" ]; then",
            "  . \"$HOME/.profile\"",
            "fi",
            "[ -f \"$HOME/.bashrc\" ] && . \"$HOME/.bashrc\"",
        ] + bashShellLines)
        outerLines += [
            "BMUXBASHRC",
            "    chmod 600 \"$bmux_shell_dir/.bashrc\" >/dev/null 2>&1 || true",
        ]
        outerLines.append(contentsOf: relayWarmupLines.map { "    " + $0 })
        outerLines += [
            "    exec \"$BMUX_LOGIN_SHELL\" --rcfile \"$bmux_shell_dir/.bashrc\" -i",
            "    ;;",
            "  fish)",
        ]
        outerLines.append(contentsOf: relayWarmupLines.map { "    " + $0 })
        outerLines += [
            "    export BMUX_FISH_INTEGRATION_FILE=\"$bmux_shell_dir/fish/config.fish\"",
            "    export BMUX_FISH_USER_CONFIG_ALREADY_LOADED=1",
            "    exec \"$BMUX_LOGIN_SHELL\" -il --init-command 'source \"$BMUX_FISH_INTEGRATION_FILE\"'",
            "    ;;",
            "  *)",
        ]
        outerLines.append(contentsOf: relayWarmupLines)
        outerLines += [
            "exec \"$BMUX_LOGIN_SHELL\" -i",
            ";;",
            "esac",
        ]

        return outerLines.joined(separator: "\n")
    }

    static func shellFeatures(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        let rawExisting = environment["GHOSTTY_SHELL_FEATURES"] ?? ""
        var seen: Set<String> = []
        var merged: [String] = []

        for token in rawExisting.split(separator: ",") {
            let feature = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !feature.isEmpty else { continue }
            if seen.insert(feature).inserted {
                merged.append(feature)
            }
        }

        for required in ["ssh-env", "ssh-terminfo"] {
            if seen.insert(required).inserted {
                merged.append(required)
            }
        }

        return merged.joined(separator: ",")
    }

    static func bundledShellIntegrationScript(
        named fileName: String,
        bundleResourceURL: URL? = Bundle.main.resourceURL,
        fileManager: FileManager = .default
    ) -> String? {
        guard let bundleResourceURL else { return nil }
        let url = bundleResourceURL
            .appendingPathComponent("shell-integration", isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let contents = String(data: data, encoding: .utf8) else {
            return nil
        }
        return contents
    }

    private static func commonShellLines(
        remoteRelayPort: Int,
        shellStateDir: String,
        shellFeatures: String,
        terminfoSource: String?
    ) -> [String] {
        let relaySocket = remoteRelayPort > 0 ? "127.0.0.1:\(remoteRelayPort)" : nil
        var lines = terminalSetupLines(terminfoSource: terminfoSource)
        lines.append(contentsOf: RemoteShellEnvironment.utf8LocaleSetupLines())
        lines.append(contentsOf: shellExportLines(shellFeatures: shellFeatures))
        lines.append("export PATH=\"$HOME/.bmux/bin:$PATH\"")
        lines.append("export BMUX_BUNDLED_CLI_PATH=\"$HOME/.bmux/bin/bmux\"")
        lines.append("export BMUX_SHELL_INTEGRATION_DIR=\"\(shellStateDir)\"")
        if let relaySocket {
            lines.append("export BMUX_SOCKET_PATH=\(relaySocket)")
        }
        // The assignment placeholders are replaced by `ssh-pty-attach` before
        // this script runs. Split the sentinel patterns so a missed replacement
        // does not export literal placeholder IDs into the remote shell.
        lines.append(contentsOf: [
            "bmux_workspace_id='__BMUX_WORKSPACE_ID__'",
            "case \"$bmux_workspace_id\" in \"\"|'__BMUX_''WORKSPACE_ID__') ;; *) export BMUX_WORKSPACE_ID=\"$bmux_workspace_id\"; export BMUX_TAB_ID=\"$bmux_workspace_id\" ;; esac",
            "bmux_surface_id='__BMUX_SURFACE_ID__'",
            "case \"$bmux_surface_id\" in \"\"|'__BMUX_''SURFACE_ID__') ;; *) export BMUX_SURFACE_ID=\"$bmux_surface_id\"; export BMUX_PANEL_ID=\"$bmux_surface_id\" ;; esac",
            "unset bmux_workspace_id bmux_surface_id",
            "hash -r >/dev/null 2>&1 || true",
            "rehash >/dev/null 2>&1 || true",
        ])
        return lines
    }

    static func terminalSetupLines(terminfoSource: String?) -> [String] {
        let trimmedTerminfoSource = terminfoSource?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedTerminfoSource, !trimmedTerminfoSource.isEmpty else {
            // Without a bundled terminfo to install we can only probe what the
            // remote already has and fall back to a universally-present entry.
            return [
                "bmux_term='xterm-256color'",
                "if command -v infocmp >/dev/null 2>&1 && infocmp xterm-ghostty >/dev/null 2>&1; then",
                "  bmux_term='xterm-ghostty'",
                "fi",
                "export TERM=\"$bmux_term\"",
            ]
        }
        // Install the bundled xterm-ghostty terminfo *synchronously*, before
        // deciding TERM, so a full-screen TUI (e.g. Claude Code) never starts
        // against a TERM whose terminfo entry is missing or half-written.
        //
        // The previous design deferred `tic` to a background job and decided
        // TERM up front, so the first shell on a host without the entry got
        // xterm-256color while a later pass could select xterm-ghostty mid-write
        // and garble output (#6352). Here we compile into a private temp
        // directory on the same filesystem as ~/.terminfo, then move each
        // compiled entry into place with an atomic rename, so a concurrent reader
        // in another bmux ssh session sharing $HOME never observes a partially
        // written database. The temp directory comes from `mktemp` when present,
        // otherwise a per-process `$$` directory (unique among live processes) so
        // the atomic-rename path applies even without `mktemp` — no branch ever
        // compiles terminfo directly into ~/.terminfo.
        return [
            "bmux_term='xterm-256color'",
            "if command -v infocmp >/dev/null 2>&1 && infocmp xterm-ghostty >/dev/null 2>&1; then",
            "  bmux_term='xterm-ghostty'",
            "elif command -v tic >/dev/null 2>&1; then",
            "  mkdir -p \"$HOME/.terminfo\" 2>/dev/null",
            "  bmux_ti_tmp=$(mktemp -d \"$HOME/.terminfo.bmux.XXXXXX\" 2>/dev/null) || bmux_ti_tmp=''",
            "  if [ -z \"$bmux_ti_tmp\" ]; then",
            "    bmux_ti_tmp=\"$HOME/.terminfo.bmux.$$\"",
            "    rm -rf \"$bmux_ti_tmp\" 2>/dev/null",
            "    mkdir \"$bmux_ti_tmp\" 2>/dev/null || bmux_ti_tmp=''",
            "  fi",
            "  {",
            "    cat <<'BMUXTERMINFO'",
            trimmedTerminfoSource,
            "BMUXTERMINFO",
            "  } | {",
            "    if [ -n \"$bmux_ti_tmp\" ] && tic -x -o \"$bmux_ti_tmp\" - >/dev/null 2>&1; then",
            "      find \"$bmux_ti_tmp\" -type f 2>/dev/null | while IFS= read -r bmux_ti_file; do",
            "        bmux_ti_rel=${bmux_ti_file#\"$bmux_ti_tmp\"/}",
            "        bmux_ti_dest=\"$HOME/.terminfo/$bmux_ti_rel\"",
            "        mkdir -p \"$(dirname \"$bmux_ti_dest\")\" 2>/dev/null",
            "        mv -f \"$bmux_ti_file\" \"$bmux_ti_dest\" 2>/dev/null || cp -f \"$bmux_ti_file\" \"$bmux_ti_dest\" 2>/dev/null",
            "      done",
            "    fi",
            "  }",
            "  [ -n \"$bmux_ti_tmp\" ] && rm -rf \"$bmux_ti_tmp\" 2>/dev/null",
            "  if infocmp xterm-ghostty >/dev/null 2>&1; then",
            "    bmux_term='xterm-ghostty'",
            "  fi",
            "  unset bmux_ti_tmp bmux_ti_file bmux_ti_rel bmux_ti_dest 2>/dev/null || true",
            "fi",
            "export TERM=\"$bmux_term\"",
        ]
    }

    private static func shellExportLines(shellFeatures: String) -> [String] {
        let environment = ProcessInfo.processInfo.environment
        let colorTerm = normalizedEnvValue(environment["COLORTERM"]) ?? "truecolor"
        let termProgram = normalizedEnvValue(environment["TERM_PROGRAM"]) ?? "ghostty"
        let termProgramVersion = normalizedEnvValue(environment["TERM_PROGRAM_VERSION"])
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? ""
        let trimmedShellFeatures = shellFeatures.trimmingCharacters(in: .whitespacesAndNewlines)

        var exports: [String] = [
            "export COLORTERM=\(shellQuote(colorTerm))",
            "export TERM_PROGRAM=\(shellQuote(termProgram))",
        ]
        if !termProgramVersion.isEmpty {
            exports.append("export TERM_PROGRAM_VERSION=\(shellQuote(termProgramVersion))")
        }
        if !trimmedShellFeatures.isEmpty {
            exports.append("export GHOSTTY_SHELL_FEATURES=\(shellQuote(trimmedShellFeatures))")
        }
        return exports
    }

    private static func relayWarmupLines(remoteRelayPort: Int) -> [String] {
        guard remoteRelayPort > 0 else {
            return []
        }
        return [
            "bmux_relay_cli=\"${BMUX_BUNDLED_CLI_PATH:-$HOME/.bmux/bin/bmux}\"",
            "if [ ! -x \"$bmux_relay_cli\" ]; then bmux_relay_cli=\"$(command -v bmux 2>/dev/null || true)\"; fi",
            "bmux_relay_tty=\"${BMUX_BOOTSTRAP_TTY:-}\"",
            "if [ -z \"$bmux_relay_tty\" ]; then bmux_relay_tty=\"$(tty 2>/dev/null || true)\"; fi",
            "bmux_relay_tty=\"${bmux_relay_tty##*/}\"",
            "if [ -n \"$bmux_relay_tty\" ] && [ \"$bmux_relay_tty\" != \"not a tty\" ]; then",
            "  mkdir -p \"$HOME/.bmux/relay\" >/dev/null 2>&1 || true",
            "  printf '%s' \"$bmux_relay_tty\" > \"$HOME/.bmux/relay/\(remoteRelayPort).tty\" 2>/dev/null || true",
            "fi",
            "if [ -n \"$bmux_relay_cli\" ] && [ -n \"$BMUX_WORKSPACE_ID\" ] && [ -n \"$bmux_relay_tty\" ] && [ \"$bmux_relay_tty\" != \"not a tty\" ]; then",
            "  (",
            "    bmux_relay_report_tty=\"{\\\"workspace_id\\\":\\\"$BMUX_WORKSPACE_ID\\\",\\\"tty_name\\\":\\\"$bmux_relay_tty\\\"}\"",
            "    bmux_relay_ports_kick=\"{\\\"workspace_id\\\":\\\"$BMUX_WORKSPACE_ID\\\",\\\"reason\\\":\\\"command\\\"}\"",
            "    if [ -n \"$BMUX_SURFACE_ID\" ]; then",
            "      bmux_relay_report_tty=\"{\\\"workspace_id\\\":\\\"$BMUX_WORKSPACE_ID\\\",\\\"surface_id\\\":\\\"$BMUX_SURFACE_ID\\\",\\\"tty_name\\\":\\\"$bmux_relay_tty\\\"}\"",
            "      bmux_relay_ports_kick=\"{\\\"workspace_id\\\":\\\"$BMUX_WORKSPACE_ID\\\",\\\"surface_id\\\":\\\"$BMUX_SURFACE_ID\\\",\\\"reason\\\":\\\"command\\\"}\"",
            "    fi",
            "    \"$bmux_relay_cli\" rpc surface.report_tty \"$bmux_relay_report_tty\" >/dev/null 2>&1 || true",
            "    \"$bmux_relay_cli\" rpc surface.ports_kick \"$bmux_relay_ports_kick\" >/dev/null 2>&1 || true",
            "  ) </dev/null >/dev/null 2>&1 &",
            "fi",
            "unset BMUX_BOOTSTRAP_TTY bmux_relay_cli bmux_relay_tty bmux_relay_report_tty bmux_relay_ports_kick",
        ]
    }

    private static func shellStateDirForRemoteRelayPort(_ remoteRelayPort: Int) -> String {
        "$HOME/.bmux/relay/\(max(remoteRelayPort, 0)).shell"
    }

    private static func normalizedEnvValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func shellQuote(_ value: String) -> String {
        let safePattern = "^[A-Za-z0-9_@%+=:,./-]+$"
        if value.range(of: safePattern, options: .regularExpression) != nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}
