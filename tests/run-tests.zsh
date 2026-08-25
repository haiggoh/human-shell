#!/bin/zsh
# Tests for the parts of Human Shell that can be checked without a terminal:
# the exit-status-to-label table, the exit-1 semantics table, the right-aligned
# report line, the one-report-per-command rule, and the history filter.
# Run with: zsh tests/run-tests.zsh

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
  local exit_code="$1" expected="$2" command="${3-}"
  _human_shell_badge "$exit_code" "$command"
  check "exit $exit_code${command:+ after \`$command\`} in ${HUMAN_SHELL_STATUS} mode" \
    "$expected" "$HUMAN_SHELL_BADGE"
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
# Exit status 1 from a command that reports a finding, not a fault.
# ---------------------------------------------------------------------------

HUMAN_SHELL_STATUS=all

badge_is 1 '%F{yellow}diff detected [exit 1]%f' 'diff -u a.txt b.txt'
badge_is 1 '%F{yellow}diff detected [exit 1]%f' 'cmp a.bin b.bin'
badge_is 1 '%F{yellow}diff detected [exit 1]%f' 'colordiff a b'
badge_is 1 '%F{yellow}diff detected [exit 1]%f' 'diff3 a b c'

# The subcommand form is matched ahead of the bare command name.
badge_is 1 '%F{yellow}diff detected [exit 1]%f' 'git diff --exit-code'

# The search family reports "no lines selected" through status 1 as well.
badge_is 1 '%F{yellow}no match [exit 1]%f' 'grep -c TODO notes.txt'
badge_is 1 '%F{yellow}no match [exit 1]%f' 'egrep needle notes.txt'
badge_is 1 '%F{yellow}no match [exit 1]%f' 'fgrep needle notes.txt'
badge_is 1 '%F{yellow}no match [exit 1]%f' 'rg needle .'
badge_is 1 '%F{yellow}no match [exit 1]%f' 'ag needle .'
badge_is 1 '%F{yellow}no match [exit 1]%f' 'ack needle .'
badge_is 1 '%F{yellow}no match [exit 1]%f' 'git grep needle'

# For grep, status 2 is a real error: an unreadable file or a bad pattern.
badge_is 2 '%F{red}failed [exit 2]%f' 'grep needle /nope/x'

# A command not in the table is still a plain failure at status 1.
badge_is 1 '%F{red}failed [exit 1]%f' 'ls /nope'
badge_is 1 '%F{red}failed [exit 1]%f' 'git status'
badge_is 1 '%F{red}failed [exit 1]%f' ''

# For diff, status 2 really is an error, so it stays red.
badge_is 2   '%F{red}failed [exit 2]%f'   'diff -u a.txt b.txt'
badge_is 127 '%F{red}not found [exit 127]%f' 'diff -u a.txt b.txt'

# Status 0 is unaffected by the table.
badge_is 0 '%F{green}success [exit 0]%f' 'diff -u a.txt a.txt'

# The label is reported in failures-only mode too: a difference is worth seeing.
HUMAN_SHELL_STATUS=failures
badge_is 1 '%F{yellow}diff detected [exit 1]%f' 'diff -u a.txt b.txt'
HUMAN_SHELL_STATUS=all

label_is() {
  local description="$1" expected="$2" line="$3"
  _human_shell_exit1_label "$line"
  check "$description" "$expected" "$REPLY"
}

label_is "an absolute path is matched by its command name" \
  "diff detected" "/usr/bin/diff a b"
label_is "leading variable assignments are looked past" \
  "diff detected" "LC_ALL=C diff a b"
label_is "a wrapper that passes the status through is looked past" \
  "diff detected" "sudo diff /etc/a /etc/b"
label_is "a redirection does not stop the command being recognised" \
  "diff detected" "diff a b > /tmp/out 2>&1"

# In a compound line the status belongs to some other command, so the table
# must not be applied: `diff a b | head` reports head's status, not diff's.
label_is "a pipeline is not classified" "" "diff a b | head"
label_is "an && list is not classified"  "" "diff a b && echo same"
label_is "an || list is not classified"  "" "diff a b || echo differs"
label_is "a ; list is not classified"    "" "diff a b; echo done"
label_is "a background job is not classified" "" "diff a b &"
label_is "an empty line is not classified" "" ""
label_is "a command outside the table has no label" "" "ls -l"

