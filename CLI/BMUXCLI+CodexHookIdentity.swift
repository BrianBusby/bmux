import Foundation

extension BMUXCLI {
    /// Bound the pre-detach probe to one second and never emit captured argv.
    static let codexHookIdentityAttestationShell = #"""
BMUX_CODEX_HOOK_IDENTITY_VERIFIED=0
if parent_info=$(/usr/bin/perl -e 'alarm 1; exec @ARGV' /bin/ps -ww -p "$PPID" -o ucomm= -o args= 2>/dev/null); then
  case "$parent_info" in
    codex[[:space:]]*)
      BMUX_CODEX_HOOK_IDENTITY_VERIFIED=1
      case " $parent_info " in
        *" app-server "*) case " $parent_info " in *" --managed-daemon "*) BMUX_CODEX_HOOK_IDENTITY_VERIFIED=0 ;; esac ;;
      esac ;;
  esac
fi
export BMUX_CODEX_HOOK_IDENTITY_VERIFIED
"""#
}
