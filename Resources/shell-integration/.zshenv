# vim:ft=zsh
#
# bmux ZDOTDIR bootstrap for zsh.
#
# GhosttyKit already uses a ZDOTDIR injection mechanism for zsh (setting ZDOTDIR
# to Ghostty's integration dir). bmux also needs to run its integration, but
# we must restore the user's real ZDOTDIR immediately so that:
# - /etc/zshrc sets HISTFILE relative to the real ZDOTDIR/HOME (shared history)
# - zsh loads the user's real .zprofile/.zshrc normally (no wrapper recursion)
#
# We restore ZDOTDIR from (in priority order):
# - GHOSTTY_ZSH_ZDOTDIR (set by GhosttyKit when it overwrote ZDOTDIR)
# - BMUX_ZSH_ZDOTDIR (set by bmux when it overwrote a user-provided ZDOTDIR)
# - unset (zsh treats unset ZDOTDIR as $HOME)

if [[ -n "${GHOSTTY_ZSH_ZDOTDIR+X}" ]]; then
    builtin export ZDOTDIR="$GHOSTTY_ZSH_ZDOTDIR"
    builtin unset GHOSTTY_ZSH_ZDOTDIR
elif [[ -n "${BMUX_ZSH_ZDOTDIR+X}" \
   && "$BMUX_ZSH_ZDOTDIR" != "${BMUX_SHELL_INTEGRATION_DIR:-}" \
   && "$BMUX_ZSH_ZDOTDIR" != */Contents/Resources/shell-integration ]]; then
    builtin export ZDOTDIR="$BMUX_ZSH_ZDOTDIR"
    builtin unset BMUX_ZSH_ZDOTDIR
else
    builtin unset ZDOTDIR
    builtin unset BMUX_ZSH_ZDOTDIR
fi

{
    # zsh treats unset ZDOTDIR as if it were HOME. We do the same.
    builtin typeset _bmux_file="${ZDOTDIR-$HOME}/.zshenv"
    [[ ! -r "$_bmux_file" ]] || builtin source -- "$_bmux_file"

    if [[ -o interactive \
       && -z "${ZSH_EXECUTION_STRING:-}" \
       && "${BMUX_SHELL_INTEGRATION:-1}" != "0" \
       && -n "${BMUX_SHELL_INTEGRATION_DIR:-}" \
       && -r "${BMUX_SHELL_INTEGRATION_DIR}/bmux-zsh-integration.zsh" \
       && "${TERM:-}" == "xterm-256color" \
       && -z "${BMUX_ZSH_RESTORE_TERM:-}" ]]; then
        # Keep startup TERM-compatible prompt/theme selection during shell init,
        # then restore the managed xterm-256color identity before the first
        # interactive command executes.
        builtin export BMUX_ZSH_RESTORE_TERM="$TERM"
        builtin export TERM="xterm-ghostty"
        builtin typeset -g _BMUX_DELAY_TERM_RESTORE_UNTIL_FIRST_PROMPT=1
    fi
} always {
    if [[ -o interactive ]]; then
        # We overwrote GhosttyKit's injected ZDOTDIR, so manually load Ghostty's
        # zsh integration if available.
        #
        # We can't rely on GHOSTTY_ZSH_ZDOTDIR here because Ghostty's own zsh
        # bootstrap unsets it before chaining into this bmux wrapper.
        if [[ "${BMUX_LOAD_GHOSTTY_ZSH_INTEGRATION:-0}" == "1" ]]; then
            if [[ -n "${BMUX_SHELL_INTEGRATION_DIR:-}" ]]; then
                builtin typeset _bmux_ghostty="$BMUX_SHELL_INTEGRATION_DIR/ghostty-integration.zsh"
            fi
            if [[ ! -r "${_bmux_ghostty:-}" && -n "${GHOSTTY_RESOURCES_DIR:-}" ]]; then
                builtin typeset _bmux_ghostty="$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration"
            fi
            [[ -r "$_bmux_ghostty" ]] && builtin source -- "$_bmux_ghostty"
        fi

        # Load bmux integration (unless disabled)
        if [[ "${BMUX_SHELL_INTEGRATION:-1}" != "0" && -n "${BMUX_SHELL_INTEGRATION_DIR:-}" ]]; then
            builtin typeset _bmux_integ="$BMUX_SHELL_INTEGRATION_DIR/bmux-zsh-integration.zsh"
            [[ -r "$_bmux_integ" ]] && builtin source -- "$_bmux_integ"
        fi
    fi

    builtin unset _bmux_file _bmux_ghostty _bmux_integ
}
