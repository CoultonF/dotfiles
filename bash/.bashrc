# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

export XDG_CONFIG_HOME=$HOME/.config

export TMUX_CONF="$XDG_CONFIG_HOME/tmux/tmux.conf"

eval "$(starship init bash)"

IS_IN_IDE=0
if [[ "$TERM_PROGRAM" == "vscode" || -n "$INTELLIJ_ENVIRONMENT_READER" ]]; then
  IS_IN_IDE=1
fi
if [ "${IS_IN_IDE}" != "1" ]; then
  # We *are* interactive, and we are not in an IDE, so if we are not already
  # in tmux, start it.
  eval "$(zellij setup --generate-auto-start bash)"
fi
