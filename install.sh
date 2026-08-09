#!/bin/zsh
set -e

repo="${0:A:h}"
zshrc="$HOME/.zshrc"
apps="$HOME/Applications"
stamp="$(date '+%Y%m%d-%H%M%S')"
backup="$HOME/.zshrc.human-shell.$stamp.bak"
config="$repo/human-shell.zsh"

for file in "$config" "$repo/Human Shell.applescript" "$repo/Human Shell Failures Only.applescript"; do
  [[ -f "$file" ]] || { print -u2 "FAIL: missing source: $file"; exit 1; }
done

zsh -n "$config"
mkdir -p "$apps"
[[ -f "$zshrc" ]] || : > "$zshrc"
cp -p "$zshrc" "$backup"
print "PASS: backed up zsh configuration:"
print "  $backup"

python3 - "$zshrc" "$config" <<'PY'
from pathlib import Path
import re
import sys

zshrc = Path(sys.argv[1])
config = Path(sys.argv[2])
text = zshrc.read_text(encoding="utf-8")
start = "# >>> human-shell >>>"
end = "# <<< human-shell <<<"
pattern = re.compile(rf"(?ms)^[ \t]*{re.escape(start)}\n.*?^[ \t]*{re.escape(end)}[ \t]*\n?")
text = pattern.sub("", text)
path = str(config).replace("\\", "\\\\").replace('"', '\\"')
block = f'{start}\nsource "{path}"\n{end}\n'
zshrc.write_text(text.rstrip() + "\n\n" + block, encoding="utf-8")
PY

if ! zsh -n "$zshrc"; then
  print -u2 "FAIL: updated .zshrc is invalid; restoring backup."
  cp -p "$backup" "$zshrc"
  exit 1
fi
print "PASS: updated .zshrc syntax is valid."

resources="/System/Applications/Utilities/Terminal.app/Contents/Resources"
icon=""
for candidate in "$resources/Terminal.icns" "$resources/AppIcon.icns"; do
  [[ -f "$candidate" ]] && { icon="$candidate"; break; }
done
[[ -n "$icon" ]] || icon="$(find "$resources" -maxdepth 1 -type f -name '*.icns' -print 2>/dev/null | head -1)"

build_app() {
  local name="$1"
  local source="$2"
  local app="$apps/$name.app"

  if [[ -e "$app" ]]; then
    mv "$app" "$apps/$name.$stamp.app"
    print "PASS: backed up existing $name.app."
  fi

  osacompile -o "$app" "$source"

  if [[ -n "$icon" && -f "$icon" ]]; then
    local destination="$app/Contents/Resources/Terminal.icns"
    /bin/cat "$icon" > "$destination"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile Terminal.icns" "$app/Contents/Info.plist" 2>/dev/null || \
      /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string Terminal.icns" "$app/Contents/Info.plist"
    [[ "$(shasum -a 256 "$icon" | awk '{print $1}')" == "$(shasum -a 256 "$destination" | awk '{print $1}')" ]] || {
      print -u2 "FAIL: icon verification failed for $name.app"
      return 1
    }
  else
    print -u2 "WARNING: Terminal icon not found for $name.app"
  fi

  codesign --force --deep --sign - "$app" >/dev/null 2>&1
  codesign --verify --deep --strict "$app" >/dev/null 2>&1
  touch "$app"
  print "PASS: installed and verified $name.app."
}

build_app "Human Shell" "$repo/Human Shell.applescript"
build_app "Human Shell Failures Only" "$repo/Human Shell Failures Only.applescript"

print
print "Human Shell installation completed."
print "Default all-status app: $apps/Human Shell.app"
print "Failures-only app:     $apps/Human Shell Failures Only.app"
print 'Run: source "$HOME/.zshrc"'
