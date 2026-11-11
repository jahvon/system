#!/bin/sh
# Sets up and runs persistent Remote Control servers on a server, one per registry session.
# Each is a systemd user service running tmux, so it starts at boot and survives disconnects. New
# sessions can be started on it, each in its own worktree, from the desktop app, claude.ai, or mobile.
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
preamble='set -eu; export PATH="$HOME/.local/bin:/usr/local/bin:$PATH" XDG_RUNTIME_DIR="/run/user/$(id -u)"'

case "$action" in
    install)
        git_url=$(W="$workspace" yq -r '.workspaces[env(W)].git' "$INVENTORY")
        remote "$(checkout_for "$workspace")" "$git_url" "$session" "$workspace" <<EOF
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
# commands are denied, through flow or mochi, because project settings pre-approve them, which would bypass those prompts.
# With mochi installed, agent-framework hides the project flow server in favor of mochi's, so only approve it without mochi.
overlay="\$HOME/.claude/settings.overlay.json"
[ -f "\$overlay" ] || echo '{}' > "\$overlay"
mochi=false
{ command -v mochi || [ -x "\$HOME/.mochi/bin/mochi" ]; } >/dev/null 2>&1 && mochi=true
tmp=\$(mktemp)
jq --argjson mochi "\$mochi" '.permissions.defaultMode = "default"
    | .permissions.deny = (((.permissions.deny // []) + [("flow", "mochi") as \$s | "run_command", "run_python", "run_executable" | "mcp__\(\$s)__\(.)"]) | unique)
    | if \$mochi then .enabledMcpjsonServers = ((.enabledMcpjsonServers // []) - ["flow"])
      else .enabledMcpjsonServers = (((.enabledMcpjsonServers // []) + ["flow"]) | unique) end' \
    "\$overlay" > "\$tmp" && mv "\$tmp" "\$overlay"
echo "[DONE] permission mode: default, ad hoc flow and mochi commands denied, \$([ "\$mochi" = true ] && echo 'mochi MCP in use' || echo 'flow MCP approved')"

af=\$(flow workspace list -o json | jq -r '.workspaces[] | select(.name == "agent-framework") | .path')
if [ -n "\$af" ]; then
    (cd "\$af" && flow update agent:global 2>&1 | tail -2)
    echo "[DONE] agent-framework at \$(git -C "\$af" log --oneline -1 | cut -c1-60)"
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

# Trust is per project and isn't inherited from a parent, so mark every repo in the workspace directory.
# The user chose to trust everything there. Stop the session first, because Claude rewrites this file.
systemctl --user stop "\$3.service" 2>/dev/null || true
tmux kill-session -t "\$3" 2>/dev/null || true
sleep 1
cp -p "\$HOME/.claude.json" "\$HOME/.claude.json.bak-trust"
find "\$HOME/workspaces" -maxdepth 6 -type d -name .git -prune 2>/dev/null | sed 's|/.git\$||' | jq -R . | jq -s . > "\$tmp"
jq --slurpfile dirs "\$tmp" 'reduce \$dirs[0][] as \$d (.; .projects[\$d].hasTrustDialogAccepted = true)' "\$HOME/.claude.json" > "\$tmp.new"
mv "\$tmp.new" "\$HOME/.claude.json"
chmod 600 "\$HOME/.claude.json"
echo "[DONE] trusted \$(jq length "\$tmp") repos under ~/workspaces"
rm -f "\$tmp"

# Waits for claude.ai first, because Remote Control doesn't retry if the network isn't up when Claude starts.
# Restarts the server if it exits; it gives up after about 10 minutes offline.
mkdir -p "\$HOME/.config/systemd/user"
cat > "\$HOME/.config/systemd/user/\$3.service" <<UNIT
[Unit]
Description=Claude Code Remote Control server for \$4

[Service]
Type=oneshot
RemainAfterExit=yes
Environment=PATH=\$HOME/.local/bin:\$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/bin/tmux new-session -d -s \$3 -c \$checkout "zsh -lc 'until curl -s -o /dev/null -m 5 https://claude.ai; do sleep 5; done; while true; do claude remote-control --name \$4 --spawn worktree --capacity 8 --permission-mode default; sleep 5; done'"
ExecStop=/usr/bin/tmux kill-session -t \$3

[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable "\$3.service" 2>&1 | tail -1
echo "[DONE] \$3 starts at boot (linger: \$(loginctl show-user "\$(id -un)" -p Linger --value))"
jq -c '{defaultMode: .permissions.defaultMode, attribution: .attribution}' "\$HOME/.claude/settings.json"
EOF
        ;;
    start)
        remote "$session" <<EOF
$preamble
systemctl --user cat "\$1.service" >/dev/null 2>&1 || { echo "[ERROR] \$1 isn't installed. Run: flow install server:claude" >&2; exit 1; }
if systemctl --user is-active --quiet "\$1.service"; then
    echo "[OK] \$1 is already running"
else
    systemctl --user start "\$1.service"
    echo "[DONE] started \$1"
fi
EOF
        ;;
    status)
        remote "$session" <<EOF
$preamble
echo "service: \$(systemctl --user is-active "\$1.service" 2>&1 || true) enabled: \$(systemctl --user is-enabled "\$1.service" 2>&1 || true)"
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
systemctl --user stop "\$1.service" && echo "[DONE] stopped \$1. It starts again at the next boot."
EOF
        ;;
    *)
        sed -n 5p "$0" >&2
        exit 2
        ;;
esac
