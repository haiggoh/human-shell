#!/bin/zsh
set -e

zshrc="$HOME/.zshrc"
stamp="$(date '+%Y%m%d-%H%M%S')"
backup="$HOME/.zshrc.human-shell-uninstall.$stamp.bak"

if [[ -f "$zshrc" ]]; then
  cp -p "$zshrc" "$backup"
  python3 - "$zshrc" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
start = "# >>> human-shell >>>"
end = "# <<< human-shell <<<"
pattern = re.compile(rf"(?ms)^[ \t]*{re.escape(start)}\n.*?^[ \t]*{re.escape(end)}[ \t]*\n?")
updated, count = pattern.subn("", text)
path.write_text(updated.rstrip() + "\n", encoding="utf-8")
print("PASS: removed managed .zshrc block." if count else "INFO: managed .zshrc block was absent.")
PY
  if ! zsh -n "$zshrc"; then
    print -u2 "FAIL: remaining .zshrc is invalid; restoring backup."
    cp -p "$backup" "$zshrc"
    exit 1
  fi
  print "PASS: remaining .zshrc syntax is valid."
fi

for app in "$HOME/Applications/Human Shell.app" "$HOME/Applications/Human Shell Failures Only.app"; do
  if [[ -e "$app" ]]; then
    rm -rf "$app"
    print "PASS: removed $app"
  else
    print "INFO: already absent: $app"
  fi
done

print "Human Shell was uninstalled."
print 'Run: source "$HOME/.zshrc"'
