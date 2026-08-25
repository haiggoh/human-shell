# Human Shell

**Visible command outcomes for interactive zsh sessions in macOS Terminal.**

Human Shell is an opt-in Terminal launcher that translates each command's exit status into a brief human label while preserving the exact technical code. Every command's outcome is reported on its own line, right-aligned beneath that command's output, so scrolling back through a session shows which commands passed and which failed rather than only the most recent one. The default all-status mode confirms success in green, shows ordinary failures in red, and uses yellow for interruptions, signal-driven stops, and findings such as a difference or no match.

A second **Human Shell Failures Only** launcher provides a quieter alternative that highlights nonzero exit codes without confirming successes. Both modes preserve normal command output, pipes, redirects, command substitutions, and unattended scripts.

## Why this exists

> "Don't log every success" is folklore.

Unix convention says a command that succeeded should say nothing. That convention was written for output — for pipes, logs, and scripts, where a per-item `ok` line is noise that buries the one line that matters. It was never a claim about the person sitting at a prompt deciding what to type next.

The maxim collapses two different things. The real axis is frequency × decision value, and an interactive prompt sits at the far end of both: it reports once per command rather than once per file, and it reports at the moment the answer is about to be acted on. When a command is silent on success, ends in a wall of verbose output, or failed three screens ago, the exit status is a fact the shell already holds and declines to show.

Human Shell shows it, in the prompt, and nowhere else. The folklore is not wrong about noise; it is wrong about where noise comes from. That distinction is also why there are two modes: failures-only mode lowers the frequency for anyone who does not want success confirmed, without giving up the signal.

## Modes

| Launcher or command | Behavior |
| --- | --- |
| `Human Shell.app` or `human-shell` | Default all-status mode: `success [exit 0]` or a humanized failure |
| `Human Shell Failures Only.app` or `human-shell --failures` | Humanizes failures while keeping successes quiet |
| `human-shell --all` | Explicit all-status mode |

Neither mode displays a status on the initial prompt. Status reporting starts after the first command entered by the user.

A status describes one command. Pressing Enter on an empty line runs nothing, so it has no outcome to report and prints nothing.

## Every command keeps its own outcome

A status is printed on its own line, right-aligned, directly beneath the output of the command it describes:

```
% cp notes.txt backup/
                                                        success [exit 0]
% ./deploy.sh
deploy: connection refused
                                                         failed [exit 1]
% diff -u notes.txt backup/notes.txt
--- notes.txt
+++ backup/notes.txt
@@ -1 +1 @@
-draft
+final
                                                  diff detected [exit 1]
```

Each verdict stays where it was printed, for as long as the scrollback lasts. That is the point of the tool: after running several unrelated commands you can scroll up and see which of them failed, not just what the last one did.

This is why the status is written into the scrollback rather than into the shell's right prompt. A right prompt belongs to the prompt it is drawn with — which is the prompt where the *next* command gets typed — so a right-prompt status ends up beside the following command and reads as a verdict on it. Printing the line attaches each outcome to the command that earned it.

## Coexisting with a prompt theme

Human Shell never writes to `RPROMPT`, `PROMPT`, or any other prompt parameter. It prints its own line and leaves your prompt entirely alone, so a theme such as powerlevel10k or starship keeps both sides of its prompt exactly as it drew them, with nothing to configure and nothing to restore.

Sourcing order does not matter for the status to appear. The installers append their managed block to the end of `~/.zshrc`, which is fine; sourcing `human-shell.zsh` above your theme is equally fine.

## Interactive debugging

Human Shell helps when manually validating setup commands, testing scripts and CLI tools, following debugging instructions, checking commands that are silent on success, or noticing failures after verbose output.

It is not a debugger and does not inspect command internals. It surfaces the exit status already returned by the previous command.

## Installation

### Homebrew — recommended

```zsh
brew install haiggoh/tap/human-shell
human-shell-install
source ~/.zshrc
```

