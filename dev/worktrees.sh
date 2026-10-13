#!/usr/bin/env bash
# Git worktree housekeeping across every repo under $WORKSPACES, kept in step with Claude Code's
# per-project state (~/.claude/projects/<path>/ for memory and transcripts, and each checkout's
# untracked .claude/settings.local.json).
#
#   worktrees.sh list
#   worktrees.sh clean        # dry run unless APPLY=true
#   worktrees.sh new NAME     # from inside a repo; BRANCH defaults to NAME
#   worktrees.sh update       # sync local Claude settings between checkouts and their worktrees
#
# Env: WORKSPACES, CLAUDE_CONFIG_DIR (default ~/.claude), REPO (substring filter), APPLY, BRANCH
set -euo pipefail

WORKSPACES="${WORKSPACES:-$HOME/workspaces}"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
PROJECTS="$CLAUDE_DIR/projects"
APPLY="${APPLY:-false}"
# Untracked files a fresh worktree needs from its main checkout; copied only when missing.
LOCAL_FILES=(.env .env.local .dev.vars)
LOCAL_SETTINGS=".claude/settings.local.json"

log() { printf '%s\n' "$*" >&2; }
die() { log "error: $*"; exit 1; }
dry() { [ "$APPLY" != "true" ]; }
act() { if dry; then log "  [dry-run] $*"; else log "  $*"; fi; }

# Claude Code names a project directory after its path with every non-alphanumeric character as '-'
sanitize() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }

repos() {
  find "$WORKSPACES" -mindepth 2 -maxdepth 4 -type d -name .git -not -path '*/node_modules/*' 2>/dev/null \
    | sed 's|/\.git$||' | sort | while read -r r; do
      [[ -z "${REPO:-}" || "$r" == *"$REPO"* ]] && printf '%s\n' "$r"
    done
}

default_ref() {
  local ref
  ref="$(git -C "$1" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)" && { echo "$ref"; return; }
  for b in main master; do
    git -C "$1" show-ref -q --verify "refs/remotes/origin/$b" && { echo "origin/$b"; return; }
  done
}

# "path<TAB>branch" for each linked worktree (not the main checkout)
linked_worktrees() {
  git -C "$1" worktree list --porcelain | awk -v main="$1" '
    /^worktree / { path = substr($0, 10); branch = "" }
    /^branch /   { branch = substr($0, 8); sub("refs/heads/", "", branch) }
    /^detached/  { branch = "(detached)" }
    /^$/         { if (path != main) print path "\t" branch; path = "" }
    END          { if (path != "" && path != main) print path "\t" branch }'
}

is_dirty() { [ -n "$(git -C "$1" status --porcelain 2>/dev/null)" ]; }

# Working directories of every running process, read once: a worktree some shell or Claude
# session is sitting in is in use, whatever its branch state.
PROCESS_CWDS="$(lsof -a -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' || true)"
in_use() { awk -v p="$1" '$0 == p || index($0, p "/") == 1 { f = 1 } END { exit !f }' <<< "$PROCESS_CWDS"; }

# A branch whose reflog holds only its creation has never had a commit of its own. Its tip is
# trivially "in" the default branch, but it is fresh work, not finished work.
never_committed() {
  [ "$(git -C "$1" reflog show --format=%H "refs/heads/$2" 2>/dev/null | wc -l | tr -d ' ')" -le 1 ]
}

# Merged if the branch is in the default branch, or a merged PR exists for it (squash merges).
merged_reason() {
  local repo="$1" branch="$2" base
  [ "$branch" = "(detached)" ] && return 1
  never_committed "$repo" "$branch" && return 1
  base="$(default_ref "$repo")"
  if [ -n "$base" ] && git -C "$repo" merge-base --is-ancestor "$branch" "$base" 2>/dev/null; then
    echo "in $base"; return
  fi
  if command -v gh > /dev/null; then
    local pr
    pr="$(cd "$repo" && gh pr list --head "$branch" --state merged --json number --jq '.[0].number' 2>/dev/null || true)"
    [ -n "$pr" ] && { echo "PR #$pr merged"; return; }
  fi
  return 1
}