# The table is a documented extension point, so a user's entry must be honoured.
HUMAN_SHELL_EXIT1_LABELS[my-checker]='nothing to do'
label_is "an entry added by the user is honoured" "nothing to do" "my-checker --all"
unset "HUMAN_SHELL_EXIT1_LABELS[my-checker]"

# A user's own table must survive sourcing, and the default must be installed
# for a user who has none. Both in a clean shell: sourcing with the mode set
# registers the real hooks, which would then overwrite this harness's state.
label_in_fresh_shell() {
  local description="$1" expected="$2" preamble="$3" line="$4"
  check "$description" "$expected" \
    "$(zsh -c "$preamble
               source '$repo/human-shell.zsh'
               _human_shell_exit1_label '$line'
               print -r -- \$REPLY")"
}

label_in_fresh_shell "the default table is installed for a user who has none" \
  "diff detected" "" "diff a b"
label_in_fresh_shell "the default table ships the search family too" \
  "no match" "" "grep needle notes.txt"
label_in_fresh_shell "sourcing does not overwrite a table the user set" \
  "only this" "typeset -gA HUMAN_SHELL_EXIT1_LABELS=(mine 'only this')" "mine --go"
label_in_fresh_shell "a user's own table replaces the default rather than merging" \
  "" "typeset -gA HUMAN_SHELL_EXIT1_LABELS=(mine 'only this')" "diff a b"

# ---------------------------------------------------------------------------
# The report line: right-aligned, and printed only when there is a badge.
# ---------------------------------------------------------------------------

COLUMNS=40

strip_colour() { sed $'s/\e\\[[0-9;]*m//g' }

# COLUMNS 40, a 15-character badge, one column reserved at the right edge.
check "the report is right-aligned one column short of the terminal width" \
  "                        failed [exit 1]" \
  "$(_human_shell_report '%F{red}failed [exit 1]%f' 'failed [exit 1]' | strip_colour)"

check "the report carries the colour of the badge" \
  "1" \
  "$(_human_shell_report '%F{red}failed [exit 1]%f' 'failed [exit 1]' \
     | grep -c $'\e\\[31m')"

check "no badge prints nothing at all" \
  "" "$(_human_shell_report '' '')"

# A badge wider than the terminal is printed rather than shifted off-screen.
COLUMNS=8
check "a badge wider than the terminal is still printed in full" \
  "failed [exit 1]" \
  "$(_human_shell_report '%F{red}failed [exit 1]%f' 'failed [exit 1]' | strip_colour)"

unset COLUMNS

# RPROMPT belongs to the prompt it is drawn with, which is the prompt where the
# next command is typed. Reporting there mislabelled the following command, so
# nothing in Human Shell may write to RPROMPT at all any more.
check "the shipped file never assigns RPROMPT" \
  "0" "$(grep -c '^[^#]*RPROMPT=' "$repo/human-shell.zsh" || true)"

# ---------------------------------------------------------------------------
# One report per command.
# ---------------------------------------------------------------------------

HUMAN_SHELL_COMMAND_RAN=0
HUMAN_SHELL_LAST_COMMAND=''

_human_shell_preexec 'false'
check "preexec marks that a command ran" "1" "$HUMAN_SHELL_COMMAND_RAN"
check "preexec remembers the command line" "false" "$HUMAN_SHELL_LAST_COMMAND"

check "precmd reports the status of the command that just ran" \
  "failed [exit 42]" \
  "$( (exit 42); _human_shell_precmd 2>&1 | sed $'s/\e\\[[0-9;]*m//g;s/^ *//' )"

# The subshell above cannot clear the marker in this shell, so run it here too.
(exit 42); _human_shell_precmd >/dev/null
check "precmd clears the command marker after reporting once" \
  "0" "$HUMAN_SHELL_COMMAND_RAN"

# A bare Enter runs no command, so there is no outcome to report -- and the
# report already printed for the previous command stays in the scrollback.
check "a bare Enter prints nothing rather than repeating the last report" \
  "" "$(_human_shell_precmd 2>&1)"

# The command line reaches the table through precmd, not only through a direct
# call, so a real diff is reported as a difference end to end.
_human_shell_preexec 'diff -u a.txt b.txt'
check "a diff reported through precmd is a yellow difference, not a red failure" \
  "diff detected [exit 1]" \
  "$( (exit 1); _human_shell_precmd 2>&1 | sed $'s/\e\\[[0-9;]*m//g;s/^ *//' )"
