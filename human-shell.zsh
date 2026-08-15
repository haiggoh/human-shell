# Human Shell interactive configuration.

autoload -Uz add-zsh-hook

human-shell() {
  local mode

  case "${1:---all}" in
    all|--all)
      mode=all
      ;;
    failures|failure|--failures|--failure)
      mode=failures
      ;;
    *)
      print -u2 "Usage: human-shell [--all|--failures]"
      return 2
      ;;
  esac

  # Already inside a Human Shell: replace this shell rather than stacking a
  # second login shell on top of it, so one exit still returns to the shell
  # the user started from instead of to an intermediate layer.
  if [[ "${HUMAN_SHELL_READY:-0}" == "1" ]]; then
    HUMAN_SHELL_READY=0 HUMAN_SHELL_STATUS="$mode" exec zsh -l
  fi

  HUMAN_SHELL_READY=0 HUMAN_SHELL_STATUS="$mode" command zsh -l
}

_human_shell_preexec() {
  typeset -g HUMAN_SHELL_COMMAND_RAN=1
}

# Keep the launcher's own bootstrap line out of history. The Dock launchers
# start a Human Shell by typing that line into a shell, which would otherwise
# record it like anything the user typed, and it is not a command anyone runs
# by hand. Returning non-zero tells zsh not to save the line at all.
#
# This hook is registered unconditionally, because the shell that would record
# the line is the plain shell that receives it, before it is replaced.
_human_shell_zshaddhistory() {
  [[ "$1" == *'HUMAN_SHELL_LAUNCHER=1'* ]] && return 1
  return 0
}

# Translate an exit status into the badge to display, returned in
# HUMAN_SHELL_BADGE (empty when nothing should be shown). Pure: it reads only
# its argument and HUMAN_SHELL_STATUS, writes no output, and touches no prompt.
_human_shell_badge() {
  local exit_code="$1"
  local signal_number signal_name

  typeset -g HUMAN_SHELL_BADGE=''

  if (( exit_code == 0 )); then
    if [[ "${HUMAN_SHELL_STATUS-}" == "all" ]]; then
      HUMAN_SHELL_BADGE='%F{green}success [exit 0]%f'
    fi
    return 0
  fi

  case "$exit_code" in
    126)
      HUMAN_SHELL_BADGE='%F{red}can'\''t run [exit 126]%f'
      ;;
    127)
      HUMAN_SHELL_BADGE='%F{red}not found [exit 127]%f'
      ;;
    128)
      HUMAN_SHELL_BADGE='%F{red}failed [exit 128]%f'
      ;;
    129)
      HUMAN_SHELL_BADGE='%F{yellow}disconnected [exit 129 / SIGHUP]%f'
      ;;
    130)
      HUMAN_SHELL_BADGE='%F{yellow}interrupted [exit 130 / SIGINT]%f'
      ;;
    131)
      HUMAN_SHELL_BADGE='%F{yellow}quit [exit 131 / SIGQUIT]%f'
      ;;
    134)
      HUMAN_SHELL_BADGE='%F{red}aborted [exit 134 / SIGABRT]%f'
      ;;
    137)
      HUMAN_SHELL_BADGE='%F{yellow}killed [exit 137 / SIGKILL]%f'
      ;;
    139)
      HUMAN_SHELL_BADGE='%F{red}crashed [exit 139 / SIGSEGV]%f'
      ;;
    141)
      HUMAN_SHELL_BADGE='%F{yellow}broken pipe [exit 141 / SIGPIPE]%f'
      ;;
    142)
      HUMAN_SHELL_BADGE='%F{yellow}timed out [exit 142 / SIGALRM]%f'
      ;;
    143)
      HUMAN_SHELL_BADGE='%F{yellow}terminated [exit 143 / SIGTERM]%f'
      ;;
    *)
      if (( exit_code >= 129 && exit_code <= 192 )); then
        signal_number=$(( exit_code - 128 ))
        signal_name="$(kill -l "$signal_number" 2>/dev/null || true)"
        signal_name="${signal_name:u}"
        signal_name="${signal_name#SIG}"
        # An unknown signal number makes kill echo the number straight back,
        # so a numeric answer means there is no name to report.
        if [[ -n "$signal_name" && "$signal_name" != <-> ]]; then
          HUMAN_SHELL_BADGE="%F{yellow}signal SIG${signal_name} [exit ${exit_code}]%f"
        else
          HUMAN_SHELL_BADGE="%F{yellow}signal ${signal_number} [exit ${exit_code}]%f"
        fi
      else
        HUMAN_SHELL_BADGE="%F{red}failed [exit ${exit_code}]%f"
      fi
      ;;
  esac
}

# Publish the badge without taking ownership of RPROMPT. Whatever right prompt
# the rest of the user's configuration produced is kept and shown after the
# badge, and is what remains when there is no badge to show.
_human_shell_compose() {
  local badge="$1"

  if [[ -n "$badge" && -n "${HUMAN_SHELL_OUTER_RPROMPT-}" ]]; then
    RPROMPT="${badge} ${HUMAN_SHELL_OUTER_RPROMPT}"
  elif [[ -n "$badge" ]]; then
    RPROMPT="$badge"
  else
    RPROMPT="${HUMAN_SHELL_OUTER_RPROMPT-}"
  fi

  typeset -g HUMAN_SHELL_LAST_RPROMPT="$RPROMPT"
}

_human_shell_precmd() {
  local exit_code=$?

  # If RPROMPT is not the value this hook last wrote, then a theme or another
  # precmd hook owns it now. Adopt it as the base to compose with instead of
  # overwriting someone else's right prompt.
  if [[ "${RPROMPT-}" != "${HUMAN_SHELL_LAST_RPROMPT-}" ]]; then
    typeset -g HUMAN_SHELL_OUTER_RPROMPT="${RPROMPT-}"
  fi

  if [[ "${HUMAN_SHELL_COMMAND_RAN:-0}" != "1" ]]; then
    _human_shell_compose ''
    return 0
  fi

  # One badge per command: pressing Enter on an empty line reports nothing,
  # because no command ran to have an outcome.
  typeset -g HUMAN_SHELL_COMMAND_RAN=0

  _human_shell_badge "$exit_code"
  _human_shell_compose "$HUMAN_SHELL_BADGE"
}

add-zsh-hook -d zshaddhistory _human_shell_zshaddhistory 2>/dev/null || true
add-zsh-hook zshaddhistory _human_shell_zshaddhistory

case "${HUMAN_SHELL_STATUS:-}" in
  all|failures)
    # Capture the right prompt as it stands when this file is sourced. Source
    # it after any prompt theme so that this precmd hook runs last and the
    # theme's own right prompt is preserved rather than replaced.
    typeset -g HUMAN_SHELL_OUTER_RPROMPT="${RPROMPT-}"
    typeset -g HUMAN_SHELL_LAST_RPROMPT="${RPROMPT-}"
    typeset -g HUMAN_SHELL_BADGE=''
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
