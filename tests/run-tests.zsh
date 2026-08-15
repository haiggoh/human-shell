#!/bin/zsh
# Tests for the parts of Human Shell that can be checked without a terminal:
# the exit-status-to-label table, the right-prompt composition, the one-badge-
# per-command rule, and the history filter. Run with: zsh tests/run-tests.zsh

repo="${0:A:h:h}"

typeset -i passed=0 failed=0

check() {
  local description="$1" expected="$2" actual="$3"

  if [[ "$expected" == "$actual" ]]; then
    (( passed += 1 ))
    print "PASS: $description"
  else
    (( failed += 1 ))
    print -u2 "FAIL: $description"
    print -u2 "  expected: [$expected]"
    print -u2 "  actual:   [$actual]"
  fi
}

# Sourced with HUMAN_SHELL_STATUS unset, so the setup block does not run: no
# hooks are registered and no banner is printed, leaving the functions to test.
source "$repo/human-shell.zsh"

check "sourcing without HUMAN_SHELL_STATUS registers no precmd hook" \
  "" "${precmd_functions[(r)_human_shell_precmd]:-}"

# ---------------------------------------------------------------------------
# The exit-status-to-label table.
# ---------------------------------------------------------------------------

badge_is() {
  local exit_code="$1" expected="$2"
  _human_shell_badge "$exit_code"
  check "exit $exit_code in ${HUMAN_SHELL_STATUS} mode" "$expected" "$HUMAN_SHELL_BADGE"
}

HUMAN_SHELL_STATUS=all

badge_is 0   '%F{green}success [exit 0]%f'
badge_is 1   '%F{red}failed [exit 1]%f'
badge_is 2   '%F{red}failed [exit 2]%f'
badge_is 126 '%F{red}can'\''t run [exit 126]%f'
badge_is 127 '%F{red}not found [exit 127]%f'
badge_is 128 '%F{red}failed [exit 128]%f'
badge_is 129 '%F{yellow}disconnected [exit 129 / SIGHUP]%f'
badge_is 130 '%F{yellow}interrupted [exit 130 / SIGINT]%f'
badge_is 131 '%F{yellow}quit [exit 131 / SIGQUIT]%f'
badge_is 134 '%F{red}aborted [exit 134 / SIGABRT]%f'
badge_is 137 '%F{yellow}killed [exit 137 / SIGKILL]%f'
badge_is 139 '%F{red}crashed [exit 139 / SIGSEGV]%f'
badge_is 141 '%F{yellow}broken pipe [exit 141 / SIGPIPE]%f'
badge_is 142 '%F{yellow}timed out [exit 142 / SIGALRM]%f'
badge_is 143 '%F{yellow}terminated [exit 143 / SIGTERM]%f'

# Signals with no entry of their own are named through kill -l.
badge_is 132 '%F{yellow}signal SIGILL [exit 132]%f'
badge_is 133 '%F{yellow}signal SIGTRAP [exit 133]%f'
badge_is 138 '%F{yellow}signal SIGBUS [exit 138]%f'
badge_is 152 '%F{yellow}signal SIGXCPU [exit 152]%f'
badge_is 159 '%F{yellow}signal SIGUSR2 [exit 159]%f'

# kill -l echoes an unknown signal number straight back, so the label has to
# fall through to the number rather than inventing a name like SIG64.
badge_is 192 '%F{yellow}signal 64 [exit 192]%f'

# Above the signal range the status is just a status again.
badge_is 193 '%F{red}failed [exit 193]%f'
badge_is 255 '%F{red}failed [exit 255]%f'

HUMAN_SHELL_STATUS=failures

badge_is 0   ''
badge_is 1   '%F{red}failed [exit 1]%f'
badge_is 130 '%F{yellow}interrupted [exit 130 / SIGINT]%f'

# ---------------------------------------------------------------------------
# Composition: a right prompt the user already has must survive.
# ---------------------------------------------------------------------------

HUMAN_SHELL_STATUS=all

HUMAN_SHELL_OUTER_RPROMPT='%F{blue}THEME%f'
RPROMPT=''
_human_shell_compose '%F{red}failed [exit 1]%f'
check "badge is composed in front of an existing right prompt" \
  '%F{red}failed [exit 1]%f %F{blue}THEME%f' "$RPROMPT"

_human_shell_compose ''
check "an existing right prompt is restored exactly when there is no badge" \
  '%F{blue}THEME%f' "$RPROMPT"

HUMAN_SHELL_OUTER_RPROMPT=''
_human_shell_compose '%F{red}failed [exit 1]%f'
check "badge stands alone when there is no existing right prompt" \
  '%F{red}failed [exit 1]%f' "$RPROMPT"

_human_shell_compose ''
check "no badge and no existing right prompt leaves an empty right prompt" \
  '' "$RPROMPT"

# A theme that sets RPROMPT from its own hook must be adopted, not discarded.
HUMAN_SHELL_OUTER_RPROMPT=''
HUMAN_SHELL_LAST_RPROMPT=''
HUMAN_SHELL_COMMAND_RAN=0
RPROMPT='%F{magenta}SET-BY-THEME%f'
_human_shell_precmd
check "a right prompt installed by another hook is adopted as the base" \
  '%F{magenta}SET-BY-THEME%f' "$HUMAN_SHELL_OUTER_RPROMPT"
check "adopting another hook's right prompt leaves it on screen unchanged" \
  '%F{magenta}SET-BY-THEME%f' "$RPROMPT"

