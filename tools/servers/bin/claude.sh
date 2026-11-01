#!/bin/sh
# Sets up and runs persistent Claude Code sessions on a server, from the sessions in the registry.
# Each runs in tmux with Remote Control on, so it survives disconnects and is reachable from claude.ai.
#   usage: claude.sh <install|start|status|connect|stop> <server> [workspace]
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

action="${1:-}"
name=$(reg_require_server "${2:-}")

# Registry value with ~ left for the server to expand.
checkout_for() { N="$name" W="$1" yq -r '.servers[env(N)].sessions[] | select(.workspace == env(W)) | .checkout' "$INVENTORY"; }
sessions() { N="$name" yq -r '(.servers[env(N)].sessions // [])[].workspace' "$INVENTORY"; }

workspace="${3:-$(sessions | head -1)}"
[ -n "$workspace" ] || { echo "'$name' has no sessions in the registry" >&2; exit 2; }
[ -n "$(checkout_for "$workspace")" ] || { echo "'$name' has no session for '$workspace'" >&2; exit 2; }
session="claude-$workspace"

# Remote snippets run under sh, so zsh's special variables don't apply.
remote() { ssh -o BatchMode=yes -o ConnectTimeout=8 "$name" 'sh -s' -- "$@"; }
preamble='set -eu; export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"'

case "$action" in
    install)
        git_url=$(W="$workspace" yq -r '.workspaces[env(W)].git' "$INVENTORY")
        remote "$(checkout_for "$workspace")" "$git_url" <<EOF
$preamble
checkout=\$(printf '%s' "\$1" | sed "s|^~|\$HOME|")
if [ -d "\$checkout/.git" ]; then
    echo "[OK] checkout at \$checkout"
elif [ -d "\$checkout" ] && [ -n "\$(ls -A "\$checkout")" ]; then
    echo "[ERROR] \$checkout has files but isn't a git repo" >&2
    exit 1
else
    GIT_TERMINAL_PROMPT=0 git clone -q "\$2" "\$checkout"
    echo "[DONE] cloned \$2"
fi

# Servers run the cluster, so sessions ask before risky actions rather than using auto mode. Ad hoc flow
# commands are denied because project settings pre-approve them, which would bypass those prompts.
overlay="\$HOME/.claude/settings.overlay.json"
[ -f "\$overlay" ] || echo '{}' > "\$overlay"
tmp=\$(mktemp)
jq '.permissions.defaultMode = "default"
    | .permissions.deny = (((.permissions.deny // []) + ["mcp__flow__run_command", "mcp__flow__run_python", "mcp__flow__run_executable"]) | unique)' \
    "\$overlay" > "\$tmp" && mv "\$tmp" "\$overlay"
echo "[DONE] permission mode: default, ad hoc flow commands denied"

af=\$(flow workspace list -o json | jq -r '.workspaces[] | select(.name == "agent-framework") | .path')
if [ -n "\$af" ]; then
    cd "\$af" && flow install agent:global 2>&1 | tail -2
else
    echo "[WARN] agent-framework isn't registered; run flow update server:workspaces"
fi

system=\$(flow workspace list -o json | jq -r '.workspaces[] | select(.name == "system") | .path')
mkdir -p "\$HOME/.claude/skills"
for skill in "\$system"/.claude/skills/*/; do
    ln -sfn "\${skill%/}" "\$HOME/.claude/skills/\$(basename "\$skill")"
done
echo "[DONE] linked system skills"

[ -f "\$HOME/.tmux.conf" ] || printf 'set -g mouse on\nset -g history-limit 50000\n' > "\$HOME/.tmux.conf"
jq -c '{defaultMode: .permissions.defaultMode, deny: .permissions.deny, attribution: .attribution}' "\$HOME/.claude/settings.json"
EOF
        ;;
    start)
        remote "$session" "$(checkout_for "$workspace")" "$workspace" <<EOF
$preamble
checkout=\$(printf '%s' "\$2" | sed "s|^~|\$HOME|")
[ -d "\$checkout/.git" ] || { echo "[ERROR] no checkout at \$checkout. Run: flow install server:claude" >&2; exit 1; }
if tmux has-session -t "\$1" 2>/dev/null; then
    echo "[OK] \$1 is already running"
    exit 0
fi
# Resumes the last conversation when there is one. The shell afterward keeps the session open to inspect.
tmux new-session -d -s "\$1" -c "\$checkout" "zsh -lc 'claude --continue --remote-control \$3 || claude --remote-control \$3; exec zsh -l'"
echo "[DONE] started \$1 in \$checkout"
EOF
        ;;
    status)
        remote "$session" <<EOF
$preamble
if ! tmux has-session -t "\$1" 2>/dev/null; then
    echo "\$1 is not running"
    exit 1
fi
tmux list-sessions -F '#S created #{t:session_created} attached=#{session_attached}' | grep "^\$1 "
tmux capture-pane -p -t "\$1" | grep -v '^ *\$' | tail -15
EOF
        ;;
    connect)
        open_interactive "ssh -t $name tmux attach -t $session"
        ;;
    stop)
        remote "$session" <<EOF
$preamble
tmux kill-session -t "\$1" 2>/dev/null && echo "[DONE] stopped \$1" || echo "\$1 was not running"
EOF
        ;;
    *)
        sed -n 4p "$0" >&2
        exit 2
        ;;
esac
