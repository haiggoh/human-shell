# Changelog

## 1.4.0

Added

- Automatic, silent multiline diagnostics in both Human Shell modes. Qualifying pasted multiline commands use a temporary, bounded ZERR collector to retain unsuppressed nonzero events without rewriting the command, intercepting stdout or stderr, or changing the existing final aggregate badge.
- `human details` for reviewing the latest frozen multiline snapshot, with guaranteed fallback `human-shell details`. The short `human` command is installed only when that name is otherwise unused. `--plain` removes presentation styling and `--clear` erases retained source and events.
- Conservative event details: scalar status, pipeline statuses, collection completeness, overflow state, and a zsh source-location candidate when available. Anonymous intermediate status 1 is not guessed to mean a diff or search finding, and exact pasted-line numbers are not claimed.
- Dedicated contracts for zsh semantics, bounded collection, ZERR conflicts, `LOCAL_TRAPS`, renderer safety, command-name collisions, hook integration, and diagnostics-on versus diagnostics-off differential behavior across output, redirects, heredocs, substitutions, pipelines, shell state, file descriptors, and existing traps.

Safety

- Collection fails closed when a function-form or list-form ZERR trap already exists, and preserves a trap installed or replaced by submitted code.
- Retained source is limited to 256 KiB and observed events to 256. Control characters in displayed diagnostic metadata are rendered visibly rather than executed by the terminal.
- Failures recovered inside successful subshells or command substitutions remain outside the parent shell's in-memory snapshot; the documentation states this process boundary explicitly.

Changed

- The standalone release example and deterministic release-builder default now target version 1.4.0.
- The release manifest now includes every shipped diagnostics contract so an extracted archive can run its complete self-test suite.

## 1.3.1

Fixed

- Reap the backups the installer writes. `install.sh` saves the previous `~/.zshrc` as `~/.zshrc.human-shell.<timestamp>.bak` on every run so a failed install can be rolled back, and nothing ever removed it once the install had succeeded, so the home directory collected one file per install forever — twelve had accumulated here. The newest 3 are now kept and older ones are pruned; set `HUMAN_SHELL_KEEP_ZSHRC_BACKUPS` to change how many are retained. Backups written by anything else, including `~/.zshrc.<timestamp>.bak` and any hand-made copy, are matched by neither prefix nor suffix and are never touched.

Added

- `scripts/reap-backups.zsh`, the single implementation of that retention rule, shared with the Homebrew wrapper's own pruning of superseded user copies under `~/.local/share/human-shell` so the two cannot drift. Selection is deliberately narrow — an entry qualifies only if it sits directly in the given directory, starts with the given prefix, ends with the given suffix, and is of the requested kind — and an empty prefix is refused rather than defaulted, because it would match every entry in the directory.
- Tests for the reaper: retention order, idempotence, `--keep 0`, prefix and suffix narrowness, file-versus-directory kind, that live state is never a candidate, that the singular and plural messages agree with their number, and every guard-rail rejection.

## 1.3.0

Changed

- Report each command's outcome on its own line, right-aligned beneath that command's output, instead of in the shell's right prompt. A right prompt belongs to the prompt it is drawn with, which is the prompt where the *next* command is typed, so the scrollback read `% echo two          failed [exit 1]` when it was the command before `echo two` that failed. Every outcome now stays attached to the command that earned it, and stays there for as long as the scrollback lasts, which is what makes a session reviewable after the fact rather than only at the moment the status appears.

  This supersedes 1.2.0's right-prompt composition rather than reverting it: Human Shell no longer assigns `RPROMPT` at all, so a theme's right prompt is not merely preserved but never touched, and sourcing order no longer matters. 1.2.0's rule that a bare Enter reports nothing is unchanged and now has nothing to clear, because a printed outcome does not move.

Added

- A status-1 findings table, so a command that reports what it found through exit status 1 is not called a failure. `diff`, `diff3`, `colordiff`, `cmp` and `git diff` show a yellow `diff detected [exit 1]`, and `grep`, `egrep`, `fgrep`, `rg`, `ag`, `ack` and `git grep` show a yellow `no match [exit 1]`. Status 2 and above stays a red failure, because for both families that really is an error. Only a lone simple command is classified — in a pipeline or an `&&`, `||` or `;` list the status belongs to some other command — and leading variable assignments and status-passing wrappers such as `sudo` are looked past. Extend it with `HUMAN_SHELL_EXIT1_LABELS[my-checker]='nothing to do'`, or define the whole array before sourcing to replace the defaults.
- Tests for the findings table including the commands it must *not* classify, and for the right-aligned report line.

## 1.2.1

Fixed

- Clear the screen only on the launcher's own first prompt. The launchers export the marker that requests the clear, so switching mode inside an existing window inherited it and wiped the scrollback the user was reading. The marker is now consumed when it is used.

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
