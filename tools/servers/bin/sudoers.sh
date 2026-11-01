#!/bin/sh
# Installs the passwordless sudo allowlist on a Kubernetes node. Needs a terminal for the sudo password.
#   usage: sudoers.sh <server> [--here]
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

name=$(reg_require_server "${1:-}")
if [ -z "$(reg_get "$name" .k8sNode)" ]; then
    echo "'$name' is not a Kubernetes node, so it needs no allowlist" >&2
    exit 2
fi

if [ "${2:-}" != "--here" ]; then
    open_interactive "'$SERVERS_DIR/bin/sudoers.sh' $name --here"
    exit 0
fi

user=$(reg_get "$name" .user)
sed "s/@USER@/$user/" "$SERVERS_DIR/files/sudoers-k3s" | ssh "$name" 'cat > /tmp/flow-k3s-sudoers'
# visudo validates first, because a broken sudoers file can lock sudo out entirely.
ssh -t "$name" 'sudo visudo -cf /tmp/flow-k3s-sudoers \
    && sudo install -o root -g root -m 440 /tmp/flow-k3s-sudoers /etc/sudoers.d/flow-k3s; \
    status=$?; rm -f /tmp/flow-k3s-sudoers; exit $status'
echo "[DONE] allowlist installed on $name"
