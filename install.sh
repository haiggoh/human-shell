#!/bin/zsh
set -e

repo="${0:A:h}"
zshrc="$HOME/.zshrc"
apps="$HOME/Applications"
stamp="$(date '+%Y%m%d-%H%M%S')"
backup="$HOME/.zshrc.human-shell.$stamp.bak"
config="$repo/human-shell.zsh"
add_to_dock=1

for argument in "$@"; do
  case "$argument" in
    --no-dock)
      add_to_dock=0
      ;;
    --dock)
      add_to_dock=1
      ;;
    *)
      print -u2 "Usage: install.sh [--dock|--no-dock]"
      exit 2
      ;;
  esac
done

for file in "$config" "$repo/Human Shell.applescript" "$repo/Human Shell Failures Only.applescript"; do
  [[ -f "$file" ]] || { print -u2 "FAIL: missing source: $file"; exit 1; }
done

if zsh -n "$config"; then
  print "PASS: human-shell.zsh syntax is valid."
else
  exit_status=$?
  print -u2 "FAIL: human-shell.zsh syntax check exited with status $exit_status."
  exit "$exit_status"
fi

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

if [[ -z "$icon" || ! -f "$icon" ]]; then
  print -u2 "FAIL: the local Terminal icon could not be found."
  exit 1
fi

build_app() {
  local name="$1"
  local source="$2"
  local bundle_id="$3"
  local app="$apps/$name.app"
  local plist="$app/Contents/Info.plist"
  local applet_icon="$app/Contents/Resources/applet.icns"
  local assets="$app/Contents/Resources/Assets.car"

  if [[ -e "$app" ]]; then
    mv "$app" "$apps/$name.$stamp.app"
    print "PASS: backed up existing $name.app."
  fi

  osacompile -o "$app" "$source"

  # AppleScript applets use applet.icns and may prefer Assets.car or
  # CFBundleIconName over a parallel custom icon resource.
  /bin/cat "$icon" > "$applet_icon"
  rm -f "$assets"

  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile applet.icns" "$plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string applet.icns" "$plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $bundle_id" "$plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName $name" "$plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleName string $name" "$plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $name" "$plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $name" "$plist"

  source_icon_hash="$(shasum -a 256 "$icon" | awk '{print $1}')"
  applet_icon_hash="$(shasum -a 256 "$applet_icon" | awk '{print $1}')"
  [[ "$source_icon_hash" == "$applet_icon_hash" ]] || {
    print -u2 "FAIL: applet icon verification failed for $name.app"
    return 1
  }

  [[ ! -e "$assets" ]] || {
    print -u2 "FAIL: conflicting Assets.car remains in $name.app"
    return 1
  }

  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$plist")" == "applet.icns" ]] || {
    print -u2 "FAIL: CFBundleIconFile is incorrect for $name.app"
    return 1
  }

  if /usr/libexec/PlistBuddy -c "Print :CFBundleIconName" "$plist" >/dev/null 2>&1; then
    print -u2 "FAIL: CFBundleIconName still overrides $name.app"
    return 1
  fi

  codesign --force --deep --sign - "$app" >/dev/null 2>&1
  codesign --verify --deep --strict "$app" >/dev/null 2>&1
  touch "$app"

  lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
  if [[ -x "$lsregister" ]]; then
    "$lsregister" -f "$app" >/dev/null 2>&1 || true
  fi

  print "PASS: installed, icon-verified, and signed $name.app."
}

build_app "Human Shell" "$repo/Human Shell.applescript" "io.github.haiggoh.human-shell"
build_app "Human Shell Failures Only" "$repo/Human Shell Failures Only.applescript" "io.github.haiggoh.human-shell.failures-only"

if (( add_to_dock )); then
  if command -v dockutil >/dev/null 2>&1; then
    dockutil --remove "Human Shell" --no-restart >/dev/null 2>&1 || true
    dockutil --remove "Human Shell Failures Only" --no-restart >/dev/null 2>&1 || true
    dockutil --add "$apps/Human Shell.app" --no-restart
    dockutil --add "$apps/Human Shell Failures Only.app"
    print "PASS: added both Human Shell launchers to the Dock."
  else
    print "INFO: dockutil is unavailable; both launchers were installed successfully."
    print "INFO: install it with 'brew install dockutil' to place them automatically,"
    print "INFO: or rerun with --no-dock to skip Dock changes without this notice."
    print "INFO: opening ~/Applications so you can drag either launcher to the Dock."
    open "$apps"
  fi
else
  print "INFO: Dock changes skipped by --no-dock."
fi

killall Finder >/dev/null 2>&1 || true

print
print "Human Shell installation completed."
print "All-status launcher:   $apps/Human Shell.app"
print "Failures-only launcher: $apps/Human Shell Failures Only.app"
print 'Run: source "$HOME/.zshrc"'
