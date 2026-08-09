# Changelog

## 1.1.1

- Replace the AppleScript applet's native icon resource with the local Terminal icon.
- Remove conflicting `Assets.car` and `CFBundleIconName` metadata.
- Assign distinct bundle identifiers and refresh Launch Services.
- Add both launchers to the Dock during explicit setup when `dockutil` is available.
- Add `--no-dock` to skip Dock changes.
- Fix generated standalone-installer failure paths to use a writable zsh variable.

## 1.1.0

- Translate exit statuses into human-readable labels while preserving exact codes.
- Add all-status and failures-only modes and launchers.
- Publish reproducible release assets, checksums, standalone installer, and Homebrew formula.
