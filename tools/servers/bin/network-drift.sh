#!/bin/sh
# Compares the registry with the live network. Read-only. Exits 1 if anything is [FAIL];
# [WARN] marks stale information worth cleaning up.
set -u
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

failed=0
ok() { echo "[OK]   $1"; }
warn() { echo "[WARN] $1"; }
fail() { echo "[FAIL] $1"; failed=1; }

# SSH aliases match what the registry would generate.
conf="$HOME/.ssh/config.d/servers.conf"
for name in $(yq -r '.servers | to_entries | .[] | select(.value.kind == "server") | .key' "$INVENTORY"); do
    want=$(reg_get "$name" .address)
    have=$(ssh -G "$name" 2>/dev/null | awk '$1 == "hostname" { print $2; exit }')
    [ "$have" = "$want" ] && ok "ssh alias $name -> $want" \
        || fail "ssh alias $name is $have, registry says $want: run flow apply server:ssh-config"
done
[ -f "$conf" ] || fail "$conf is missing"

# Kubernetes context and nodes.
context=$(yq -r '.clusters.home.context' "$INVENTORY")
if kubectl config get-contexts -o name 2>/dev/null | grep -qxF "$context"; then
    ok "kube context $context exists"
    current=$(kubectl config current-context 2>/dev/null)
    [ "$current" = "$context" ] || warn "current kube context is $current, not $context"
    for name in $(yq -r '.servers | to_entries | .[] | select(.value.k8sNode) | .key' "$INVENTORY"); do
        node=$(reg_get "$name" .k8sNode)
        ip=$(kubectl --context "$context" get node "$node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null | awk '{ print $1 }')
        [ "$ip" = "$(reg_get "$name" .address)" ] && ok "node $node at $ip" \
            || fail "node $node reports '$ip', registry says $(reg_get "$name" .address)"
    done
else
    fail "kube context $context not found"
fi

# DNS.
dns_server=$(yq -r '.network.dns.server' "$INVENTORY")
dns_ip=$(reg_get "$dns_server" .address)
if [ -n "$(dig +short +time=2 +tries=1 "@$dns_ip" pi.hole 2>/dev/null)" ]; then
    ok "Pi-hole answers at $dns_ip ($dns_server)"
else
    fail "Pi-hole does not answer at $dns_ip"
fi

# Tailscale routers, seen from this machine.
ts=$(command -v tailscale || echo /Applications/Tailscale.app/Contents/MacOS/Tailscale)
status=$("$ts" status --json 2>/dev/null || true)
lan=$(yq -r '.network.lan' "$INVENTORY")
if [ -z "$status" ] || [ "$(printf '%s' "$status" | jq -r .BackendState)" != "Running" ]; then
    warn "Tailscale is not running here, so the tailnet was not checked"
else
    for name in $(yq -r '.network.tailscale.routers[]' "$INVENTORY"); do
        peer=$(printf '%s' "$status" | jq -c --arg n "$name" '[.Peer[] | select(.HostName == $n)][0] // empty')
        if [ -z "$peer" ]; then
            fail "router $name is not on the tailnet: run flow install network:tailscale $name"
        elif [ "$(printf '%s' "$peer" | jq -r .Online)" != "true" ]; then
            fail "router $name is offline"
        elif printf '%s' "$peer" | jq -e --arg r "$lan" '.AllowedIPs | index($r)' >/dev/null; then
            ok "router $name is online with $lan approved"
        else
            warn "router $name is online, but $lan is unapproved or it is the standby route"
        fi
    done
    primary=$(printf '%s' "$status" | jq -r --arg r "$lan" '[.Peer[] | select((.PrimaryRoutes // []) | index($r)) | .HostName][0] // "none"')
    printf '%s' "$status" | jq -e '[.Peer[] | select(.HostName | startswith("ts-pod-cidrs"))] | length > 0' >/dev/null \
        && warn "the k3s connector ts-pod-cidrs is still on the tailnet"
    case "$primary" in
        none) fail "nothing is serving $lan on the tailnet" ;;
        *) ok "$lan is served by $primary" ;;
    esac
    printf '%s' "$status" | jq -r '.Peer[] | select(.Online == false and .KeyExpiry != null and .KeyExpiry < (now | todate)) | .HostName' \
        | while read -r stale; do warn "stale tailnet device with an expired key: $stale"; done
fi

# Hardcoded LAN addresses the registry doesn't know about, across the repos that hold them.
known=$(yq -r '.servers[].address' "$INVENTORY")
prefix=$(printf '%s' "$lan" | cut -d. -f1-3)
pattern=$(printf '%s' "$prefix" | sed 's/\./\\./g')
root=$(CDPATH= cd -- "$SERVERS_DIR/../../.." && pwd)
for repo in "$root/kube" "$root/../../git.malik.haus/homelab"; do
    [ -d "$repo" ] || continue
    grep -rIoE --exclude-dir=archive --exclude-dir=.git --exclude-dir=.claude --exclude-dir=.data \
        "$pattern\.[0-9]{1,3}" "$repo" 2>/dev/null | awk -F: '{ print $2 }' | sort -u | grep -vE '\.(0|255)$' | while read -r ip; do
        printf '%s\n' "$known" | grep -qxF "$ip" || warn "$ip is hardcoded in $(basename "$repo") but not in the registry"
    done
done

[ "$failed" -eq 0 ] && echo "No failures." || { echo "Failures found."; exit 1; }
