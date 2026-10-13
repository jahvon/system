---
name: system-setup
description: Set up, update, or repair Jahvon's machines through the `system` flow workspace (~/workspaces/github.com/jahvon/system) — new Mac or Linux server bootstrap, `update system`, shell health checks, zsh/dotfiles, mise toolchains, Homebrew packages, iTerm profiles and colors, completions, and the Claude Code setup. Use whenever the user asks to set up or update a machine or server, says the shell or terminal is slow or broken, wants to change dotfiles, aliases, prompt, PATH, or tool versions, or asks how their machine setup works — even if they don't mention the system repo.
allowed-tools: mcp__flow__list_executables, mcp__flow__get_executable, mcp__flow__execute, mcp__flow__sync_executables, Bash(flow:*), Read
---

# Machine setup through the system workspace

Everything about this machine's setup lives in the `system` repo at
`~/workspaces/github.com/jahvon/system`, registered as the flow workspace `system`. Change it
there and apply it with its flow executables. Hand-editing files in `~` gets overwritten or
silently drifts from the repo.

## Pick the executable

| Goal | Run |
|------|-----|
| Is the shell healthy? (startup time, links, mise, completions) | `flow check system:shell` |
| Bring a machine current | `flow update system` |
| Re-apply dotfiles, zsh plugins, mise tools | `flow apply dotfiles:dotfiles` |
| What is linked where | `flow show dotfiles:` |
| Regenerate flow/mochi completions | `flow install packages:completions` |
| Homebrew packages (`tools/packages/Brewfile`) | `flow install packages:homebrew` |
| iTerm profiles and colors | `flow install preferences:iterm` |
| Claude Code + agent-framework | `flow install claude:setup` |
| Rust (opt-in per machine) | `flow install rust` |
| Go tools / module tasks | `flow install go:tools`, `flow build\|test\|lint go:module` |
| New Mac | `curl -fsSL https://raw.githubusercontent.com/jahvon/system/main/tools/bootstrap.sh \| sh` |
| New Linux server | same, with `GIT_USER_NAME=… GIT_USER_EMAIL=… GITHUB_USER=… BOOTSTRAP_TARGET=ubuntu-server` |

Outside the system repo, qualify refs with the workspace (`update system/system`,
`check system/system:shell`), or run from inside the repo. Use `flow-help` or
`mcp__flow__list_executables` for anything not in this table.

Before running `update system` or `install packages:homebrew`, tell the user what will happen:
both upgrade every Homebrew package, and `update system` asks for a sudo password to replace
the flow binary. Treat `bootstrap` as a first-run operation: it is safe to re-run, but it is
heavy.

## Where changes go

- **Shell config:** edit `tools/dotfiles/templates/` (`zshrc`, `zshenv`, `zprofile`,
  `path.zsh`, `p10k.zsh`, `mise.toml`). These are symlinked into `~`, so an edit is live in the
  next shell. Machine-only settings go in `~/.zshrc.local` / `~/.zshenv.local`, which are not
  tracked.
- **PATH:** `templates/path.zsh`. It is sourced from both `.zshenv` (every shell, including
  the non-interactive ones flow executables run in) and `.zprofile` (after macOS
  `path_helper`). Language runtimes come from mise shims, not Homebrew, nvm, or Volta.
- **Packages:** `tools/packages/Brewfile`, plus `ubuntu-install-core.sh` for servers.
- **iTerm:** `tools/preferences/iterm/profiles.json`, which holds Dynamic Profiles. Paths in it are
  written as `${HOME}` and filled in at install. When editing it:
  - Profiles must be self-contained. Don't set a parent profile: deleting that parent breaks
    every child.
  - iTerm keeps old keys that a reload omits. To clear a value, set it explicitly (for example
    `"Initial Text": ""`); don't delete the key.
  - iTerm's parser rejects `NaN` and `Infinity`. The install step checks for them.
- **Claude Code settings** are not managed here. agent-framework builds them from its
  `global/settings.base.json` plus `~/.claude/settings.overlay.json`; `claude:setup` only
  calls it.

## Verify before calling it done

1. Run `flow schema validate` on any `.flow` file you touched.
2. Run `flow check system:shell`. Warm startup should be well under 200ms, so a large jump means
   something now runs eagerly at startup (version managers and `eval "$(tool init)"` are the
   usual cause).
3. This session's PATH predates any dotfile change. To see the new environment, run checks
   through a fresh login shell (`zsh -l -c '…'`).
4. For prompt or terminal changes, the user has to open a new tab to see them. Say so.

## Gotchas

- Pass flow flag args after `--`, for example `flow check system:shell -- --max-ms=150`.
  A bare `key=value` is silently ignored.
- Executables in other workspaces that aren't marked public (agent-framework's
  `agent:global`) can only run from inside that workspace's checkout.
- Commit in the system repo with one logical change per commit. Don't push unless asked.
