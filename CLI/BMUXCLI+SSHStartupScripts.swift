import Foundation

extension BMUXCLI {
    func buildSSHStartupCommand(
        sshCommand: String,
        shellFeatures: String,
        remoteRelayPort: Int,
        isShellSnippet: Bool = false,
        passwordCredential: String? = nil,
        controlPathPreflightShellFunction: String? = nil,
        retryPTYAttachStatus: Bool = false,
        reconnectLimitDefault: Int = 20
    ) throws -> String {
        let script = buildSSHStartupScriptBody(
            sshCommand: sshCommand,
            shellFeatures: shellFeatures,
            remoteRelayPort: remoteRelayPort,
            isShellSnippet: isShellSnippet,
            passwordCredential: passwordCredential,
            controlPathPreflightShellFunction: controlPathPreflightShellFunction,
            retryPTYAttachStatus: retryPTYAttachStatus,
            reconnectLimitDefault: reconnectLimitDefault
        )
        return try writeSSHStartupScript(script, remoteRelayPort: remoteRelayPort)
    }

    func buildReusableSSHStartupCommand(
        sshCommand: String,
        shellFeatures: String,
        remoteRelayPort: Int,
        isShellSnippet: Bool = false,
        passwordCredential: String? = nil,
        controlPathPreflightShellFunction: String? = nil,
        retryPTYAttachStatus: Bool = false,
        reconnectLimitDefault: Int = 20
    ) -> String {
        // Reusable commands are persisted in workspace metadata and can be emitted over the socket API.
        // Short-lived credentials must stay in the one-shot launcher path only.
        let script = buildSSHStartupScriptBody(
            sshCommand: sshCommand,
            shellFeatures: shellFeatures,
            remoteRelayPort: remoteRelayPort,
            isShellSnippet: isShellSnippet,
            passwordCredential: nil,
            controlPathPreflightShellFunction: controlPathPreflightShellFunction,
            retryPTYAttachStatus: retryPTYAttachStatus,
            reconnectLimitDefault: reconnectLimitDefault
        )
        return reusableShellStartupCommand(
            scriptBody: script,
            tempPrefix: "bmux-ssh-startup"
        )
    }

    func buildReusableSSHPTYAttachStartupCommand(
        remoteShellCommand: String,
        remoteRelayPort: Int
    ) -> String {
        let attachScript = buildSSHPTYAttachScriptBody(
            remoteShellCommand: remoteShellCommand
        )
        return buildReusableSSHStartupCommand(
            sshCommand: attachScript,
            shellFeatures: "",
            remoteRelayPort: remoteRelayPort,
            isShellSnippet: true,
            retryPTYAttachStatus: true
        )
    }

    func buildSSHPTYAttachScriptBody(
        remoteShellCommand: String
    ) -> String {
        let executablePath = resolvedExecutableURL()?.path ?? (args.first ?? "bmux")
        let commandB64 = Data(remoteShellCommand.utf8).base64EncodedString()
        let attachCommand = [
            shellQuote(executablePath),
            "ssh-pty-attach",
            "--wait",
            "--workspace", "\"$bmux_ssh_pty_workspace_id\"",
            "--session-id", "\"$bmux_ssh_pty_session_id\"",
            "--attachment-id", "\"$bmux_ssh_pty_surface_id\"",
            "--command-b64", shellQuote(commandB64),
        ].joined(separator: " ")
        return [
            "bmux_ssh_pty_workspace_id=\"${BMUX_WORKSPACE_ID:-}\"",
            "bmux_ssh_pty_surface_id=\"${BMUX_SURFACE_ID:-}\"",
            "if [ -z \"$bmux_ssh_pty_workspace_id\" ]; then printf '%s\\n' '[bmux] required workspace context missing for SSH PTY attach.' >&2; exit 1; fi",
            "if [ -z \"$bmux_ssh_pty_surface_id\" ]; then printf '%s\\n' '[bmux] required terminal context missing for SSH PTY attach.' >&2; exit 1; fi",
            "bmux_ssh_pty_session_id=\"ssh-$bmux_ssh_pty_workspace_id-$bmux_ssh_pty_surface_id\"",
            "exec \(attachCommand)",
        ].joined(separator: "\n")
    }

