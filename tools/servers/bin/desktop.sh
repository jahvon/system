#!/bin/sh
# Opens a server's desktop in Windows App. The connection file holds no password.
#   usage: desktop.sh <server>
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

name=$(reg_require_server "${1:-}")
[ "$(reg_get "$name" .desktop.protocol)" = "rdp" ] || { echo "'$name' has no RDP desktop in the registry" >&2; exit 2; }

address="$name.$(yq -r '.network.domain' "$INVENTORY")"
port=$(reg_get "$name" .desktop.port)
dir="$HOME/Library/Caches/flow-servers"
file="$dir/$name.rdp"

if [ ! -d "/Applications/Windows App.app" ]; then
    echo "Windows App isn't installed. Run: flow install server:desktop $name" >&2
    exit 1
fi

mkdir -p "$dir"
cat > "$file" <<EOF
full address:s:$address:$port
username:s:$(reg_get "$name" .user)
prompt for credentials:i:1
screen mode id:i:2
use multimon:i:0
audiomode:i:0
redirectclipboard:i:1
EOF

if [ -n "${CLAUDECODE:-}" ] || [ "${FLOW_RUN_SOURCE:-}" = "mcp" ]; then
    echo "Wrote $file. A person opens it with: open -a 'Windows App' '$file'"
    exit 0
fi
open -a "Windows App" "$file"
echo "Opened $name in Windows App."