HUMAN_SHELL_COMMAND_RAN=0

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
# The launcher's one-time screen clear does not survive into a mode switch.
# ---------------------------------------------------------------------------

check "the launcher marker is consumed, so a mode switch keeps the scrollback" \
  "gone" \
  "$(HUMAN_SHELL_STATUS=all HUMAN_SHELL_READY=0 HUMAN_SHELL_LAUNCHER=1 \
     zsh -c "source '$repo/human-shell.zsh' >/dev/null 2>&1
             print -r -- \${HUMAN_SHELL_LAUNCHER:-gone}")"

check "a shell started without the launcher is unaffected" \
  "gone" \
  "$(HUMAN_SHELL_STATUS=all HUMAN_SHELL_READY=0 \
     zsh -c "source '$repo/human-shell.zsh' >/dev/null 2>&1
             print -r -- \${HUMAN_SHELL_LAUNCHER:-gone}")"

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
# Reaping superseded backups. Both installers write a timestamped backup per
# run so a failed install can be rolled back, and both call this to stop the
# backups accumulating once the install has succeeded.
# ---------------------------------------------------------------------------

reaper="$repo/scripts/reap-backups.zsh"

# Build a directory of backups with distinct, ordered modification times.
# Returns the path in REPLY.
make_backups() {
  local kind="$1" count="$2" prefix="${3:-.previous-}" suffix="${4:-}"
  local dir entry index
  dir="$(mktemp -d)"
  for index in {1..$count}; do
    entry="$dir/${prefix}2026081${index}-120000${suffix}"
    if [[ "$kind" == directory ]]; then
      mkdir -p "$entry"
      print "copy $index" > "$entry/human-shell.zsh"
    else
      print "backup $index" > "$entry"
    fi
    touch -t "2026081${index}1200" "$entry"
  done
  REPLY="$dir"
}

