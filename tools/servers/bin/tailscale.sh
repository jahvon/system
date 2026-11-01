#!/bin/sh
# Installs Tailscale on a server and applies the settings from the registry. Safe to re-run.
# Needs a terminal for the sudo password and browser sign-in.
#   usage: tailscale.sh <server> [--here]
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

name=$(reg_require_server "${1:-}")

if [ "${2:-}" != "--here" ]; then
    open_interactive "$SERVERS_DIR/bin/tailscale.sh $name --here"
    exit 0
fi

lan=$(yq -r '.network.lan' "$INVENTORY")
is_router=$(N="$name" yq -r '.network.tailscale.routers | any_c(. == env(N))' "$INVENTORY")
exit_node=$(yq -r '.network.tailscale.exitNode' "$INVENTORY")

# LAN hosts must not route their own subnet through the tailnet, and Pi-hole owns DNS here.
flags="--reset --hostname=$name --accept-routes=false --accept-dns=false"
[ "$is_router" = "true" ] && flags="$flags --advertise-routes=$lan"
[ "$exit_node" = "$name" ] && flags="$flags --advertise-exit-node"

ssh -t "$name" "command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh; sudo tailscale up $flags && tailscale status | head -5"
echo "[DONE] $name applied: $flags"
echo "If routes are new, approve them at https://login.tailscale.com/admin/machines and disable key expiry."
