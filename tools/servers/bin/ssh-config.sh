#!/bin/sh
# Generates ~/.ssh/config.d/servers.conf from the registry and includes it from ~/.ssh/config.
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

CONFIG="$HOME/.ssh/config"
OUT="$HOME/.ssh/config.d/servers.conf"
INCLUDE="Include ~/.ssh/config.d/servers.conf"

mkdir -p "$(dirname "$OUT")"
chmod 700 "$HOME/.ssh" "$(dirname "$OUT")"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
{
    echo "# Generated from system/tools/servers/inventory.yaml by 'flow apply server:ssh-config'. Do not edit."
    for name in $(yq -r '.servers | to_entries | .[] | select(.value.kind == "server") | .key' "$INVENTORY"); do
        aliases=$(N="$name" yq -r '(.servers[env(N)].aliases // []) | join(" ")' "$INVENTORY")
        echo ""
        echo "Host $name${aliases:+ $aliases}"
        echo "    HostName $(reg_get "$name" .address)"
        echo "    User $(reg_get "$name" .user)"
        echo "    IdentityFile $SSH_PUBLIC_KEY"
        echo "    IdentitiesOnly yes"
        echo "    StrictHostKeyChecking accept-new"
        echo "    ServerAliveInterval 30"
    done
} > "$tmp"
cat "$tmp" > "$OUT"
chmod 600 "$OUT"
echo "Wrote $OUT"

touch "$CONFIG"
if ! grep -qxF "$INCLUDE" "$CONFIG"; then
    backup="$CONFIG.bak-$(date +%Y%m%d-%H%M%S)"
    cp -p "$CONFIG" "$backup"
    # Must come first: ssh treats anything after a Host line as part of that block.
    { echo "$INCLUDE"; cat "$backup"; } > "$CONFIG"
    echo "Added the Include to $CONFIG (backup: $backup)"
fi