The explicit setup command installs the per-user source, updates `.zshrc` with a bounded managed block, generates both launchers under `~/Applications` using this Mac's local Terminal icon, and adds both launchers to the Dock. Pass `human-shell-install --no-dock` to skip Dock changes.

The formula depends on `dockutil` because placing the launchers in the Dock is part of the documented default. If you always use `--no-dock`, that dependency is doing nothing for you; the non-Homebrew installers treat `dockutil` as optional and open `~/Applications` for a manual drag when it is absent.

### Standalone release installer

```zsh
curl -fLO https://github.com/haiggoh/human-shell/releases/download/v1.3.1/human-shell-installer-v1.3.1.zsh
zsh -n human-shell-installer-v1.3.1.zsh
zsh human-shell-installer-v1.3.1.zsh
source ~/.zshrc
```

The standalone installer verifies the release archive and installs source under `~/.local/share/human-shell/current` before generating the launchers locally.

## Installed locations

Human Shell uses a per-user installation and does not require `sudo`.

| Item | Location |
| --- | --- |
| All-status launcher | `~/Applications/Human Shell.app` |
| Failures-only launcher | `~/Applications/Human Shell Failures Only.app` |
| Active packaged source | `~/.local/share/human-shell/current` |
| Shell integration | Managed block in `~/.zshrc` |
| Development checkout, if used | User-selected clone directory |

`~/Applications` is the per-user Applications directory. It is used deliberately so Human Shell does not require administrator privileges or write to `/Applications`.

## Test

In the default app, run:

```zsh
true
false
```

After `true`, the prompt shows green `success [exit 0]`. After `false`, it shows red `failed [exit 1]`.

## Human-readable statuses

Human Shell preserves the exact exit code and adds only meanings that are portable enough to be honest:

| Exit status | Display |
| ---: | --- |
| `0` | `success [exit 0]` |
| `1` | A findings label for a command in the table below, otherwise `failed [exit 1]` |
| `2–125` | `failed [exit N]` |
| `126` | `can't run [exit 126]` |
| `127` | `not found [exit 127]` |
| `128` | `failed [exit 128]` |
| `129–192` | A signal-aware label when the signal is known, otherwise `signal N` |
| Other nonzero values | `failed [exit N]` |

Common signals receive short labels such as `interrupted [exit 130 / SIGINT]`, `crashed [exit 139 / SIGSEGV]`, and `terminated [exit 143 / SIGTERM]`.

Most other nonzero codes are application-defined. Human Shell therefore says `failed [exit N]` instead of inventing a meaning; consult the command's own error output or documentation for details.

### Commands that report a finding through status 1

Some commands use status 1 to report what they found rather than that something went wrong. Running `diff` to see what differs, or `grep` to find out whether a pattern is present, is the normal case: "they differ" and "no match" are answers, and the difference is usually intended. Calling either a red failure reports an error that did not happen, so these commands get a yellow label at status 1 instead:

| Command | Status 1 shows |
| --- | --- |
| `diff`, `diff3`, `colordiff`, `cmp`, `git diff` | `diff detected [exit 1]` |
| `grep`, `egrep`, `fgrep`, `rg`, `ag`, `ack`, `git grep` | `no match [exit 1]` |

Status 2 and above is untouched and still red, because for both families that really is an error: `diff` on a missing file and `grep` on an unreadable one both report `failed [exit 2]`.

The table only applies to a command on its own. In a pipeline or an `&&`, `||` or `;` list the exit status belongs to some other command, so `diff a b \| head` reports the status of `head` as it should. Leading variable assignments, and wrappers such as `sudo` that pass the status through, are looked past.

The table is a documented extension point. To label another command's status 1, add a key after Human Shell is sourced:

```zsh
HUMAN_SHELL_EXIT1_LABELS[my-checker]='nothing to do'
```

Or define `HUMAN_SHELL_EXIT1_LABELS` before sourcing to replace the defaults outright, which is also how you opt a shipped command back out — an entry you set is never merged with the defaults.

