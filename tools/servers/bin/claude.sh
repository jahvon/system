#!/bin/sh
# Sets up and runs persistent Remote Control servers on a server, one per workspace in its registry entry.
# Each is a systemd user service running tmux, so it starts at boot and survives disconnects. New
# sessions can be started on it, each in its own worktree, from the desktop app, claude.ai, or mobile.
# Without a workspace, acts on all of them; connect takes the first.
#   usage: claude.sh <install|start|status|connect|stop> <server> [workspace]
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

action="${1:-}"
name=$(reg_require_server "${2:-}")

workspaces() { N="$name" yq -r '(.servers[env(N)].workspaces // [])[]' "$INVENTORY"; }
git_for() { W="$1" yq -r '.workspaces[env(W)].git' "$INVENTORY"; }
# The registry's checkout, else ~/workspaces/<host>/<owner>/<repo> from the git URL. ~ is left for the server.
checkout_for() {
    W="$1" yq -r '.workspaces[env(W)].checkout // ""' "$INVENTORY" | grep . \
        || git_for "$1" | sed -E 's|^git@([^:]+):|\1/|; s|^https?://||; s|\.git$||; s|^|~/workspaces/|'
}

[ -n "$(workspaces)" ] || { echo "'$name' has no workspaces in the registry" >&2; exit 2; }
if [ -n "${3:-}" ]; then
    workspaces | grep -qxF "$3" || { echo "'$3' isn't one of $name's workspaces: $(workspaces | tr '\n' ' ')" >&2; exit 2; }
    targets="$3"
else
    targets=$(workspaces)
fi

# Remote snippets run under sh, so zsh's special variables don't apply.
remote() { ssh -o BatchMode=yes -o ConnectTimeout=8 "$name" 'sh -s' -- "$@"; }
preamble='set -eu; export PATH="$HOME/.local/bin:/usr/local/bin:$PATH" XDG_RUNTIME_DIR="/run/user/$(id -u)"'

case "$action" in
    install)
        set --
        for ws in $targets; do set -- "$@" "$ws" "$(checkout_for "$ws")" "$(git_for "$ws")"; done
        remote "$@" <<EOF
$preamble
# Arguments come in threes: workspace, checkout, git URL.
expand() { printf '%s' "\$1" | sed "s|^~|\$HOME|"; }
args="\$*"
while [ \$# -ge 3 ]; do
    checkout=\$(expand "\$2")
    if [ -d "\$checkout/.git" ]; then
        echo "[OK] \$1 checkout at \$checkout"
    elif [ -d "\$checkout" ] && [ -n "\$(ls -A "\$checkout")" ]; then
        echo "[ERROR] \$checkout has files but isn't a git repo" >&2
        exit 1
    else
        GIT_TERMINAL_PROMPT=0 git clone -q "\$3" "\$checkout"
        echo "[DONE] cloned \$3"
    fi
    shift 3
done
set -- \$args

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
# The user chose to trust everything there. Stop every Claude server first, because Claude rewrites this file.
running=\$(systemctl --user list-units --plain --no-legend --state=active 'claude-*.service' | cut -d' ' -f1)
for unit in \$running; do systemctl --user stop "\$unit"; done
tmux ls -F '#S' 2>/dev/null | grep '^claude-' | xargs -r -n1 tmux kill-session -t
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
# No session is pre-created, so idle servers don't each hold a Claude process.
mkdir -p "\$HOME/.config/systemd/user"
units=
while [ \$# -ge 3 ]; do
ws=\$1 checkout=\$(expand "\$2") unit=claude-\$1
cat > "\$HOME/.config/systemd/user/\$unit.service" <<UNIT
[Unit]
Description=Claude Code Remote Control server for \$ws

[Service]
Type=oneshot
RemainAfterExit=yes
Environment=PATH=\$HOME/.local/bin:\$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/bin/tmux new-session -d -s \$unit -c \$checkout "zsh -lc 'until curl -s -o /dev/null -m 5 https://claude.ai; do sleep 5; done; while true; do claude remote-control --name \$ws --spawn worktree --capacity 8 --no-create-session-in-dir --permission-mode default; sleep 5; done'"
ExecStop=/usr/bin/tmux kill-session -t \$unit

[Install]
WantedBy=default.target
UNIT
units="\$units \$unit.service"
shift 3
done
systemctl --user daemon-reload
systemctl --user enable \$units 2>&1 | grep -v '^Created symlink' || true
# Start what was installed, and restart what was stopped for the trust edit.
systemctl --user start \$units \$running
echo "[DONE] running:\$units \$running (start at boot; linger: \$(loginctl show-user "\$(id -un)" -p Linger --value))"
jq -c '{defaultMode: .permissions.defaultMode, attribution: .attribution}' "\$HOME/.claude/settings.json"
EOF
        ;;
    start)
        remote $targets <<EOF
$preamble
for ws in "\$@"; do
    unit=claude-\$ws
    systemctl --user cat "\$unit.service" >/dev/null 2>&1 || { echo "[ERROR] \$unit isn't installed. Run: flow install server:claude $name" >&2; exit 1; }
    if systemctl --user is-active --quiet "\$unit.service"; then
        echo "[OK] \$unit is already running"
    else
        systemctl --user start "\$unit.service"
        echo "[DONE] started \$unit"
    fi
done
EOF
        ;;
    status)
        remote $targets <<EOF
$preamble
down=0
for ws in "\$@"; do
    unit=claude-\$ws
    echo "== \$unit service: \$(systemctl --user is-active "\$unit.service" 2>&1 || true) enabled: \$(systemctl --user is-enabled "\$unit.service" 2>&1 || true)"
    if ! tmux has-session -t "\$unit" 2>/dev/null; then
        echo "\$unit is not running"
        down=1
        continue
    fi
    tmux capture-pane -p -t "\$unit" | grep -v '^ *\$' | tail -6
done
exit \$down
EOF
        ;;
    connect)
        open_interactive "ssh -t $name tmux attach -t claude-$(printf '%s\n' $targets | head -1)"
        ;;
    stop)
        remote $targets <<EOF
$preamble
for ws in "\$@"; do
    systemctl --user stop "claude-\$ws.service" && echo "[DONE] stopped claude-\$ws. It starts again at the next boot."
done
EOF
        ;;
    *)
        sed -n 5p "$0" >&2
        exit 2
        ;;
esac
