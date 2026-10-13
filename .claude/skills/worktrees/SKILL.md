---
name: worktrees
description: Create, list, sync, and clean up git worktrees across Jahvon's repos with the `system` flow executables, keeping Claude Code's per-project state (local settings, memories, project folders) in step. Use when starting parallel work in a new worktree, when finishing or merging worktree work, when the user asks to clean up, prune, or list worktrees or branches, when permissions granted in a worktree should carry over, or when ~/.claude/projects is cluttered with old worktree folders.
allowed-tools: mcp__flow__execute, mcp__flow__get_executable, Bash(flow:*), Bash(git worktree list:*), Read
---

# Worktrees

Four executables in the `system` workspace handle worktrees across every repo under
`~/workspaces`. Outside the system repo, qualify them as `system/…`
(`flow clean system/worktrees`).

| Goal | Run |
|------|-----|
| See every worktree, its branch, age, and merged state | `flow list worktrees` |
| Start parallel work in the current repo | `flow new worktree NAME -- --branch=feat/x` |
| Carry Claude permissions between a checkout and its worktrees | `flow update worktrees -- --apply=true` |
| Remove finished worktrees and old Claude project folders | `flow clean worktrees`, then `-- --apply=true` |

All of them take `-- --repo=<substring>` to limit them to matching repos.

## How they keep Claude state consistent

- **Local settings:** `.claude/settings.local.json` is untracked, so git never copies it into a
  worktree. Permissions granted during a worktree session land only in that worktree's copy.
  - `new` seeds a worktree with the main checkout's settings.
  - `update` merges the settings both ways: allow-lists combine, and nothing is removed.
  - `clean` folds a worktree's settings back into the main checkout before deleting it.
- **Memories:** Claude Code keeps a repo's memory in the main checkout's project folder. If a
  folder for a deleted worktree holds memories anyway, `clean` moves them into the repo's memory
  (with their index lines) before deleting the folder. It refuses to overwrite a same-named file,
  and keeps that folder instead.
- **Project folders:** `~/.claude/projects/<repo>--claude-worktrees-<name>` hold transcripts for
  worktrees that no longer exist. `clean` deletes them once their memories are safe.

## Running clean

1. Run `flow clean worktrees` without `--apply` first, and show the user what it would remove
   and what it keeps.
2. Apply only after they agree. It deletes worktrees, branches, and session transcripts.

`clean` keeps any worktree that:
- has uncommitted changes,
- has no commits of its own yet (fresh work: its tip is trivially already in the default branch),
- is unmerged,
- is the working directory of a running process, such as another Claude session.

Merged means the branch is in `origin`'s default branch, or `gh` reports a merged PR for it
(this catches squash merges). If the user wants a kept worktree gone anyway, they decide. Use
`git worktree remove` yourself only when asked, and never with `--force` on uncommitted work.

## After finishing work in a worktree

Once the branch is merged or pushed, run `flow update worktrees -- --apply=true` so permissions
granted during the session reach the main checkout. Offer a `clean` dry run at the end of the
session.
