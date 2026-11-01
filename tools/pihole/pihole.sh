#!/bin/sh
# Operates Pi-hole on the DNS server named in the registry, through its CLI, so no API password is needed.
#   usage: pihole.sh <status|summary|top-queries|top-blocked|clients|pause [seconds]|enable|flush|gravity|apply|records>
set -eu
DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SERVERS_DIR="$DIR/../servers"
. "$SERVERS_DIR/lib/registry.sh"

server=$(yq -r '.network.dns.server' "$INVENTORY")
pihole() { ssh -o BatchMode=yes -o ConnectTimeout=8 "$server" docker exec pihole pihole "$@"; }
# The CLI prints a harmless shell warning to stderr on some versions.
api() { pihole api "'$1'" 2>/dev/null; }

summary() {
    api stats/summary | jq -r '
        "Queries today: \(.queries.total)",
        "Blocked today: \(.queries.blocked) (\(.queries.percent_blocked | floor)%)",
        "Domains on blocklists: \(.gravity.domains_being_blocked)",
        "Active clients: \(.clients.active)"'
}

apply() {
    tag=$(date +%Y%m%d-%H%M%S)
    dir='~/workspaces/pihole'
    pass_before=$(ssh "$server" 'docker exec pihole pihole-FTL --config webserver.api.pwhash | shasum | cut -c1-12')
    echo "Backing up Pi-hole settings to $dir/backups on $server"
    ssh "$server" "mkdir -p $dir/backups && chmod 700 $dir/backups \
        && docker exec -w /tmp pihole sh -c 'rm -f /tmp/pi-hole_*teleporter*; pihole-FTL --teleporter >/dev/null 2>&1; cat /tmp/pi-hole_*teleporter*.zip' > $dir/backups/teleporter-$tag.zip \
        && [ -s $dir/backups/teleporter-$tag.zip ] \
        && cp -p $dir/docker-compose.yml $dir/backups/docker-compose-$tag.yml"
    ssh "$server" "cat > $dir/docker-compose.yml.new && chmod 600 $dir/docker-compose.yml.new && mv $dir/docker-compose.yml.new $dir/docker-compose.yml" \
        < "$DIR/docker-compose.yml"
    echo "Restarting Pi-hole. DNS is briefly unavailable."
    ssh "$server" "cd $dir && docker compose pull -q && docker compose up -d"
    for _ in $(seq 1 30); do
        sleep 5
        health=$(ssh "$server" "docker inspect pihole --format '{{.State.Health.Status}}'" 2>/dev/null || echo unknown)
        [ "$health" = "healthy" ] && break
    done
    [ "$health" = "healthy" ] || { echo "[ERROR] Pi-hole is $health after 150 seconds. Previous compose file: $dir/backups/docker-compose-$tag.yml" >&2; exit 1; }
    pass_after=$(ssh "$server" 'docker exec pihole pihole-FTL --config webserver.api.pwhash | shasum | cut -c1-12')
    [ "$pass_before" = "$pass_after" ] || echo "[WARN] the admin password changed during the update"
    ssh "$server" 'docker exec pihole pihole -v' | cut -d'(' -f1
    echo "[DONE] Pi-hole applied on $server"
}

# Adds an A record in Pi-hole for each server, like devbox.malik.haus. Leaves other records alone.
records() {
    domain=$(yq -r '.network.domain' "$INVENTORY")
    current=$(ssh "$server" 'docker exec pihole pihole-FTL --config dns.hosts' | tr -d '[]' | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$')
    changed=false
    for name in $(yq -r '.servers | to_entries | .[] | select(.value.kind == "server") | .key' "$INVENTORY"); do
        record="$(reg_get "$name" .address) $name.$domain"
        if printf '%s\n' "$current" | grep -qxF "$record"; then
            echo "[OK] $record"
        else
            current=$(printf '%s\n%s' "$current" "$record")
            changed=true
            echo "[ADD] $record"
        fi
    done
    [ "$changed" = true ] || return 0
    json=$(printf '%s\n' "$current" | jq -R . | jq -sc .)
    ssh "$server" "docker exec pihole pihole-FTL --config dns.hosts '$json'" >/dev/null
}

case "${1:-}" in
    records) records ;;
    status) pihole status 2>/dev/null; api dns/blocking | jq -r '"Blocking: \(.blocking)"' ;;
    summary) summary ;;
    top-queries) api 'stats/top_domains?count=15' | jq -r '.domains[] | "\(.count)\t\(.domain)"' ;;
    top-blocked) api 'stats/top_domains?blocked=true&count=15' | jq -r '.domains[] | "\(.count)\t\(.domain)"' ;;
    clients) api 'stats/top_clients?count=15' | jq -r '.clients[] | "\(.count)\t\(.name // "")\t\(.ip)"' ;;
    pause) pihole disable "${2:-300}s" ;;
    enable) pihole enable ;;
    flush) pihole -f ;;
    gravity) pihole -g ;;
    apply) apply ;;
    *) sed -n 3p "$0" >&2; exit 2 ;;
esac