    func sshAskpassExecShellScript(passwordCredential: String) -> String {
        let passwordB64 = Data(passwordCredential.utf8).base64EncodedString()
        return [
            "set -e",
            "bmux_ssh_askpass_dir=$(mktemp -d \"${TMPDIR:-/tmp}/bmux-ssh-askpass.XXXXXX\")",
            "bmux_ssh_askpass_file=\"$bmux_ssh_askpass_dir/password\"",
            "bmux_ssh_askpass_script=\"$bmux_ssh_askpass_dir/askpass\"",
            "bmux_ssh_expect_script=\"$bmux_ssh_askpass_dir/ssh-password.exp\"",
            "cleanup() { rm -rf \"$bmux_ssh_askpass_dir\"; }",
            "trap cleanup EXIT HUP INT TERM",
            "printf %s \(shellQuote(passwordB64)) | base64 -d > \"$bmux_ssh_askpass_file\" 2>/dev/null || printf %s \(shellQuote(passwordB64)) | base64 -D > \"$bmux_ssh_askpass_file\"",
            "chmod 600 \"$bmux_ssh_askpass_file\"",
            "if command -v expect >/dev/null 2>&1; then",
            "  cat > \"$bmux_ssh_expect_script\" <<'BMUX_EXPECT'",
            "set timeout 12",
            "set password_file $env(BMUX_SSH_ASKPASS_FILE)",
            "set fh [open $password_file r]",
            "set password [read $fh]",
            "close $fh",
            "set password [string trimright $password \"\\r\\n\"]",
            "set bmux_interactive_stdin [expr {[catch {exec /bin/sh -c {test -t 0}}] == 0}]",
            "log_user 0",
            "spawn {*}$argv",
            "proc bmux_rejected_password {} {",
            "  puts stderr {\\n[bmux] Cloud VM SSH credential was rejected; reconnecting.}",
            "  catch {close}",
            "  catch {wait}",
            "  exit 255",
            "}",
            "proc bmux_relay_session {} {",
            "  global bmux_interactive_stdin",
            "  set timeout -1",
            "  log_user 1",
            "  if {$bmux_interactive_stdin} {",
            "    interact",
            "    set status [wait]",
            "    exit [lindex $status 3]",
            "  }",
            "  expect { eof { set status [wait]; exit [lindex $status 3] } }",
            "}",
            "proc bmux_wait_after_password {} {",
            "  set timeout 2",
            "  expect {",
            "    -re \"(?i)permission denied\" { bmux_rejected_password }",
            "    -re \"(?i)password:\" { bmux_rejected_password }",
            "    timeout {",
            "      set bmux_buffer \"\"",
            "      catch { set bmux_buffer $expect_out(buffer) }",
            "      if {[regexp -nocase {(password:|permission denied)} $bmux_buffer]} { bmux_rejected_password }",
            "      if {[string length $bmux_buffer] > 0} { send_user -- $bmux_buffer }",
            "      bmux_relay_session",
            "    }",
            "    eof { set status [wait]; exit [lindex $status 3] }",
            "  }",
            "}",
            "expect {",
            "  -re \"(?i)password:\" {",
            "    send -- \"$password\\r\"",
            "    bmux_wait_after_password",
            "  }",
            "  timeout {",
            "    puts stderr {\\n[bmux] Cloud VM SSH credential prompt timed out; reconnecting.}",
            "    exit 255",
            "  }",
            "  eof { set status [wait]; exit [lindex $status 3] }",
            "}",
            "set status [wait]",
            "exit [lindex $status 3]",
            "BMUX_EXPECT",
            "  chmod 700 \"$bmux_ssh_expect_script\"",
            "  export BMUX_SSH_ASKPASS_FILE=\"$bmux_ssh_askpass_file\"",
            "  set +e",
            "  expect \"$bmux_ssh_expect_script\" \"$@\"",
            "  bmux_ssh_status=$?",
            "  exit \"$bmux_ssh_status\"",
            "fi",
            "printf '%s\\n' '#!/bin/sh' 'cat \"$BMUX_SSH_ASKPASS_FILE\"' > \"$bmux_ssh_askpass_script\"",
            "chmod 700 \"$bmux_ssh_askpass_script\"",
            "export BMUX_SSH_ASKPASS_FILE=\"$bmux_ssh_askpass_file\"",
            "export SSH_ASKPASS=\"$bmux_ssh_askpass_script\"",
            "export SSH_ASKPASS_REQUIRE=force",
            "export DISPLAY=\"${DISPLAY:-bmux}\"",
            "set +e",
            "\"$@\"",
            "bmux_ssh_status=$?",
            "exit \"$bmux_ssh_status\"",
        ].joined(separator: "\n")
    }