## Isolation

Human Shell is opt-in. Ordinary Terminal windows and noninteractive scripts remain unchanged. Prompt indicators are not written to stdout, stderr, pipes, redirected files, or command substitutions.

## What the launchers do

Each launcher is a small AppleScript applet that starts a Terminal window in the mode it is named for. Two details are worth stating plainly, because both are otherwise invisible:

- **One window per click.** Launching Terminal makes Terminal open a window of its own. When Terminal is not already running, the launcher takes over that window instead of leaving it behind, so a click opens exactly one window rather than a Human Shell next to an unused plain shell.
- **The bootstrap line is not recorded in history.** A launcher starts its mode by typing one line into the window's shell. Human Shell installs a `zshaddhistory` hook that refuses to save that line, so it never reaches a history file and never appears when you press the up arrow. The filter matches only lines containing `HUMAN_SHELL_LAUNCHER=1`, which no one types by hand; everything you type yourself, `human-shell --failures` included, is recorded normally. The hook is registered in every interactive shell that sources `human-shell.zsh`, not only inside a Human Shell, because the shell that records the line is the plain one that receives it, before it is replaced.

Without that filter the line accumulates, and it accumulates faster than one copy per launch. Terminal keeps history per session under `~/.zsh_sessions`, and the Human Shell inherits the session of the shell it replaces, so the line is both saved into that session's history and restored from it into every later window of the same session chain.

To clear copies left by earlier versions:

```zsh
zsh scripts/scrub-launcher-history.zsh
```

It covers the shared history file and every per-session file, backs up each file it changes into one timestamped directory under `~/.human-shell-history-backups`, edits in place so permissions are unchanged, leaves multi-line entries intact, and reports exactly what it removed. Files with nothing to remove are not touched. Pass explicit paths to limit it to those files.

## Installer backups

Each install saves what it is about to replace, so a failed install can be rolled back:

| Backup | Written by | Retention |
| --- | --- | --- |
| `~/.zshrc.human-shell.<timestamp>.bak` | `install.sh` | newest 3, `HUMAN_SHELL_KEEP_ZSHRC_BACKUPS` |
| `~/.local/share/human-shell/.previous-<timestamp>` | the Homebrew wrapper | newest 3, `HUMAN_SHELL_KEEP_PREVIOUS` |

Both are pruned by `scripts/reap-backups.zsh` after the install succeeds, so neither grows without bound. Only entries matching the exact prefix and suffix above are candidates — a backup you made yourself, or one written by another tool, is never removed.

## Tests

```zsh
zsh tests/run-tests.zsh
```

The suite covers the exit-status-to-label table including the signal fallbacks, the status-1 findings table for both the diff and search families including the commands it must *not* classify, the right-aligned report line, the one-status-per-command rule, the history filter, and a syntax or compile check of every shipped script and applet. It needs no terminal and changes nothing on the system.

## Terminal icon

The repository does not redistribute Apple's Terminal icon. The installer replaces each generated AppleScript applet's native `applet.icns` with the icon from this Mac's local Terminal.app, removes conflicting generated icon metadata, re-signs the apps, and refreshes Launch Services. The icon remains Apple's property.

## Alternative installation layouts

<details>
<summary>Development checkout and direct repository installation</summary>

Use this when you intend to modify or contribute to Human Shell:

```zsh
mkdir -p "$HOME/ClaudeWorkspace"
git clone https://github.com/haiggoh/human-shell.git "$HOME/ClaudeWorkspace/human-shell"
cd "$HOME/ClaudeWorkspace/human-shell"
./install.sh
source ~/.zshrc
```

The checkout location is user-selected. Homebrew or the standalone release installer is preferred for routine use.

</details>

## Uninstall

```zsh
cd "$HOME/ClaudeWorkspace/human-shell"
./uninstall.sh
source "$HOME/.zshrc"
```

## License

Project source is licensed under the [MIT License](LICENSE).

Copyright © 2026 Heiko Brantsch.
