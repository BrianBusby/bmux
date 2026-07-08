public import Foundation

// Remote-side relay provisioning script builders. Static because they
// compose pure script text from raw inputs independent of a session instance
// (the BmuxCore SSH-option-normalization precedent); the script text is
// wire/process behavior pinned by tests — do not alter.
extension RemoteSessionCoordinator {
    /// Script that removes the relay metadata files for `relayPort` and the
    /// `socket_addr` pointer when it still points at that relay.
    public static func remoteRelayMetadataCleanupScript(relayPort: Int) -> String {
        """
        relay_socket='127.0.0.1:\(relayPort)'
        socket_addr_file="$HOME/.bmux/socket_addr"
        if [ -r "$socket_addr_file" ] && [ "$(tr -d '\\r\\n' < "$socket_addr_file")" = "$relay_socket" ]; then
          rm -f "$socket_addr_file"
        fi
        rm -f "$HOME/.bmux/relay/\(relayPort).auth" "$HOME/.bmux/relay/\(relayPort).daemon_path" "$HOME/.bmux/relay/\(relayPort).slot" "$HOME/.bmux/relay/\(relayPort).tty"
        """
    }

    /// Script that kills a stale sshd listener (and its persistent
    /// bmuxd-remote children for `persistentDaemonSlot`) still bound to
    /// `relayPort`, or `nil` when the inputs cannot be matched safely.
    public static func remoteStaleRelayListenerCleanupScript(
        relayPort: Int,
        persistentDaemonSlot: String?
    ) -> String? {
        guard relayPort > 0, relayPort <= 65535 else { return nil }
        guard let persistentDaemonSlot = normalizedPersistentDaemonSlotForRemoteCleanup(persistentDaemonSlot) else {
            return nil
        }

        return """
        bmux_stale_relay_listener_cleanup=1
        bmux_relay_port='\(relayPort)'
        bmux_persistent_slot=\(persistentDaemonSlot.shellSingleQuoted)
        bmux_listener_pids=''
        if command -v lsof >/dev/null 2>&1; then
          bmux_listener_pids="$(lsof -nP -iTCP:"$bmux_relay_port" -sTCP:LISTEN -Fpn 2>/dev/null | awk -v port="$bmux_relay_port" '
            /^p/ { pid = substr($0, 2); next }
            /^n/ {
              name = substr($0, 2)
              if (pid ~ /^[0-9]+$/ && name ~ ("(^|[^0-9])127[.]0[.]0[.]1:" port "$")) {
                seen[pid] = 1
              }
            }
            END {
              for (pid in seen) print pid
            }
          ')"
        fi
        [ -n "$bmux_listener_pids" ] || exit 0
        bmux_ps_output="$(ps -axo pid=,ppid=,command= 2>/dev/null || true)"
        for bmux_listener_pid in $bmux_listener_pids; do
          case "$bmux_listener_pid" in
            ''|*[!0-9]*) continue ;;
          esac
          bmux_listener_command="$(printf '%s\\n' "$bmux_ps_output" | awk -v target="$bmux_listener_pid" '$1 == target { $1 = ""; $2 = ""; sub(/^[[:space:]]+/, ""); print; exit }')"
          case "$bmux_listener_command" in
            *sshd*|*ssh*) ;;
            *) continue ;;
          esac
          bmux_child_pids="$(printf '%s\\n' "$bmux_ps_output" | awk -v parent="$bmux_listener_pid" -v slot="$bmux_persistent_slot" '
            function clean_token(value) {
              gsub(/\\047/, "", value)
              gsub(/"/, "", value)
              gsub(/\\\\/, "", value)
              return value
            }
            function has_token(target, i) {
              for (i = 3; i <= NF; i++) {
                if (clean_token($i) == target) return 1
              }
              return 0
            }
            function next_value(after, i, value) {
              for (i = after + 1; i <= NF; i++) {
                value = clean_token($i)
                if (value != "") return value
              }
              return ""
            }
            function has_exact_slot(i, token, value) {
              for (i = 3; i <= NF; i++) {
                token = clean_token($i)
                if (token == "--slot") {
                  return next_value(i) == slot
                }
                if (token ~ /^--slot=/) {
                  value = substr(token, 8)
                  if (value != "") return value == slot
                  return next_value(i) == slot
                }
              }
              return 0
            }
            $2 == parent &&
            index($0, "bmuxd-remote") &&
            has_token("serve") &&
            has_token("--stdio") &&
            has_token("--persistent") &&
            has_exact_slot() &&
            $1 ~ /^[0-9]+$/ {
              print $1
            }
          ')"
          bmux_cleanup_reason=child
          if [ -z "$bmux_child_pids" ]; then
            bmux_cleanup_reason=metadata
            bmux_metadata_ok=0
            bmux_slot_file="$HOME/.bmux/relay/${bmux_relay_port}.slot"
            bmux_metadata_slot_ok=0
            if [ -r "$bmux_slot_file" ]; then
              bmux_stored_slot="$(tr -d '\\r\\n' < "$bmux_slot_file")"
              [ "$bmux_stored_slot" = "$bmux_persistent_slot" ] && bmux_metadata_slot_ok=1
            fi
            if [ "$bmux_metadata_slot_ok" -eq 1 ]; then
              bmux_daemon_map="$HOME/.bmux/relay/${bmux_relay_port}.daemon_path"
              bmux_auth_file="$HOME/.bmux/relay/${bmux_relay_port}.auth"
              if [ -r "$bmux_daemon_map" ]; then
                bmux_daemon_path="$(tr -d '\\r\\n' < "$bmux_daemon_map")"
                case "$bmux_daemon_path" in
                  *bmuxd-remote*) bmux_metadata_ok=1 ;;
                esac
              fi
              if [ "$bmux_metadata_ok" -ne 1 ] && [ -r "$bmux_auth_file" ]; then
                bmux_auth_payload="$(tr -d '\\r\\n' < "$bmux_auth_file")"
                case "$bmux_auth_payload" in
                  *relay_id*relay_token*) bmux_metadata_ok=1 ;;
                esac
              fi
            fi
            [ "$bmux_metadata_ok" -eq 1 ] || continue
          fi
          kill -TERM "$bmux_listener_pid" $bmux_child_pids 2>/dev/null || true
          for bmux_child_pid in $bmux_child_pids; do
            kill -0 "$bmux_child_pid" 2>/dev/null && kill -KILL "$bmux_child_pid" 2>/dev/null || true
          done
          kill -0 "$bmux_listener_pid" 2>/dev/null && kill -KILL "$bmux_listener_pid" 2>/dev/null || true
          bmux_child_list="$(printf '%s\\n' "$bmux_child_pids" | tr '\\n' ' ' | sed 's/[[:space:]]*$//')"
          printf 'bmux_stale_relay_killed pid=%s children=%s port=%s reason=%s\\n' "$bmux_listener_pid" "$bmux_child_list" "$bmux_relay_port" "$bmux_cleanup_reason"
        done
        """
    }

