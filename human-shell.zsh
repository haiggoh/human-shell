# Human Shell interactive configuration.

autoload -Uz add-zsh-hook

human-shell() {
  case "${1:---all}" in
    all|--all)
      HUMAN_SHELL_READY=0 HUMAN_SHELL_STATUS=all command zsh -l
      ;;
    failures|failure|--failures|--failure)
      HUMAN_SHELL_READY=0 HUMAN_SHELL_STATUS=failures command zsh -l
      ;;
    *)
      print -u2 "Usage: human-shell [--all|--failures]"
      return 2
      ;;
  esac
}

_human_shell_preexec() {
  typeset -g HUMAN_SHELL_COMMAND_RAN=1
}

_human_shell_precmd() {
  local exit_code=$?
  local signal_number signal_name

  if [[ "${HUMAN_SHELL_COMMAND_RAN:-0}" != "1" ]]; then
    RPROMPT=''
    return
  fi

  if (( exit_code == 0 )); then
    if [[ "$HUMAN_SHELL_STATUS" == "all" ]]; then
      RPROMPT='%F{green}success [exit 0]%f'
    else
      RPROMPT=''
    fi
    return
  fi

  case "$exit_code" in
    126)
      RPROMPT='%F{red}can'\''t run [exit 126]%f'
      ;;
    127)
      RPROMPT='%F{red}not found [exit 127]%f'
      ;;
    129)
      RPROMPT='%F{yellow}disconnected [exit 129 / SIGHUP]%f'
      ;;
    130)
      RPROMPT='%F{yellow}interrupted [exit 130 / SIGINT]%f'
      ;;
    131)
      RPROMPT='%F{yellow}quit [exit 131 / SIGQUIT]%f'
      ;;
    134)
      RPROMPT='%F{red}aborted [exit 134 / SIGABRT]%f'
      ;;
    137)
      RPROMPT='%F{yellow}killed [exit 137 / SIGKILL]%f'
      ;;
    139)
      RPROMPT='%F{red}crashed [exit 139 / SIGSEGV]%f'
      ;;
    141)
      RPROMPT='%F{yellow}broken pipe [exit 141 / SIGPIPE]%f'
      ;;
    142)
      RPROMPT='%F{yellow}timed out [exit 142 / SIGALRM]%f'
      ;;
    143)
      RPROMPT='%F{yellow}terminated [exit 143 / SIGTERM]%f'
      ;;
    128)
      RPROMPT='%F{red}failed [exit 128]%f'
      ;;
    *)
      if (( exit_code >= 129 && exit_code <= 192 )); then
        signal_number=$(( exit_code - 128 ))
        signal_name="$(kill -l "$signal_number" 2>/dev/null || true)"
        signal_name="${signal_name:u}"
        signal_name="${signal_name#SIG}"
        if [[ -n "$signal_name" ]]; then
          RPROMPT="%F{yellow}signal SIG${signal_name} [exit ${exit_code}]%f"
        else
          RPROMPT="%F{yellow}signal ${signal_number} [exit ${exit_code}]%f"
        fi
      else
        RPROMPT="%F{red}failed [exit ${exit_code}]%f"
      fi
      ;;
  esac
}

case "${HUMAN_SHELL_STATUS:-}" in
  all|failures)
    RPROMPT=''
    typeset -g HUMAN_SHELL_COMMAND_RAN=0

    add-zsh-hook -d preexec _human_shell_preexec 2>/dev/null || true
    add-zsh-hook -d precmd _human_shell_precmd 2>/dev/null || true
    add-zsh-hook preexec _human_shell_preexec
    add-zsh-hook precmd _human_shell_precmd

    if [[ "${HUMAN_SHELL_READY:-0}" != "1" ]]; then
      export HUMAN_SHELL_READY=1

      if [[ "${HUMAN_SHELL_LAUNCHER:-0}" == "1" ]]; then
        # Preserve Terminal's Last login line and clear from row 2 downward.
        printf '\033[2;1H\033[J'
      fi

      if [[ "$HUMAN_SHELL_STATUS" == "all" ]]; then
        print -P '%F{green}Human Shell is ready.%f Successes are %F{green}green%f, failures are %F{red}red%f, and interruptions are %F{yellow}yellow%f on the right.'
      else
        print -P '%F{green}Human Shell is ready in failures-only mode.%f %F{red}Failed commands%f appear on the right.'
      fi
    fi
    ;;
esac
