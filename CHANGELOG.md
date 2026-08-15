# Changelog

## 1.2.0

Fixed

- Compose the status label with the right prompt instead of overwriting it. Previously `RPROMPT` was assigned unconditionally, which silently destroyed the right prompt of a theme such as powerlevel10k or starship with no way to get it back. An existing right prompt is now kept, shown after the label, and left alone when there is no label; a right prompt installed later by another hook is adopted as the base rather than replaced.
- Clear the label on an empty line. Pressing Enter without running a command re-rendered the previous command's label, because the marker that a command had run was never reset.
- Open exactly one window per launcher click. When Terminal was not already running, launching it opened a window of its own and the launcher then opened a second one, leaving an unused plain shell beside the Human Shell. The launcher now takes over that first window.
- Keep the launchers' bootstrap line out of history, with a `zshaddhistory` hook. The line the launchers type was recorded like a typed command, and because Terminal keeps history per session and the Human Shell inherits the session of the shell it replaces, it was also restored into every later window of that session chain.
- Report an unnamed signal by number. An unknown signal number is echoed back by `kill -l` rather than returning nothing, so the intended numeric fallback was unreachable and produced labels like `signal SIG64`.
- Replace the current shell instead of nesting a second login shell when `human-shell` is run from inside a Human Shell, so one `exit` returns to the shell it was started from.

Added

- A test suite covering the exit-status-to-label table including signal fallbacks, the right-prompt composition, the one-label-per-command rule, the history filter, the history scrubber, and a syntax or compile check of every shipped script and applet: `zsh tests/run-tests.zsh`.
- `scripts/scrub-launcher-history.zsh`, which removes bootstrap lines recorded by earlier versions from the shared and per-session history files, backing up every file it changes into one timestamped directory.
- A "Why this exists" section in the README, and documentation of prompt-theme coexistence, what the launchers do, and why the Homebrew formula depends on `dockutil`.

Changed

- Point at `brew install dockutil` when Dock placement is skipped because `dockutil` is missing.

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