    func sshAskpassExecShellScript(passwordFilePath: String, cleanupDirectory: String) -> String {
        [
            "set -e",
            "bmux_ssh_askpass_dir=\(shellQuote(cleanupDirectory))",
            "bmux_ssh_askpass_file=\(shellQuote(passwordFilePath))",
            "bmux_ssh_askpass_script=\"$bmux_ssh_askpass_dir/askpass\"",
            "bmux_ssh_expect_script=\"$bmux_ssh_askpass_dir/ssh-password.exp\"",
            "cleanup() { rm -rf \"$bmux_ssh_askpass_dir\"; }",
            "trap cleanup EXIT HUP INT TERM",
            "chmod 600 \"$bmux_ssh_askpass_file\"",
            "if command -v expect >/dev/null 2>&1; then",
            "  cat > \"$bmux_ssh_expect_script\" <<'BMUX_EXPECT'",
            "set timeout 12",
            "set password_file $env(BMUX_SSH_ASKPASS_FILE)",
            "set fh [open $password_file r]",
            "set password [read $fh]",
            "close $fh",
            "set password [string trimright $password \"\\r\\n\"]",
            "set bmux_interactive_stdin [expr {[catch {exec /bin/sh -c {test -t 0}}] == 0}]",
            "log_user 0",
            "spawn {*}$argv",
            "proc bmux_rejected_password {} {",
            "  puts stderr {\\n[bmux] Cloud VM SSH credential was rejected; reconnecting.}",
            "  catch {close}",
            "  catch {wait}",
            "  exit 255",
            "}",
            "proc bmux_relay_session {} {",
            "  global bmux_interactive_stdin",
            "  set timeout -1",
            "  log_user 1",
            "  if {$bmux_interactive_stdin} {",
            "    interact",
            "    set status [wait]",
            "    exit [lindex $status 3]",
            "  }",
            "  expect { eof { set status [wait]; exit [lindex $status 3] } }",
            "}",
            "proc bmux_wait_after_password {} {",
            "  set timeout 2",
            "  expect {",
            "    -re \"(?i)permission denied\" { bmux_rejected_password }",
            "    -re \"(?i)password:\" { bmux_rejected_password }",
            "    timeout {",
            "      set bmux_buffer \"\"",
            "      catch { set bmux_buffer $expect_out(buffer) }",
            "      if {[regexp -nocase {(password:|permission denied)} $bmux_buffer]} { bmux_rejected_password }",
            "      if {[string length $bmux_buffer] > 0} { send_user -- $bmux_buffer }",
            "      bmux_relay_session",
            "    }",
            "    eof { set status [wait]; exit [lindex $status 3] }",
            "  }",
            "}",
            "expect {",
            "  -re \"(?i)password:\" {",
            "    send -- \"$password\\r\"",
            "    bmux_wait_after_password",
            "  }",
            "  timeout {",
            "    puts stderr {\\n[bmux] Cloud VM SSH credential prompt timed out; reconnecting.}",
            "    exit 255",
            "  }",
            "  eof { set status [wait]; exit [lindex $status 3] }",
            "}",
            "set status [wait]",
            "exit [lindex $status 3]",
            "BMUX_EXPECT",
            "  chmod 700 \"$bmux_ssh_expect_script\"",
            "  export BMUX_SSH_ASKPASS_FILE=\"$bmux_ssh_askpass_file\"",
            "  set +e",
            "  expect \"$bmux_ssh_expect_script\" \"$@\"",
            "  bmux_ssh_status=$?",
            "  exit \"$bmux_ssh_status\"",
            "fi",
            "printf '%s\\n' '#!/bin/sh' 'cat \"$BMUX_SSH_ASKPASS_FILE\"' > \"$bmux_ssh_askpass_script\"",
            "chmod 700 \"$bmux_ssh_askpass_script\"",
            "export BMUX_SSH_ASKPASS_FILE=\"$bmux_ssh_askpass_file\"",
            "export SSH_ASKPASS=\"$bmux_ssh_askpass_script\"",
            "export SSH_ASKPASS_REQUIRE=force",
            "export DISPLAY=\"${DISPLAY:-bmux}\"",
            "set +e",
            "\"$@\"",
            "bmux_ssh_status=$?",
            "exit \"$bmux_ssh_status\"",
        ].joined(separator: "\n")
    }

