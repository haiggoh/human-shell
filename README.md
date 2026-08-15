# Human Shell

**Visible command outcomes for interactive zsh sessions in macOS Terminal.**

Human Shell is an opt-in Terminal launcher that translates the previous command's exit status into a brief human label while preserving the exact technical code. The default all-status mode confirms success in green, shows ordinary failures in red, and uses yellow for interruptions and other signal-driven stops.

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

A status describes one command. Pressing Enter on an empty line runs nothing, so it has no outcome to report and returns a clean prompt rather than repeating the previous label.

## Coexisting with a prompt theme

Human Shell writes to the right side of the prompt, and it does not take that space over. Whatever right prompt your own configuration produces is kept and shown after the status label, and it is what remains on the prompt when there is no status to show. If a theme installs its right prompt from its own hook, Human Shell adopts that value as the base and composes with it instead of replacing it.

For the label to be visible, Human Shell's hook has to run after your theme's, which means sourcing it after the theme in `~/.zshrc`. The installers append their managed block to the end of the file, so this is already the case for a standard installation. If you source `human-shell.zsh` by hand, keep it below your theme.

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
curl -fLO https://github.com/haiggoh/human-shell/releases/download/v1.2.1/human-shell-installer-v1.2.1.zsh
zsh -n human-shell-installer-v1.2.1.zsh
zsh human-shell-installer-v1.2.1.zsh
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
| `1–125` | `failed [exit N]` |
| `126` | `can't run [exit 126]` |
| `127` | `not found [exit 127]` |
| `128` | `failed [exit 128]` |
| `129–192` | A signal-aware label when the signal is known, otherwise `signal N` |
| Other nonzero values | `failed [exit N]` |

Common signals receive short labels such as `interrupted [exit 130 / SIGINT]`, `crashed [exit 139 / SIGSEGV]`, and `terminated [exit 143 / SIGTERM]`.

Most other nonzero codes are application-defined. Human Shell therefore says `failed [exit N]` instead of inventing a meaning; consult the command's own error output or documentation for details.

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

## Tests

```zsh
zsh tests/run-tests.zsh
```

The suite covers the exit-status-to-label table including the signal fallbacks, the right-prompt composition, the one-status-per-command rule, the history filter, and a syntax or compile check of every shipped script and applet. It needs no terminal and changes nothing on the system.

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
