#!/usr/bin/env python3
from __future__ import annotations
import gzip, hashlib, io, os, stat, sys, tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION = sys.argv[1] if len(sys.argv) > 1 else "1.1.1"
DIST = ROOT / "dist"
PREFIX = f"human-shell-{VERSION}"
FILES = [
    "human-shell.zsh", "Human Shell.applescript",
    "Human Shell Failures Only.applescript", "install.sh", "uninstall.sh",
    "README.md", "LICENSE", "CHANGELOG.md",
]
DIST.mkdir(exist_ok=True)
archive = DIST / f"{PREFIX}.tar.gz"
raw = io.BytesIO()
with tarfile.open(fileobj=raw, mode="w", format=tarfile.PAX_FORMAT) as tf:
    for name in FILES:
        data = (ROOT / name).read_bytes()
        info = tarfile.TarInfo(f"{PREFIX}/{name}")
        info.size = len(data)
        info.mtime = 0
        info.uid = info.gid = 0
        info.uname = info.gname = ""
        info.mode = 0o755 if name in {"install.sh", "uninstall.sh"} else 0o644
        tf.addfile(info, io.BytesIO(data))
archive.write_bytes(gzip.compress(raw.getvalue(), compresslevel=9, mtime=0))
archive_sha = hashlib.sha256(archive.read_bytes()).hexdigest()

installer = DIST / f"human-shell-installer-v{VERSION}.zsh"
installer.write_text(f'''#!/bin/zsh
set -e
version="{VERSION}"
expected_sha="{archive_sha}"
url="https://github.com/haiggoh/human-shell/releases/download/v{VERSION}/human-shell-{VERSION}.tar.gz"
tmp="$(mktemp -d "${{TMPDIR:-/tmp}}/human-shell.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
archive="$tmp/human-shell.tar.gz"
if [[ -n "${{HUMAN_SHELL_ARCHIVE:-}}" ]]; then
  cp "$HUMAN_SHELL_ARCHIVE" "$archive"
  print "PASS: using local Human Shell archive."
elif curl -fL --retry 3 -o "$archive" "$url"; then
  print "PASS: downloaded Human Shell v$version."
else
  exit_status=$?
  print -u2 "FAIL: download exited with status $exit_status."
  exit "$exit_status"
fi
actual_sha="$(shasum -a 256 "$archive" | awk '{{print $1}}')"
[[ "$actual_sha" == "$expected_sha" ]] || {{ print -u2 "FAIL: archive checksum mismatch."; exit 1; }}
print "PASS: archive checksum verified."
tar -xzf "$archive" -C "$tmp"
source_dir="$tmp/human-shell-$version"
destination="$HOME/.local/share/human-shell/current"
staging="$HOME/.local/share/human-shell/.staging-$$"
backup="$HOME/.local/share/human-shell/.previous-$(date '+%Y%m%d-%H%M%S')"
mkdir -p "$HOME/.local/share/human-shell"
rm -rf "$staging"
cp -R "$source_dir" "$staging"
if [[ -e "$destination" ]]; then mv "$destination" "$backup"; print "PASS: previous installation backed up to $backup"; fi
mv "$staging" "$destination"
chmod 755 "$destination/install.sh" "$destination/uninstall.sh"
if "$destination/install.sh" "$@"; then
  print "PASS: Human Shell v$version installed from release asset."
else
  exit_status=$?
  print -u2 "FAIL: installer exited with status $exit_status."
  [[ -e "$backup" ]] && {{ rm -rf "$destination"; mv "$backup" "$destination"; print -u2 "Restored previous installation."; }}
  exit "$exit_status"
fi
print 'Run: source "$HOME/.zshrc"'
''', encoding="utf-8")
installer.chmod(0o755)
installer_sha = hashlib.sha256(installer.read_bytes()).hexdigest()
checksums = DIST / "SHA256SUMS"
checksums.write_text(
    f"{archive_sha}  {archive.name}\n{installer_sha}  {installer.name}\n",
    encoding="utf-8",
)
print(f"PASS: built {archive.name}")
print(f"PASS: built {installer.name}")
print(f"PASS: wrote {checksums.name}")
print(f"ARCHIVE_SHA256={archive_sha}")
