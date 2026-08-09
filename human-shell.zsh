# Human Shell interactive configuration.

autoload -Uz add-zsh-hook

human-shell() {
  case "${1:---all}" in
    all|--all)
      HUMAN_SHELL_STATUS=all command zsh -l
      ;;
    failures|failure|--failures|--failure)
      HUMAN_SHELL_STATUS=failures command zsh -l
      ;;
    *)
      print -u2 "Usage: human-shell [--all|--failures]"
      return 2
      ;;
  esac
}

_human_shell_preexec() {
  case "${HUMAN_SHELL_STATUS:-}" in
    all)
      RPROMPT='%(?.%F{green}[ok 0]%f.%F{red}[exit %?]%f)'
      ;;
    failures)
      RPROMPT='%(?..%F{red}[exit %?]%f)'
      ;;
  esac
}

case "${HUMAN_SHELL_STATUS:-}" in
  all|failures)
    # Keep the initial prompt clean. The preexec hook enables status display only
    # after the user submits the first command.
    RPROMPT=''
    add-zsh-hook -d preexec _human_shell_preexec 2>/dev/null || true
    add-zsh-hook preexec _human_shell_preexec

    if [[ "${HUMAN_SHELL_READY:-0}" != "1" ]]; then
      export HUMAN_SHELL_READY=1

      if [[ "${HUMAN_SHELL_LAUNCHER:-0}" == "1" ]]; then
        # Preserve Terminal's Last login line and clear from row 2 downward.
        printf '\033[2;1H\033[J'
      fi

      if [[ "$HUMAN_SHELL_STATUS" == "all" ]]; then
        print -P '%F{green}Human Shell is ready.%f Every command result appears on the right.'
      else
        print -P '%F{green}Human Shell is ready in failures-only mode.%f Failed commands appear on the right.'
      fi
    fi
    ;;
esac
