#!/bin/sh
# Fast-forwards every clean repo under ~/workspaces and refreshes flow's git workspaces, here or on a server.
# Never touches a repo with local changes, or one not on its default branch.
#   usage: pull-repos.sh [server]
set -eu

if [ -n "${1:-}" ]; then
    exec ssh -o BatchMode=yes -o ConnectTimeout=8 "$1" 'export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"; sh -s' < "$0"
fi

failed=0
for git_dir in "$HOME"/workspaces/*/*/*/.git; do
    [ -d "$git_dir" ] || continue
    repo=$(dirname "$git_dir")
    label=${repo#"$HOME/workspaces/"}

    if ! GIT_TERMINAL_PROMPT=0 git -C "$repo" fetch -q --prune 2>/dev/null; then
        echo "[FAIL] $label: fetch failed"
        failed=1
        continue
    fi
    branch=$(git -C "$repo" symbolic-ref --short -q HEAD || echo detached)
    default=$(git -C "$repo" symbolic-ref --short -q refs/remotes/origin/HEAD | sed 's|^origin/||')
    default=${default:-main}
    behind=$(git -C "$repo" rev-list --count "HEAD..origin/$default" 2>/dev/null || echo "?")

    if [ "$branch" != "$default" ]; then
        echo "[SKIP] $label: on $branch, not $default ($behind behind origin/$default)"
    elif [ -n "$(git -C "$repo" status --porcelain --untracked-files=no)" ]; then
        echo "[SKIP] $label: local changes ($behind behind)"
    elif [ "$behind" = 0 ]; then
        echo "[OK]   $label: current"
    elif git -C "$repo" merge -q --ff-only "origin/$default" 2>/dev/null; then
        echo "[OK]   $label: pulled $behind, now $(git -C "$repo" log --oneline -1 | cut -c1-50)"
    else
        echo "[FAIL] $label: has diverged from origin/$default"
        failed=1
    fi
done

if command -v flow >/dev/null 2>&1; then
    # Workspaces registered from git live in flow's cache, not under ~/workspaces.
    if flow sync --git >/dev/null 2>&1; then
        echo "[OK]   flow git workspaces: synced"
    else
        echo "[FAIL] flow git workspaces: sync failed"
        failed=1
    fi
fi
exit "$failed"
