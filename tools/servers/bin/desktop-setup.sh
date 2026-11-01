#!/bin/sh
# Prepares RDP to a server's desktop: Windows App here, then the firewall and credentials on the server.
# Safe to re-run. Needs a terminal for sudo on both machines.
#   usage: desktop-setup.sh <server> [--here]
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

name=$(reg_require_server "${1:-}")
[ "$(reg_get "$name" .desktop.protocol)" = "rdp" ] || { echo "'$name' has no RDP desktop in the registry" >&2; exit 2; }

if [ "${2:-}" != "--here" ]; then
    open_interactive "$SERVERS_DIR/bin/desktop-setup.sh $name --here"
    exit 0
fi

if [ ! -d "/Applications/Windows App.app" ]; then
    echo "Installing Windows App. macOS may ask for your password."
    brew install --cask windows-app
fi

lan=$(yq -r '.network.lan' "$INVENTORY")
port=$(reg_get "$name" .desktop.port)
user=$(reg_get "$name" .user)

echo "Configuring $name. Enter its sudo password when asked."
# Allow the LAN and tailnet before removing any broader rule, so access never drops.
ssh -t "$name" "
    sudo ufw allow from $lan to any port $port proto tcp comment 'RDP from LAN' &&
    sudo ufw allow in on tailscale0 to any port $port proto tcp comment 'RDP from tailnet' &&
    { sudo ufw delete allow $port/tcp 2>/dev/null; sudo ufw delete allow $port 2>/dev/null; true; } &&
    sudo ufw status | grep -E 'Status|$port' &&
    if sudo grdctl --system status | grep -qE 'Username: *\(empty\)'; then
        echo 'Choose a username and password for remote login. Save the password in 1Password.'
        printf 'New RDP password: '; stty -echo; read -r rdp_pass; stty echo; echo
        sudo grdctl --system rdp set-credentials $user \"\$rdp_pass\"; unset rdp_pass
    else
        echo '[OK] RDP credentials are already set. To change them: sudo grdctl --system rdp set-credentials USER PASSWORD'
    fi &&
    sudo grdctl --system rdp enable &&
    sudo grdctl --system status | grep -E 'Status|Port|Username'
"
echo "[DONE] Now run: flow open server:desktop $name"