    private func buildSSHStartupScriptBody(
        sshCommand: String,
        shellFeatures: String,
        remoteRelayPort: Int,
        isShellSnippet: Bool,
        passwordCredential: String?,
        controlPathPreflightShellFunction: String?,
        retryPTYAttachStatus: Bool,
        reconnectLimitDefault: Int
    ) -> String {
        let trimmedFeatures = shellFeatures.trimmingCharacters(in: .whitespacesAndNewlines)
        let shellFeaturesBootstrap: String = trimmedFeatures.isEmpty
            ? ""
            : "export GHOSTTY_SHELL_FEATURES=\(shellQuote(trimmedFeatures))"
        let lifecycleCleanup = buildSSHSessionEndShellCommand(remoteRelayPort: remoteRelayPort)
        let trimmedControlPathPreflight = controlPathPreflightShellFunction?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var scriptLines: [String] = []
        if !shellFeaturesBootstrap.isEmpty {
            scriptLines.append(shellFeaturesBootstrap)
        }
        if let passwordCredential, !passwordCredential.isEmpty {
            let passwordB64 = Data(passwordCredential.utf8).base64EncodedString()
            scriptLines += [
                "bmux_ssh_askpass_dir=$(mktemp -d \"${TMPDIR:-/tmp}/bmux-ssh-askpass.XXXXXX\") || exit 1",
                "bmux_ssh_askpass_file=\"$bmux_ssh_askpass_dir/password\"",
                "bmux_ssh_askpass_script=\"$bmux_ssh_askpass_dir/askpass\"",
                "printf %s \(shellQuote(passwordB64)) | base64 -d > \"$bmux_ssh_askpass_file\" 2>/dev/null || printf %s \(shellQuote(passwordB64)) | base64 -D > \"$bmux_ssh_askpass_file\" || exit 1",
                "chmod 600 \"$bmux_ssh_askpass_file\"",
                "printf '%s\\n' '#!/bin/sh' 'cat \"$BMUX_SSH_ASKPASS_FILE\"' > \"$bmux_ssh_askpass_script\"",
                "chmod 700 \"$bmux_ssh_askpass_script\"",
                "export BMUX_SSH_ASKPASS_FILE=\"$bmux_ssh_askpass_file\"",
                "export SSH_ASKPASS=\"$bmux_ssh_askpass_script\"",
                "export SSH_ASKPASS_REQUIRE=force",
                "export DISPLAY=\"${DISPLAY:-bmux}\"",
                "bmux_ssh_cleanup_password() { rm -rf \"$bmux_ssh_askpass_dir\" 2>/dev/null || true; }",
            ]
        } else {
            scriptLines.append("bmux_ssh_cleanup_password() { :; }")
        }
        if let trimmedControlPathPreflight, !trimmedControlPathPreflight.isEmpty {
            scriptLines.append(trimmedControlPathPreflight)
        }
        scriptLines += [
            "rm -f -- \"$0\" 2>/dev/null || true",
            "BMUX_SSH_SESSION_ENDED=0",
            "BMUX_SSH_STARTUP_PID=$$",
            "export BMUX_SSH_STARTUP_PID",
            "bmux_ssh_reconnect_limit=\"${BMUX_SSH_RECONNECT_LIMIT:-\(max(0, reconnectLimitDefault))}\"",
            "case \"$bmux_ssh_reconnect_limit\" in ''|*[!0-9]*) bmux_ssh_reconnect_limit=20 ;; esac",
            "bmux_ssh_reconnect_delay=\"${BMUX_SSH_RECONNECT_DELAY_SECONDS:-2}\"",
            "case \"$bmux_ssh_reconnect_delay\" in ''|*[!0-9]*) bmux_ssh_reconnect_delay=2 ;; esac",
            "bmux_ssh_retry=0",
            "BMUX_SSH_CHILD_PID=",
            "BMUX_SSH_PENDING_SIGNAL=",
            "bmux_ssh_note() { if [ -t 2 ]; then printf \"$@\" >&2 || true; fi; }",
            "bmux_ssh_session_end() { if [ \"${BMUX_SSH_SESSION_ENDED:-0}\" = 1 ]; then return; fi; BMUX_SSH_SESSION_ENDED=1; bmux_ssh_cleanup_password; \(lifecycleCleanup); }",
            "bmux_ssh_signal_exit() { bmux_ssh_signal_status=\"$1\"; if [ -z \"${BMUX_SSH_CHILD_PID:-}\" ]; then BMUX_SSH_PENDING_SIGNAL=\"$bmux_ssh_signal_status\"; return; fi; BMUX_SSH_SESSION_ENDED=1; bmux_ssh_cleanup_password; trap - EXIT HUP INT TERM; exit \"$bmux_ssh_signal_status\"; }",
            "trap 'bmux_ssh_session_end' EXIT",
            "trap 'bmux_ssh_signal_exit 129' HUP",
            "trap 'bmux_ssh_signal_exit 130' INT",
            "trap 'bmux_ssh_signal_exit 143' TERM",
            "while :; do",
        ]
        if let trimmedControlPathPreflight, !trimmedControlPathPreflight.isEmpty {
            scriptLines.append("  bmux_ssh_preflight_control_path")
        }
        if isShellSnippet {
            scriptLines += [
                "  (",
                "    \(sshCommand)",
                "  ) <&0 &",
            ]
        } else {
            scriptLines.append("  command \(sshCommand) <&0 &")
        }
        let retryableStatusPattern = retryPTYAttachStatus ? "254|255" : "255"
        scriptLines += [
            "  BMUX_SSH_CHILD_PID=$!",
            "  if [ -n \"${BMUX_SSH_PENDING_SIGNAL:-}\" ]; then bmux_ssh_signal_exit \"$BMUX_SSH_PENDING_SIGNAL\"; fi",
            "  wait \"$BMUX_SSH_CHILD_PID\"",
            "  bmux_ssh_status=$?",
            "  BMUX_SSH_CHILD_PID=",
            "  if [ \"$bmux_ssh_status\" -eq 0 ]; then break; fi",
            "  case \"$bmux_ssh_status\" in \(retryableStatusPattern)) ;; *) break ;; esac",
            "  if [ \"$bmux_ssh_retry\" -ge \"$bmux_ssh_reconnect_limit\" ]; then break; fi",
            "  bmux_ssh_retry=$((bmux_ssh_retry + 1))",
            "  bmux_ssh_note '\\n\\033[33m[bmux] ssh exited with status %s; reconnecting (attempt %s/%s).\\033[0m\\n\\033[2m[bmux] close this pane or press Ctrl-C to stop reconnecting.\\033[0m\\n' \"$bmux_ssh_status\" \"$bmux_ssh_retry\" \"$bmux_ssh_reconnect_limit\"",
            "  if [ \"$bmux_ssh_reconnect_delay\" -gt 0 ]; then sleep \"$bmux_ssh_reconnect_delay\"; fi",
            "  if [ -n \"${BMUX_SSH_PENDING_SIGNAL:-}\" ]; then bmux_ssh_session_end; trap - EXIT HUP INT TERM; exit \"$BMUX_SSH_PENDING_SIGNAL\"; fi",
            "done",
            "trap - EXIT HUP INT TERM",
            "bmux_ssh_session_end",
            "if [ \"$bmux_ssh_status\" -ne 0 ]; then",
            "  printf '\\n\\033[31m[bmux] ssh exited with status %s.\\033[0m\\n\\033[2m[bmux] the remote VM may have been paused, destroyed, or lost network.\\033[0m\\n\\033[2m[bmux] press Enter to close this pane.\\033[0m\\n' \"$bmux_ssh_status\" >&2 || true",
            "  IFS= read -r _bmux_dismiss_key 2>/dev/null || true",
            "fi",
            "exit $bmux_ssh_status",
        ]
        return scriptLines.joined(separator: "\n")
    }

