#!/bin/sh
# Prints the registry as a table. Reads local files only.
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

last_status() {
    flow cache get --global "server.$1.status" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' \
        | jq -r 'if .reachable then "up@" else "down@" end + .checked' 2>/dev/null || echo "-"
}

{
    echo "NAME KIND ADDRESS USER K8S-NODE ALIASES LAST-STATUS"
    yq -r '.servers | to_entries | .[] | [
        .key,
        .value.kind,
        .value.address,
        (.value.user // "-"),
        (.value.k8sNode // "-"),
        ((.value.aliases // []) | join(",") | select(. != "") // "-")
    ] | join(" ")' "$INVENTORY" | while read -r line; do
        echo "$line $(last_status "${line%% *}")"
    done
} | column -t
