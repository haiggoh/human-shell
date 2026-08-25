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
  typeset -g HUMAN_SHELL_LAST_COMMAND="$1"
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

# Commands whose exit status 1 reports a finding rather than a fault. Running
# `diff` to see what differs, or `grep` to find out whether a pattern is there,
# is the normal case, and "no difference" or "no match" is an answer rather than
# a fault. A red "failed" there reads as an error that did not happen. Status 2
# and above is left alone, because for both families that really is an error.
#
# Keyed by the command as written, so a subcommand form such as `git diff` can
# carry its own entry. Set this in .zshrc before sourcing to replace the table,
# or assign single keys afterwards to extend it:
#
#     HUMAN_SHELL_EXIT1_LABELS[my-checker]='nothing to do'
#
if (( ! ${+HUMAN_SHELL_EXIT1_LABELS} )); then
  typeset -gA HUMAN_SHELL_EXIT1_LABELS=(
    diff         'diff detected'
    diff3        'diff detected'
    colordiff    'diff detected'
    cmp          'diff detected'
    'git diff'   'diff detected'

    grep         'no match'
    egrep        'no match'
    fgrep        'no match'
    rg           'no match'
    ag           'no match'
    ack          'no match'
    'git grep'   'no match'
  )
fi

# Look up the label for status 1 from the command line that produced it,
# returned in REPLY (empty when status 1 is a genuine failure).
#
# Only a lone simple command is classified. In a pipeline, an && list or a
# ; list the status belongs to some other command, so applying the table there
# would label the wrong thing.
_human_shell_exit1_label() {
  local line="$1" first second
  local -a words

  REPLY=''
  [[ -n "$line" ]] || return 0

  # The status of a compound line is not the status of the command named in it.
  [[ "$line" == *('|'|';'|'&&'|$'\n')* ]] && return 0
  [[ "${line%%[[:space:]]}" == *'&' ]] && return 0

  words=(${(z)line})

  # Leading assignments and wrappers pass the status through, so look past them.
  while (( $#words )); do
    case "${words[1]}" in
      *=*)                                  shift words ;;
      sudo|command|builtin|nice|nohup|time) shift words ;;
      *) break ;;
    esac
  done
  (( $#words )) || return 0

  first="${words[1]:t}"
  second="${words[2]-}"

  # A two-word form such as `git diff` is matched ahead of the bare command.
  if [[ -n "$second" ]] && (( ${+HUMAN_SHELL_EXIT1_LABELS[$first $second]} )); then
    REPLY="${HUMAN_SHELL_EXIT1_LABELS[$first $second]}"
    return 0
  fi

  REPLY="${HUMAN_SHELL_EXIT1_LABELS[$first]-}"
  return 0
}

# Record one badge in both the forms the rest of the file needs: the prompt
# string that carries the colour, and the plain text whose width decides where
# the line starts.
_human_shell_set_badge() {
  typeset -g HUMAN_SHELL_BADGE_TEXT="$2"
  typeset -g HUMAN_SHELL_BADGE="%F{$1}$2%f"
}

# Translate an exit status, and the command line that produced it, into the
# badge to display. Returned in HUMAN_SHELL_BADGE as a prompt string and in
# HUMAN_SHELL_BADGE_TEXT as plain text, both empty when nothing should be
# shown. Pure: it reads only its arguments, HUMAN_SHELL_STATUS and the exit-1
# table, writes no output, and touches no prompt.
_human_shell_badge() {
  local exit_code="$1" command="${2-}"
  local signal_number signal_name

  typeset -g HUMAN_SHELL_BADGE=''
  typeset -g HUMAN_SHELL_BADGE_TEXT=''

  if (( exit_code == 0 )); then
    if [[ "${HUMAN_SHELL_STATUS-}" == "all" ]]; then
      _human_shell_set_badge green 'success [exit 0]'
    fi
    return 0
  fi

  # A command that reports a finding through status 1 has not failed.
  if (( exit_code == 1 )); then
    _human_shell_exit1_label "$command"
    if [[ -n "$REPLY" ]]; then
      _human_shell_set_badge yellow "$REPLY [exit 1]"
      return 0
    fi
  fi

  case "$exit_code" in
    126)
      _human_shell_set_badge red 'can'\''t run [exit 126]'
      ;;
    127)
      _human_shell_set_badge red 'not found [exit 127]'
      ;;
    128)
      _human_shell_set_badge red 'failed [exit 128]'
      ;;
    129)
      _human_shell_set_badge yellow 'disconnected [exit 129 / SIGHUP]'
      ;;
    130)
      _human_shell_set_badge yellow 'interrupted [exit 130 / SIGINT]'
      ;;
    131)
      _human_shell_set_badge yellow 'quit [exit 131 / SIGQUIT]'
      ;;
    134)
      _human_shell_set_badge red 'aborted [exit 134 / SIGABRT]'
      ;;
    137)
      _human_shell_set_badge yellow 'killed [exit 137 / SIGKILL]'
      ;;
    139)
      _human_shell_set_badge red 'crashed [exit 139 / SIGSEGV]'
      ;;
    141)
      _human_shell_set_badge yellow 'broken pipe [exit 141 / SIGPIPE]'
      ;;
    142)
      _human_shell_set_badge yellow 'timed out [exit 142 / SIGALRM]'
      ;;
    143)
      _human_shell_set_badge yellow 'terminated [exit 143 / SIGTERM]'
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
          _human_shell_set_badge yellow "signal SIG${signal_name} [exit ${exit_code}]"
        else
          _human_shell_set_badge yellow "signal ${signal_number} [exit ${exit_code}]"
        fi
      else
        _human_shell_set_badge red "failed [exit ${exit_code}]"
      fi
      ;;
  esac
}

