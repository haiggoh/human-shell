# Human Shell

**Visible command outcomes for interactive zsh sessions in macOS Terminal.**

Human Shell is an opt-in Terminal launcher that translates the previous command's exit status into a brief human label while preserving the exact technical code. The default all-status mode confirms success in green, shows ordinary failures in red, and uses yellow for interruptions and other signal-driven stops.

A second **Human Shell Failures Only** launcher provides a quieter alternative that highlights nonzero exit codes without confirming successes. Both modes preserve normal command output, pipes, redirects, command substitutions, and unattended scripts.

## Modes

| Launcher or command | Behavior |
| --- | --- |
| `Human Shell.app` or `human-shell` | Default all-status mode: `success [exit 0]` or a humanized failure |
| `Human Shell Failures Only.app` or `human-shell --failures` | Humanizes failures while keeping successes quiet |
| `human-shell --all` | Explicit all-status mode |

Neither mode displays a status on the initial prompt. Status reporting starts after the first command entered by the user.

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

### Standalone release installer

```zsh
curl -fLO https://github.com/haiggoh/human-shell/releases/download/v1.1.1/human-shell-installer-v1.1.1.zsh
zsh -n human-shell-installer-v1.1.1.zsh
zsh human-shell-installer-v1.1.1.zsh
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
| `129–192` | A signal-aware label when the signal is known |
| Other nonzero values | `failed [exit N]` |

Common signals receive short labels such as `interrupted [exit 130 / SIGINT]`, `crashed [exit 139 / SIGSEGV]`, and `terminated [exit 143 / SIGTERM]`.

Most other nonzero codes are application-defined. Human Shell therefore says `failed [exit N]` instead of inventing a meaning; consult the command's own error output or documentation for details.

## Isolation

Human Shell is opt-in. Ordinary Terminal windows and noninteractive scripts remain unchanged. Prompt indicators are not written to stdout, stderr, pipes, redirected files, or command substitutions.

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
