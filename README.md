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

## Common Commands

```bash
# Tools & System
flow apply dotfiles                 # plugins, symlinks, mise tools
flow install packages:completions   # regenerate flow/mochi zsh completions
flow install packages:homebrew      # brew bundle from tools/packages/Brewfile
flow update system
flow open vscode

# Development
flow push branch

# Productivity
flow get tasks
flow add task
```
