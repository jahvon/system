#!/bin/sh
# Prints the registry as a table. Reads local files only.
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

{
    echo "NAME KIND ADDRESS USER K8S-NODE ALIASES"
    yq -r '.servers | to_entries | .[] | [
        .key,
        .value.kind,
        .value.address,
        (.value.user // "-"),
        (.value.k8sNode // "-"),
        ((.value.aliases // []) | join(",") | select(. != "") // "-")
    ] | join(" ")' "$INVENTORY"
} | column -t
