# Jahvon's Development Workspace

Personal development environment and productivity tools managed with ([flow](https://flowexec.io)).

## Organization

- `dev/` - Development Tools
- `tools/` - System & Editor Tools
- `productivity/` - Personal Productivity

## Shell

- zsh with powerlevel10k, zsh-autosuggestions, and zsh-syntax-highlighting (no framework)
- Language versions (node, go, ruby) come from [mise](https://mise.jdx.dev) shims, so they are on
  `PATH` in non-interactive shells too (flow/mochi executables)
- Dotfiles in `tools/dotfiles/templates/` are **symlinked** into `~`; edit them here. Machine-specific
  settings go in `~/.zshrc.local` / `~/.zshenv.local`
- `devflow` / `devmochi` run the local dev builds from `$FLOWEXEC/flow` and `$FLOWEXEC/mochi`

## New machine

```bash
# macOS (auto-detected)
curl -fsSL https://raw.githubusercontent.com/jahvon/system/main/tools/bootstrap.sh | sh

# Linux server: shell setup, mise tools, and completions, without Docker.
# The GIT_* vars skip the prompts, which is needed when there is no terminal.
curl -fsSL https://raw.githubusercontent.com/jahvon/system/main/tools/bootstrap.sh \
  | GIT_USER_NAME="..." GIT_USER_EMAIL="..." GITHUB_USER="..." BOOTSTRAP_TARGET=ubuntu-server sh
```

Re-running either command is safe, and it's how you update an existing machine.

## Common Commands

```bash
# Tools & System
flow apply dotfiles:dotfiles        # plugins, symlinks, mise tools
flow show dotfiles:                 # what is linked where
flow install packages:completions   # regenerate flow/mochi zsh completions
flow install packages:homebrew      # brew bundle from tools/packages/Brewfile
flow run bootstrap:ubuntu-server    # Linux server setup from an existing checkout
flow open vscode

# Development
flow new branch
flow new commit

# Productivity
flow get tasks
flow add task
```
