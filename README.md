# Human Shell

**Visible command outcomes for interactive zsh sessions in macOS Terminal.**

Human Shell is an opt-in Terminal launcher that displays the previous command's exit status in the right prompt. The default all-status mode confirms successful commands with a green `[ok 0]` indicator and highlights failures with a red `[exit N]` indicator.

A second **Human Shell Failures Only** launcher provides a quieter alternative that highlights nonzero exit codes without confirming successes. Both modes preserve normal command output, pipes, redirects, command substitutions, and unattended scripts.

## Modes

| Launcher or command | Behavior |
| --- | --- |
| `Human Shell.app` or `human-shell` | Default all-status mode: `[ok 0]` or `[exit N]` |
| `Human Shell Failures Only.app` or `human-shell --failures` | Shows only failures |
| `human-shell --all` | Explicit all-status mode |

Neither mode displays a status on the initial prompt. Status reporting starts after the first command entered by the user.

## Interactive debugging

Human Shell helps when manually validating setup commands, testing scripts and CLI tools, following debugging instructions, checking commands that are silent on success, or noticing failures after verbose output.

It is not a debugger and does not inspect command internals. It surfaces the exit status already returned by the previous command.

## Installation

```zsh
mkdir -p "$HOME/ClaudeWorkspace"
git clone https://github.com/haiggoh/human-shell.git "$HOME/ClaudeWorkspace/human-shell"
cd "$HOME/ClaudeWorkspace/human-shell"
./install.sh
source "$HOME/.zshrc"
```

The installer creates both launchers under `~/Applications`. Drag either or both to the Dock.

## Test

In the default app, run:

```zsh
true
false
```

After `true`, the prompt shows green `[ok 0]`. After `false`, it shows red `[exit 1]`.

## Isolation

Human Shell is opt-in. Ordinary Terminal windows and noninteractive scripts remain unchanged. Prompt indicators are not written to stdout, stderr, pipes, redirected files, or command substitutions.

## Terminal icon

The repository does not redistribute Apple's Terminal icon. The installer copies it from the user's local Terminal.app into each generated launcher. The icon remains Apple's property.

## Uninstall

```zsh
cd "$HOME/ClaudeWorkspace/human-shell"
./uninstall.sh
source "$HOME/.zshrc"
```

## License

Project source is licensed under the [MIT License](LICENSE).

Copyright © 2026 Heiko Brantsch.
