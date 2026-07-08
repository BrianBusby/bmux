# vim:ft=zsh
#
# Compatibility shim: with the current integration model, bmux restores
# ZDOTDIR in .zshenv so this file should never be reached. If it is, restore
# ZDOTDIR and behave like vanilla zsh by sourcing the user's .zshrc.

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

builtin typeset _bmux_file="${ZDOTDIR-$HOME}/.zshrc"
[[ ! -r "$_bmux_file" ]] || builtin source -- "$_bmux_file"
builtin unset _bmux_file
