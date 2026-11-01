#!/bin/sh
# Lists, compares, or applies the flow workspaces the registry assigns to a server.
# Remote snippets run under the server's zsh, where `path` and `status` are special variables.
#   usage: workspaces.sh <show|check|update> <server>
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

action="${1:-}"
name=$(reg_require_server "${2:-}")
remote() { ssh -o BatchMode=yes -o ConnectTimeout=8 "$name" 'export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"; '"$1"; }

registered() { remote 'flow workspace list -o json' | jq -r '.workspaces[] | "\(.name)\t\(.path)"'; }
wanted() { N="$name" yq -r '(.servers[env(N)].workspaces // [])[]' "$INVENTORY"; }

case "$action" in
    show)
        registered
        ;;
    check)
        current=$(registered | cut -f1)
        missing=0
        for ws in $(wanted); do
            if printf '%s\n' "$current" | grep -qxF "$ws"; then
                echo "[OK]   $ws"
            else
                echo "[MISSING] $ws"
                missing=1
            fi
        done
        for ws in $current; do
            [ "$ws" = "default" ] || wanted | grep -qxF "$ws" || echo "[EXTRA] $ws is registered but not in the registry"
        done
        exit "$missing"
        ;;
    update)
        current=$(registered | cut -f1)
        # Bootstrapped machines registered the system checkout as main before it was renamed.
        if printf '%s\n' "$current" | grep -qxF main && ! printf '%s\n' "$current" | grep -qxF system; then
            remote 'ws_dir=$(flow workspace list -o json | jq -r ".workspaces[] | select(.name == \"main\") | .path")
                flow workspace add system "$ws_dir" >/dev/null && flow workspace switch system >/dev/null && flow workspace remove main -y >/dev/null'
            echo "renamed workspace main to system"
            current=$(registered | cut -f1)
        fi
        for ws in $(wanted); do
            printf '%s\n' "$current" | grep -qxF "$ws" && continue
            git=$(W="$ws" yq -r '.workspaces[env(W)].git' "$INVENTORY")
            ref=$(W="$ws" yq -r '.workspaces[env(W)].ref' "$INVENTORY")
            checkout=$(W="$ws" yq -r '.workspaces[env(W)].checkout // ""' "$INVENTORY")
            if [ -n "$checkout" ]; then
                # ~ stays unquoted here so the server expands it.
                dir=$(printf '%s' "$checkout" | sed 's|^~/||')
                remote "[ -d \"\$HOME/$dir/.git\" ] || GIT_TERMINAL_PROMPT=0 git clone -q --branch '$ref' '$git' \"\$HOME/$dir\"; flow workspace add '$ws' \"\$HOME/$dir\" >/dev/null"
                echo "cloned and registered $ws at $checkout"
            else
                remote "GIT_TERMINAL_PROMPT=0 flow workspace add '$ws' '$git' --branch '$ref' 2>/dev/null" >/dev/null
                echo "registered $ws from $git ($ref)"
            fi
        done
        # The system checkout is a plain clone, so refuse to pull over local changes.
        remote 'ws_dir=$(flow workspace list -o json | jq -r ".workspaces[] | select(.name == \"system\") | .path")
            if [ -z "$(git -C "$ws_dir" status --porcelain)" ]; then
                git -C "$ws_dir" pull -q --ff-only && echo "system is at $(git -C "$ws_dir" log --oneline -1 | cut -c1-60)"
            else
                echo "[WARN] system has local changes, so it was not updated"
            fi
            flow sync --git 2>&1 | tail -1'
        registered
        ;;
    *)
        sed -n 4p "$0" >&2
        exit 2
        ;;
esac
