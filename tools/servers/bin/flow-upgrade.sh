#!/bin/sh
# Installs this machine's flow version on a server, after verifying the release checksum.
#   usage: flow-upgrade.sh <server>
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

name=$(reg_require_server "${1:-}")
version=$(flow --version 2>/dev/null | awk '/^Version/ { print $2 }')
[ -n "$version" ] || { echo "could not read this machine's flow version" >&2; exit 1; }

ssh -o BatchMode=yes -o ConnectTimeout=8 "$name" "FLOW_VERSION=$version sh -s" <<'EOF'
set -eu
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
target=$(command -v flow)
current=$(flow --version 2>/dev/null | awk '/^Version/ { print $2 }')
if [ "$current" = "$FLOW_VERSION" ]; then
    echo "$(hostname): already on flow $current"
    exit 0
fi
case "$(uname -m)" in
    x86_64) arch=amd64 ;;
    aarch64) arch=arm64 ;;
    *) echo "unsupported architecture" >&2; exit 2 ;;
esac
tarball="flow_v${FLOW_VERSION}_linux_${arch}.tar.gz"
base="https://github.com/flowexec/flow/releases/download/v${FLOW_VERSION}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/$tarball" "$base/$tarball"
curl -fsSL -o "$tmp/sums" "$base/flow_${FLOW_VERSION}_checksums.txt"
(cd "$tmp" && grep -F "$tarball" sums | sha256sum -c - >/dev/null)
tar -xzf "$tmp/$tarball" -C "$tmp" flow
[ "$("$tmp/flow" --version 2>/dev/null | awk '/^Version/ { print $2 }')" = "$FLOW_VERSION" ] \
    || { echo "downloaded binary is not $FLOW_VERSION" >&2; exit 1; }
cat "$tmp/flow" > "$target"
echo "$(hostname): flow $current -> $(flow --version | awk '/^Version/ { print $2 }')"
EOF