    private func writeSSHStartupScript(_ scriptBody: String, remoteRelayPort: Int) throws -> String {
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "bmux-ssh-startup-\(remoteRelayPort)-\(UUID().uuidString.lowercased()).sh"
        )
        let script = "#!/bin/sh\n\(scriptBody)\n"
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        return shellQuote(scriptURL.path)
    }

    private func reusableShellStartupCommand(
        scriptBody: String,
        tempPrefix: String
    ) -> String {
        let fullScript = "#!/bin/sh\n\(scriptBody)\n"
        let encodedScript = Data(fullScript.utf8).base64EncodedString()
        let encodedLiteral = shellQuote(encodedScript)
        let wrapper = [
            "bmux_tmp=$(mktemp \"${TMPDIR:-/tmp}/\(tempPrefix).XXXXXX\") || exit 1",
            "bmux_cleanup() { rm -f -- \"$bmux_tmp\" 2>/dev/null || true; }",
            "trap 'bmux_cleanup' EXIT HUP INT TERM",
            "(printf %s \(encodedLiteral) | base64 -d 2>/dev/null || printf %s \(encodedLiteral) | base64 -D 2>/dev/null) > \"$bmux_tmp\" || exit 1",
            "chmod 700 \"$bmux_tmp\" >/dev/null 2>&1 || true",
            "/bin/sh \"$bmux_tmp\"",
            "bmux_status=$?",
            "trap - EXIT HUP INT TERM",
            "bmux_cleanup",
            "unset bmux_tmp bmux_status",
            "unset -f bmux_cleanup 2>/dev/null || true",
            "exit $bmux_status",
        ].joined(separator: "\n")
        return "/bin/sh -c \(shellQuote(wrapper))"
    }

    private func buildSSHSessionEndShellCommand(remoteRelayPort: Int) -> String {
        [
            "if [ -n \"${BMUX_BUNDLED_CLI_PATH:-}\" ]",
            "&& [ -x \"${BMUX_BUNDLED_CLI_PATH}\" ]",
            "&& [ -n \"${BMUX_SOCKET_PATH:-}\" ]",
            "&& [ -n \"${BMUX_WORKSPACE_ID:-}\" ]",
            "&& [ -n \"${BMUX_SURFACE_ID:-}\" ]; then",
            "\"${BMUX_BUNDLED_CLI_PATH}\" --socket \"${BMUX_SOCKET_PATH}\" ssh-session-end --relay-port \(remoteRelayPort) --workspace \"${BMUX_WORKSPACE_ID}\" --surface \"${BMUX_SURFACE_ID}\" >/dev/null 2>&1 || true;",
            "elif command -v bmux >/dev/null 2>&1",
            "&& [ -n \"${BMUX_WORKSPACE_ID:-}\" ]",
            "&& [ -n \"${BMUX_SURFACE_ID:-}\" ]; then",
            "bmux ssh-session-end --relay-port \(remoteRelayPort) --workspace \"${BMUX_WORKSPACE_ID}\" --surface \"${BMUX_SURFACE_ID}\" >/dev/null 2>&1 || true;",
            "fi",
        ].joined(separator: " ")
    }
}
