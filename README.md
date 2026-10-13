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
- Jump around with `cd <repo>` from anywhere, named dirs (`~mochi`, `~flow`, `~ico`, `~kube`,
  `~system`, `~notes`, `~ws`), or `ws [query]` to pick any repo with fzf

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
# Keep a machine current
flow update system                  # pull, packages, dotfiles, mise, flow CLI, Claude setup
flow check system:shell             # startup time, linked dotfiles, mise tools, completions

# Setup pieces
flow apply dotfiles:dotfiles        # plugins, symlinks, mise tools
flow show dotfiles:                 # what is linked where
flow install packages:completions   # regenerate flow/mochi zsh completions
flow install packages:homebrew      # brew bundle from tools/packages/Brewfile
flow run bootstrap:ubuntu-server    # Linux server setup from an existing checkout
flow install rust                   # opt-in Rust toolchain via mise
flow install claude:setup           # Claude Code + agent-framework (CLAUDE.md, settings, plugins)

# Go
flow build go:module                # also test/lint go:module; run from the module directory
flow install go:tools               # mockgen, dlv
flow template generate <name> --template module   # new Go module scaffold

# Editors and notes
flow open vscode
flow open jetbrains:goland
flow create daily
```
