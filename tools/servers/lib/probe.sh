# Runs on a server through `ssh <server> sh -s`. Prints key=value lines and changes nothing.
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/local/bin:$PATH"

echo "uptime=$(uptime -p | sed 's/^up //')"
echo "load=$(cut -d' ' -f1-3 /proc/loadavg)"
echo "disk=$(df -h / | awk 'NR == 2 { print $5 }')"
echo "reboot=$([ -f /var/run/reboot-required ] && echo required || echo no)"
echo "k3s=$(k3s --version 2>/dev/null | awk 'NR == 1 { print $3 }')"
echo "flow=$(flow --version 2>/dev/null | awk '/^Version/ { print $2 }')"
echo "claude=$(claude --version 2>/dev/null | awk 'NR == 1 { print $1 }')"
echo "tailscale=$(tailscale version 2>/dev/null | head -1)"
echo "tmux=$(tmux list-sessions -F '#S' 2>/dev/null | paste -sd, -)"
echo "workspaces=$(flow workspace list -o json 2>/dev/null | jq -r '[.workspaces[].name] | join(",")' 2>/dev/null)"