# ---------------------------------------------------------------------------
# One badge per command.
# ---------------------------------------------------------------------------

HUMAN_SHELL_OUTER_RPROMPT='%F{blue}THEME%f'
RPROMPT='%F{blue}THEME%f'
HUMAN_SHELL_LAST_RPROMPT='%F{blue}THEME%f'

_human_shell_preexec
check "preexec marks that a command ran" "1" "$HUMAN_SHELL_COMMAND_RAN"

(exit 42); _human_shell_precmd
check "precmd reports the status of the command that just ran" \
  '%F{red}failed [exit 42]%f %F{blue}THEME%f' "$RPROMPT"
check "precmd clears the command marker after reporting once" \
  "0" "$HUMAN_SHELL_COMMAND_RAN"

# A bare Enter runs no command, so there is no outcome to report.
_human_shell_precmd
check "a bare Enter clears the badge instead of repeating it" \
  '%F{blue}THEME%f' "$RPROMPT"

# ---------------------------------------------------------------------------
# The launcher's bootstrap line is never recorded in history.
# ---------------------------------------------------------------------------

_human_shell_zshaddhistory 'HUMAN_SHELL_STATUS=all HUMAN_SHELL_LAUNCHER=1 exec /bin/zsh -l'$'\n'
check "the all-status launcher line is refused by the history filter" "1" "$?"

_human_shell_zshaddhistory 'HUMAN_SHELL_STATUS=failures HUMAN_SHELL_LAUNCHER=1 exec /bin/zsh -l'$'\n'
check "the failures-only launcher line is refused by the history filter" "1" "$?"

_human_shell_zshaddhistory 'git status'$'\n'
check "an ordinary command is kept in history" "0" "$?"

_human_shell_zshaddhistory 'human-shell --failures'$'\n'
check "the user-facing command is kept in history" "0" "$?"

# ---------------------------------------------------------------------------
# Usage.
# ---------------------------------------------------------------------------

human-shell --nonsense 2>/dev/null
check "an unknown mode is rejected with status 2" "2" "$?"

# ---------------------------------------------------------------------------
# Scrubbing launcher lines out of history written by earlier versions.
# ---------------------------------------------------------------------------

scrub_dir="$(mktemp -d)"
print ': 1750000001:0;git status'                                        > "$scrub_dir/dirty"
print 'HUMAN_SHELL_STATUS=all HUMAN_SHELL_LAUNCHER=1 exec /bin/zsh -l'  >> "$scrub_dir/dirty"
print ': 1750000003:0;echo one \'                                       >> "$scrub_dir/dirty"
print 'two three'                                                       >> "$scrub_dir/dirty"
print ': 1750000004:0;echo clean'                                        > "$scrub_dir/clean"
chmod 600 "$scrub_dir/dirty" "$scrub_dir/clean"
dirty_inode="$(stat -f '%i' "$scrub_dir/dirty")"

HUMAN_SHELL_HISTORY_BACKUP_DIR="$scrub_dir/backups" \
  zsh "$repo/scripts/scrub-launcher-history.zsh" \
  "$scrub_dir/dirty" "$scrub_dir/clean" "$scrub_dir/dirty" >/dev/null 2>&1
check "scrubbing succeeds" "0" "$?"

check "the launcher line is gone" \
  "0" "$(grep -c 'HUMAN_SHELL_LAUNCHER=1' "$scrub_dir/dirty" || true)"
check "an ordinary entry survives scrubbing" \
  "1" "$(grep -c 'git status' "$scrub_dir/dirty" || true)"
check "a multi-line entry survives scrubbing intact" \
  "1" "$(grep -c '^two three$' "$scrub_dir/dirty" || true)"
check "scrubbing edits in place, preserving the inode" \
  "$dirty_inode" "$(stat -f '%i' "$scrub_dir/dirty")"
check "scrubbing preserves the file mode" "600" "$(stat -f '%Lp' "$scrub_dir/dirty")"
check "a file with nothing to remove is not backed up" \
  "" "$(print -l "$scrub_dir/backups"/**/clean(N))"
check "backups are collected in one directory, not beside the original" \
  "" "$(print -l "$scrub_dir"/*.bak(N))"

HUMAN_SHELL_HISTORY_BACKUP_DIR="$scrub_dir/backups" \
  zsh "$repo/scripts/scrub-launcher-history.zsh" "$scrub_dir/dirty" >/dev/null 2>&1
check "scrubbing again is a no-op that still succeeds" "0" "$?"

rm -rf "$scrub_dir"

# ---------------------------------------------------------------------------
# Shipped sources stay syntactically valid.
# ---------------------------------------------------------------------------

for script in human-shell.zsh install.sh uninstall.sh scripts/scrub-launcher-history.zsh; do
  zsh -n "$repo/$script" 2>/dev/null
  check "$script parses" "0" "$?"
done

if (( $+commands[osacompile] )); then
  scratch="$(mktemp -d)"
  for applet in "Human Shell" "Human Shell Failures Only"; do
    osacompile -o "$scratch/$applet.scpt" "$repo/$applet.applescript" 2>/dev/null
    check "$applet.applescript compiles" "0" "$?"
  done
  rm -rf "$scratch"
else
  print "SKIP: osacompile is unavailable; AppleScript sources were not compiled."
fi

# ---------------------------------------------------------------------------

print
print "$passed passed, $failed failed."
(( failed == 0 ))