# Print an outcome on its own line, right-aligned, directly beneath the output
# of the command it describes.
#
# The outcome has to be written into the scrollback rather than into RPROMPT.
# A right prompt belongs to the prompt it is drawn with, which is the prompt
# where the *next* command is typed, so the scrollback ended up reading
# `% echo two          failed [exit 1]` when it was the command before it that
# failed. Printing means every command keeps its own verdict, in the right
# place, for as long as the scrollback lasts -- and RPROMPT is left entirely
# alone, so any prompt theme keeps its right prompt untouched.
_human_shell_report() {
  local badge="$1" text="$2" padding pad='' empty=''

  [[ -n "$badge" ]] || return 0

  # One column short of the right edge, as zsh places RPROMPT: writing the
  # final cell can leave a terminal's pending-wrap flag set and cost a blank
  # line.
  padding=$(( ${COLUMNS:-80} - ${#text} - 1 ))
  (( padding > 0 )) && pad="${(l:$padding:)empty}"

  print -P -- "${pad}${badge}"
}

_human_shell_precmd() {
  local exit_code=$?

  if [[ "${HUMAN_SHELL_COMMAND_RAN:-0}" != "1" ]]; then
    return 0
  fi

  # One report per command: pressing Enter on an empty line reports nothing,
  # because no command ran to have an outcome. Reports already printed stay
  # exactly where they were printed.
  typeset -g HUMAN_SHELL_COMMAND_RAN=0

  _human_shell_badge "$exit_code" "${HUMAN_SHELL_LAST_COMMAND-}"
  _human_shell_report "$HUMAN_SHELL_BADGE" "$HUMAN_SHELL_BADGE_TEXT"
}

add-zsh-hook -d zshaddhistory _human_shell_zshaddhistory 2>/dev/null || true
add-zsh-hook zshaddhistory _human_shell_zshaddhistory

case "${HUMAN_SHELL_STATUS:-}" in
  all|failures)
    typeset -g HUMAN_SHELL_BADGE=''
    typeset -g HUMAN_SHELL_BADGE_TEXT=''
    typeset -g HUMAN_SHELL_LAST_COMMAND=''
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

        # Once only. The launcher exports this, so without unsetting it here a
        # later mode switch in the same window would inherit it and clear the
        # screen again, discarding the scrollback the user was reading.
        unset HUMAN_SHELL_LAUNCHER
      fi

      if [[ "$HUMAN_SHELL_STATUS" == "all" ]]; then
        print -P '%F{green}Human Shell is ready.%f Every command reports on the right, under its own output: %F{green}green%f succeeded, %F{red}red%f failed, %F{yellow}yellow%f was interrupted or found a difference.'
      else
        print -P '%F{green}Human Shell is ready in failures-only mode.%f %F{red}Failed commands%f report on the right, under their own output.'
      fi
    fi
    ;;
esac
