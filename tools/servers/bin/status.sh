#!/bin/sh
# Reports a server's health and saves it to flow's data store as server.<name>.status. Read-only on the server.
#   usage: status.sh <server>
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

name=$(reg_require_server "${1:-}")
checked=$(date -u +%Y-%m-%dT%H:%M:%SZ)

save() { flow cache set --global "server.$name.status" "$1" >/dev/null 2>&1 || echo "[WARN] could not save status" >&2; }

if ! raw=$(ssh -o BatchMode=yes -o ConnectTimeout=8 "$name" 'sh -s' < "$SERVERS_DIR/lib/probe.sh" 2>/dev/null); then
    echo "$name: unreachable over SSH. Set up access with flow install server:ssh-access $name"
    save "{\"reachable\":false,\"checked\":\"$checked\"}"
    exit 1
fi

printf '%s\n' "$raw" | sed 's/=/: /' | sed "s/^/$name /"
json=$(printf '%s\n' "$raw" | jq -Rn --arg checked "$checked" \
    '[inputs | capture("^(?<key>[^=]+)=(?<value>.*)$")] | from_entries + {reachable: true, checked: $checked}' -c)
save "$json"