age() { git -C "$1" log -1 --format=%cr 2>/dev/null || echo "?"; }

# Deep-merge settings files: objects merge, arrays union (first file's order), scalars from the second win.
merge_settings() {
  jq -n --slurpfile a "$1" --slurpfile b "$2" '
    def m($a; $b):
      if ($a|type) == "object" and ($b|type) == "object" then
        reduce ($b|keys_unsorted[]) as $k ($a; .[$k] = m($a[$k]; $b[$k]))
      elif ($a|type) == "array" and ($b|type) == "array" then
        $a + [$b[] | select(. as $x | $a | index([$x]) | not)]
      elif $b == null then $a else $b end;
    m($a[0]; $b[0])'
}

# Fold SRC's settings into DEST (creating DEST if needed); reports only when DEST would change.
fold_settings() {
  local src="$1" dest="$2" label="$3" merged
  [ -f "$src" ] || return 0
  if [ ! -f "$dest" ]; then
    act "copy $LOCAL_SETTINGS -> $label"
    dry || { mkdir -p "$(dirname "$dest")"; cp "$src" "$dest"; }
    return 0
  fi
  merged="$(merge_settings "$dest" "$src")"
  if [ "$(jq -S . "$dest")" != "$(jq -S . <<< "$merged")" ]; then
    act "merge $LOCAL_SETTINGS into $label"
    dry || printf '%s\n' "$merged" > "$dest"
  fi
}

copy_local_files() {
  local repo="$1" wt="$2" f
  for f in "${LOCAL_FILES[@]}"; do
    if [ -f "$repo/$f" ] && [ ! -e "$wt/$f" ]; then
      act "copy $f -> ${wt##*/}"
      dry || cp "$repo/$f" "$wt/$f"
    fi
  done
}

# Move a stale project's memories into the repo's project memory, never overwriting a file.
fold_memory() {
  local from="$PROJECTS/$1/memory" to="$PROJECTS/$2/memory" f name
  [ -d "$from" ] || return 0
  for f in "$from"/*.md; do
    [ -e "$f" ] || continue
    name="${f##*/}"
    [ "$name" = "MEMORY.md" ] && continue
    if [ -e "$to/$name" ]; then
      log "  ! memory $name exists in both; keeping the repo's copy, worktree copy left in $1"
      return 1
    fi
    act "move memory $name -> repo memory"
    if ! dry; then
      mkdir -p "$to"
      mv "$f" "$to/$name"
      grep -F "($name)" "$from/MEMORY.md" 2>/dev/null >> "$to/MEMORY.md" || true
    fi
  done
}

cmd_list() {
  local repo wt branch state merged
  printf '%-28s %-46s %-30s %s\n' REPO WORKTREE BRANCH STATE
  while read -r repo; do
    while IFS=$'\t' read -r wt branch; do
      [ -n "$wt" ] || continue
      if [ ! -d "$wt" ]; then
        state="missing (prunable)"
      else
        state="$(age "$wt")"
        is_dirty "$wt" && state="$state, uncommitted changes"
        merged="$(merged_reason "$repo" "$branch" || true)"
        [ -n "$merged" ] && state="$state, merged ($merged)"
        never_committed "$repo" "$branch" && state="$state, no commits yet"
      fi
      printf '%-28s %-46s %-30s %s\n' "${repo#"$WORKSPACES"/github.com/}" "${wt/#$HOME/~}" "$branch" "$state"
    done < <(linked_worktrees "$repo")
  done < <(repos)
}

