#!/bin/zsh
# Remove the launchers' bootstrap line from existing zsh history files.
#
# Human Shell 1.2.0 stops the line from being recorded in the first place, with
# a zshaddhistory hook. This script is for history written by earlier versions.
#
# By default it covers the shared history file and Terminal's per-session
# history under ~/.zsh_sessions, because that is where copies accumulate: the
# shell that receives the line records it into the session's history file, and
# the Human Shell that replaces it inherits the same session, so the line comes
# back on every restore of that session.
#
# Each file is backed up before it is touched and edited in place so its
# permissions and ownership are preserved. Files with nothing to remove are left
# alone entirely.
#
# Backups are collected in one timestamped directory rather than left beside the
# originals: Terminal expires its own session files but would never clean up
# stray copies, and there can be hundreds of them.
#
# Usage: scrub-launcher-history.zsh [file ...]
#   HUMAN_SHELL_HISTORY_BACKUP_DIR overrides where backups are collected.

set -e

marker='HUMAN_SHELL_LAUNCHER=1'
backup_root="${HUMAN_SHELL_HISTORY_BACKUP_DIR:-$HOME/.human-shell-history-backups}/$(date '+%Y%m%d-%H%M%S')"

# Return a unique path inside the backup directory for the given history file.
backup_path_for() {
  local candidate="$backup_root/${1:t}"
  local -i suffix=2

  while [[ -e "$candidate" ]]; do
    candidate="$backup_root/${1:t}.$suffix"
    (( suffix += 1 ))
  done

  print -r -- "$candidate"
}

typeset -a targets
if (( $# > 0 )); then
  targets=("$@")
else
  targets=(
    ${HISTFILE:+"$HISTFILE"}
    "$HOME/.zsh_history"
    "$HOME"/.zsh_sessions/*.history(N)
    "$HOME"/.zsh_sessions/*.historynew(N)
  )
fi

# A launcher line is always a single line. A matching line that continues onto
# the next one is left alone, so a multi-line entry can never be orphaned.
count_in() {
  awk -v marker="$marker" '
    index($0, marker) && $0 !~ /\\$/ { hits += 1 }
    END { print hits + 0 }
  ' "$1"
}

typeset -i files_changed=0 lines_removed=0 files_seen=0
typeset -A already_done

for histfile in $targets; do
  [[ -f "$histfile" && -w "$histfile" ]] || continue

  # The same file can arrive twice, e.g. HISTFILE pointing into the session dir.
  key="${histfile:A}"
  [[ -n "${already_done[$key]:-}" ]] && continue
  already_done[$key]=1
  (( files_seen += 1 ))

  matches="$(count_in "$histfile")"
  (( matches == 0 )) && continue

  mkdir -p "$backup_root"
  backup="$(backup_path_for "$histfile")"
  cp -p "$histfile" "$backup"

  scratch="$(mktemp)"
  awk -v marker="$marker" '
    index($0, marker) && $0 !~ /\\$/ { next }
    { print }
  ' "$histfile" > "$scratch"

  # Written through the existing file rather than moved over it, so the inode,
  # and therefore the mode and ownership, are preserved.
  cat "$scratch" > "$histfile"
  rm -f "$scratch"

  remaining="$(count_in "$histfile")"
  if (( remaining != 0 )); then
    print -u2 "FAIL: $remaining line(s) still present in $histfile; restoring the backup."
    cat "$backup" > "$histfile"
    exit 1
  fi

  print "PASS: removed $matches line(s) from $histfile"
  (( files_changed += 1 ))
  (( lines_removed += matches ))
done

print
if (( files_changed == 0 )); then
  print "INFO: checked $files_seen history file(s); no launcher lines found, nothing changed."
else
  print "Removed $lines_removed line(s) from $files_changed of $files_seen history file(s)."
  print "Backups of every file changed:"
  print "  $backup_root"
  print "INFO: open a new shell, or run 'fc -R', to reload history in this session."
fi