# Names of the surviving entries, oldest first, so expectations read in order.
survivors() {
  print -l "$1"/*(NDn) | sed "s|^$1/||" | tr '\n' ' ' | sed 's/ $//'
}

make_backups directory 5
dir="$REPLY"
zsh "$reaper" --dir "$dir" --prefix '.previous-' --keep 3 >/dev/null
check "reaping keeps the newest backups and removes the oldest" \
  ".previous-20260813-120000 .previous-20260814-120000 .previous-20260815-120000" \
  "$(survivors "$dir")"

zsh "$reaper" --dir "$dir" --prefix '.previous-' --keep 3 >/dev/null
check "reaping again is a no-op" "3" "$(print -l "$dir"/*(ND) | grep -c .)"

zsh "$reaper" --dir "$dir" --prefix '.previous-' --keep 0 >/dev/null
check "keep 0 removes every backup" "" "$(survivors "$dir")"
rm -rf "$dir"

# The message is user-facing, so it has to agree with itself about number.
make_backups directory 2
dir="$REPLY"
check "pruning exactly one is reported in the singular" \
  "PASS: pruned 1 superseded user copy, kept the newest 1." \
  "$(zsh "$reaper" --dir "$dir" --prefix '.previous-' --keep 1 --label 'user copy')"
rm -rf "$dir"

make_backups directory 4
dir="$REPLY"
check "pruning several is reported in the plural" \
  "PASS: pruned 3 superseded user copies, kept the newest 1." \
  "$(zsh "$reaper" --dir "$dir" --prefix '.previous-' --keep 1 \
     --label 'user copy' --label-plural 'user copies')"
rm -rf "$dir"

make_backups directory 3
dir="$REPLY"
check "a label the naive rule fits needs no explicit plural" \
  "PASS: pruned 2 superseded backups, kept the newest 1." \
  "$(zsh "$reaper" --dir "$dir" --prefix '.previous-' --keep 1)"
rm -rf "$dir"

# The .zshrc backups are files with a suffix, not directories.
make_backups file 4 '.zshrc.human-shell.' '.bak'
dir="$REPLY"
zsh "$reaper" --dir "$dir" --prefix '.zshrc.human-shell.' --suffix '.bak' \
  --keep 2 --kind file >/dev/null
check "file backups are reaped by prefix and suffix" \
  ".zshrc.human-shell.20260813-120000.bak .zshrc.human-shell.20260814-120000.bak" \
  "$(survivors "$dir")"

# Selection must be narrow: a similar name that is not ours has to survive.
print 'unrelated' > "$dir/.zshrc.20260808-152824.bak"
print 'mine' > "$dir/.zshrc.prototype-removal.20260825-000000.bak"
print 'wrong suffix' > "$dir/.zshrc.human-shell.20260801-120000.txt"
zsh "$reaper" --dir "$dir" --prefix '.zshrc.human-shell.' --suffix '.bak' \
  --keep 0 --kind file >/dev/null
check "a backup with a different prefix is not ours to remove" \
  "0" "$([[ -f "$dir/.zshrc.20260808-152824.bak" ]] && print 0 || print MISSING)"
check "a backup with a longer prefix is not ours to remove" \
  "0" "$([[ -f "$dir/.zshrc.prototype-removal.20260825-000000.bak" ]] && print 0 || print MISSING)"
check "a matching prefix with the wrong suffix is left alone" \
  "0" "$([[ -f "$dir/.zshrc.human-shell.20260801-120000.txt" ]] && print 0 || print MISSING)"
rm -rf "$dir"

# A directory reaper must not delete files, and a file reaper must not delete
# directories, or one installer's backups would eat the other's.
make_backups file 3 '.previous-' ''
dir="$REPLY"
zsh "$reaper" --dir "$dir" --prefix '.previous-' --keep 0 --kind directory >/dev/null
check "a file is not removed by a directory reaper" \
  "3" "$(print -l "$dir"/*(ND.) | grep -c .)"
zsh "$reaper" --dir "$dir" --prefix '.previous-' --keep 0 --kind file >/dev/null
check "the same entries are removed once the kind matches" \
  "0" "$(print -l "$dir"/*(ND.) | grep -c .)"
rm -rf "$dir"

# Live state must never be a candidate.
make_backups directory 3
dir="$REPLY"
mkdir -p "$dir/current"
zsh "$reaper" --dir "$dir" --prefix '.previous-' --keep 0 >/dev/null
check "the live installation is never a reaping candidate" \
  "0" "$([[ -d "$dir/current" ]] && print 0 || print DESTROYED)"
rm -rf "$dir"

# An empty prefix would match every entry in the directory, so it is refused
# rather than defaulted. This is the guard that keeps a caller bug from
# deleting the user's home directory contents.
scratch="$(mktemp -d)"
print 'precious' > "$scratch/keep-me"
zsh "$reaper" --dir "$scratch" --prefix '' --keep 0 --kind file >/dev/null 2>&1
check "an empty prefix is refused with status 2" "2" "$?"
check "an empty prefix deletes nothing" \
  "0" "$([[ -f "$scratch/keep-me" ]] && print 0 || print DESTROYED)"

zsh "$reaper" --prefix '.previous-' >/dev/null 2>&1
check "a missing --dir is refused with status 2" "2" "$?"

zsh "$reaper" --dir "$scratch" --prefix 'x' --keep 'lots' >/dev/null 2>&1
check "a non-numeric --keep is refused with status 2" "2" "$?"

zsh "$reaper" --dir "$scratch" --prefix 'x' --kind socket >/dev/null 2>&1
check "an unknown --kind is refused with status 2" "2" "$?"

zsh "$reaper" --bogus >/dev/null 2>&1
check "an unknown argument is refused with status 2" "2" "$?"
rm -rf "$scratch"

# The first install has no backups yet, and an uninstalled tree may be absent.
zsh "$reaper" --dir "/nonexistent-$$" --prefix '.previous-' >/dev/null 2>&1
check "a directory that does not exist succeeds quietly" "0" "$?"

check "a directory with no matching backups prints nothing" \
  "" "$(scratch="$(mktemp -d)"; zsh "$reaper" --dir "$scratch" --prefix '.previous-'; rmdir "$scratch")"

# The installer has to actually call the reaper, or none of the above runs.
# Assert the invocation, not the mention: a mutation that replaced `zsh` with
# `true` left the filename in place and this test passed anyway.
check "install.sh actually invokes the reaper, not just mentions it" \
  "1" "$(grep -cE '^[[:space:]]*zsh "\$repo/scripts/reap-backups\.zsh"' "$repo/install.sh")"
check "install.sh reaps the backups it writes itself" \
  "1" "$(grep -c "prefix '.zshrc.human-shell.'" "$repo/install.sh")"

# ---------------------------------------------------------------------------
# Shipped sources stay syntactically valid.
# ---------------------------------------------------------------------------

for script in human-shell.zsh install.sh uninstall.sh scripts/scrub-launcher-history.zsh scripts/reap-backups.zsh; do
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