cmd_clean() {
  local repo wt branch merged removed=0 kept=0 stale=0
  dry && log "dry run: nothing will change (rerun with apply=true)"
  while read -r repo; do
    local name="${repo#"$WORKSPACES"/github.com/}" pruned
    pruned="$(git -C "$repo" worktree prune --dry-run -v 2>&1 || true)"
    if [ -n "$pruned" ]; then
      act "$name: prune records of deleted worktrees"
      dry || git -C "$repo" worktree prune
    fi
    while IFS=$'\t' read -r wt branch; do
      [ -n "$wt" ] && [ -d "$wt" ] || continue
      if is_dirty "$wt"; then
        log "  keep ${wt##*/} ($name): uncommitted changes"; kept=$((kept + 1)); continue
      fi
      if in_use "$wt"; then
        log "  keep ${wt##*/} ($name): a running process is using it"; kept=$((kept + 1)); continue
      fi
      if never_committed "$repo" "$branch"; then
        log "  keep ${wt##*/} ($name): no commits yet"; kept=$((kept + 1)); continue
      fi
      if ! merged="$(merged_reason "$repo" "$branch")"; then
        log "  keep ${wt##*/} ($name): $branch not merged"; kept=$((kept + 1)); continue
      fi
      log "$name: remove ${wt##*/} [$branch, $merged]"
      fold_settings "$wt/$LOCAL_SETTINGS" "$repo/$LOCAL_SETTINGS" "$name main checkout"
      act "git worktree remove ${wt/#$HOME/~} && git branch -D $branch"
      if ! dry; then
        git -C "$repo" worktree remove "$wt"
        git -C "$repo" branch -D "$branch" > /dev/null
      fi
      removed=$((removed + 1))
    done < <(linked_worktrees "$repo")

    # Claude project directories for this repo's worktrees that no longer exist
    local base proj suffix
    base="$(sanitize "$repo")"
    for proj in "$PROJECTS/$base--claude-worktrees-"*; do
      [ -d "$proj" ] || continue
      suffix="${proj##*/$base--claude-worktrees-}"
      if compgen -G "$repo/.claude/worktrees/*" > /dev/null; then
        local live=false d
        for d in "$repo"/.claude/worktrees/*; do
          [ "$(sanitize "${d##*/}")" = "$suffix" ] && live=true
        done
        $live && continue
      fi
      log "$name: Claude project for deleted worktree '$suffix' ($(du -sh "$proj" | cut -f1))"
      if fold_memory "${proj##*/}" "$base"; then
        act "delete ${proj/#$HOME/~}"
        dry || rm -rf "$proj"
        stale=$((stale + 1))
      fi
    done
  done < <(repos)
  log ""
  log "$removed worktree(s) to remove, $kept kept, $stale stale Claude project(s)$(dry && echo ' (dry run)')"
}

cmd_new() {
  local name="${1:?usage: new NAME}" branch="${BRANCH:-}" repo common base wt
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || die "run from inside a git repo"
  repo="${common%/.git}"
  branch="${branch:-$name}"
  wt="$repo/.claude/worktrees/$name"
  [ -e "$wt" ] && die "$wt already exists"
  grep -qxF '.claude/worktrees/' "$repo/.git/info/exclude" 2>/dev/null || echo '.claude/worktrees/' >> "$repo/.git/info/exclude"
  git -C "$repo" fetch -q origin
  base="$(default_ref "$repo")"
  [ -n "$base" ] || die "no origin default branch found"
  git -C "$repo" worktree add -q -b "$branch" "$wt" "$base"
  APPLY=true fold_settings "$repo/$LOCAL_SETTINGS" "$wt/$LOCAL_SETTINGS" "$name"
  APPLY=true copy_local_files "$repo" "$wt"
  log "created $wt on $branch from $base"
  printf '%s\n' "$wt"
}

cmd_update() {
  local repo wt branch
  dry && log "dry run: nothing will change (rerun with apply=true)"
  while read -r repo; do
    local name="${repo#"$WORKSPACES"/github.com/}"
    while IFS=$'\t' read -r wt branch; do
      [ -n "$wt" ] && [ -d "$wt" ] || continue
      # Permissions granted in either place should reach both
      fold_settings "$wt/$LOCAL_SETTINGS" "$repo/$LOCAL_SETTINGS" "$name main checkout"
      fold_settings "$repo/$LOCAL_SETTINGS" "$wt/$LOCAL_SETTINGS" "${wt##*/}"
      copy_local_files "$repo" "$wt"
    done < <(linked_worktrees "$repo")
  done < <(repos)
}

command -v jq > /dev/null || die "jq is required"
case "${1:-}" in
  list) cmd_list ;;
  clean) cmd_clean ;;
  new) shift; cmd_new "$@" ;;
  update) cmd_update ;;
  *) die "usage: worktrees.sh list|clean|new NAME|update" ;;
esac