    static func normalizedPersistentDaemonSlotForRemoteCleanup(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed != ".",
              trimmed != "..",
              trimmed.range(of: "^[A-Za-z0-9._-]{1,128}$", options: .regularExpression) != nil else {
            return nil
        }
        return trimmed
    }

    static func remoteCLIWrapperScript() -> String {
        """
        #!/bin/sh
        set -eu

        daemon="$HOME/.bmux/bin/bmuxd-remote-current"
        socket_path="${BMUX_SOCKET_PATH:-}"
        if [ -z "$socket_path" ] && [ -r "$HOME/.bmux/socket_addr" ]; then
          socket_path="$(tr -d '\\r\\n' < "$HOME/.bmux/socket_addr")"
        fi

        if [ -n "$socket_path" ] && [ "${socket_path#/}" = "$socket_path" ] && [ "${socket_path#*:}" != "$socket_path" ]; then
          relay_port="${socket_path##*:}"
          relay_map="$HOME/.bmux/relay/${relay_port}.daemon_path"
          if [ -r "$relay_map" ]; then
            mapped_daemon="$(tr -d '\\r\\n' < "$relay_map")"
            if [ -n "$mapped_daemon" ] && [ -x "$mapped_daemon" ]; then
              daemon="$mapped_daemon"
            fi
          fi
        fi

        exec "$daemon" "$@"
        """
    }

    static func remoteCLIWrapperInstallScript(daemonRemotePath: String) -> String {
        let trimmedRemotePath = daemonRemotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let daemonPathExpression = remoteDaemonPathShellExpression(trimmedRemotePath)
        return """
        mkdir -p "$HOME/.bmux/bin" "$HOME/.bmux/relay"
        ln -sf \(daemonPathExpression) "$HOME/.bmux/bin/bmuxd-remote-current"
        wrapper_tmp="$HOME/.bmux/bin/.bmux-wrapper.tmp.$$"
        cat > "$wrapper_tmp" <<'BMUXWRAPPER'
        \(remoteCLIWrapperScript())
        BMUXWRAPPER
        chmod 755 "$wrapper_tmp"
        mv -f "$wrapper_tmp" "$HOME/.bmux/bin/bmux"
        """
    }

    static func remoteRelayMetadataInstallScript(
        daemonRemotePath: String,
        relayPort: Int,
        relayID: String,
        relayToken: String,
        persistentDaemonSlot: String? = nil
    ) -> String {
        let trimmedRemotePath = daemonRemotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let daemonPathExpression = remoteDaemonPathShellExpression(trimmedRemotePath)
        let slotMetadataLine: String
        if let slot = normalizedPersistentDaemonSlotForRemoteCleanup(persistentDaemonSlot) {
            slotMetadataLine = "printf '%s' \(slot.shellSingleQuoted) > \"$HOME/.bmux/relay/\(relayPort).slot\"\nchmod 600 \"$HOME/.bmux/relay/\(relayPort).slot\""
        } else {
            slotMetadataLine = "rm -f \"$HOME/.bmux/relay/\(relayPort).slot\""
        }
        let authPayload = """
        {"relay_id":"\(relayID)","relay_token":"\(relayToken)"}
        """
        return """
        umask 077
        mkdir -p "$HOME/.bmux" "$HOME/.bmux/relay"
        chmod 700 "$HOME/.bmux/relay"
        \(remoteCLIWrapperInstallScript(daemonRemotePath: trimmedRemotePath))
        printf '%s' \(daemonPathExpression) > "$HOME/.bmux/relay/\(relayPort).daemon_path"
        \(slotMetadataLine)
        cat > "$HOME/.bmux/relay/\(relayPort).auth" <<'BMUXRELAYAUTH'
        \(authPayload)
        BMUXRELAYAUTH
        chmod 600 "$HOME/.bmux/relay/\(relayPort).auth"
        printf '%s' '127.0.0.1:\(relayPort)' > "$HOME/.bmux/socket_addr"
        """
    }

    static func remoteDaemonPathShellExpression(_ remotePath: String) -> String {
        let trimmedRemotePath = remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedRemotePath.hasPrefix("/") {
            return trimmedRemotePath.shellSingleQuoted
        }
        return "\"$HOME/\(trimmedRemotePath)\""
    }
}
