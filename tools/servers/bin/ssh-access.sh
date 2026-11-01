#!/bin/sh
# Sets up key login to a server using a key held in 1Password. Needs a terminal for 1Password
# approval and the server's password.
#   usage: ssh-access.sh <server> [--here]
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

name=$(reg_require_server "${1:-}")

if [ "${2:-}" != "--here" ]; then
    open_interactive "'$SERVERS_DIR/bin/ssh-access.sh' $name --here"
    exit 0
fi

"$SERVERS_DIR/bin/ssh-config.sh"

if [ ! -s "$SSH_PUBLIC_KEY" ]; then
    if ! op item get "$OP_SSH_ITEM" --account "$OP_ACCOUNT" >/dev/null 2>&1; then
        echo "Creating the '$OP_SSH_ITEM' SSH key in 1Password."
        # No --vault: the default vault is the one 1Password's SSH agent reads.
        op item create --category "SSH Key" --title "$OP_SSH_ITEM" --account "$OP_ACCOUNT" \
            --ssh-generate-key ed25519 >/dev/null
    fi
    op item get "$OP_SSH_ITEM" --account "$OP_ACCOUNT" --fields "public key" > "$SSH_PUBLIC_KEY"
    chmod 644 "$SSH_PUBLIC_KEY"
    echo "Wrote $SSH_PUBLIC_KEY"
fi

if ssh -o BatchMode=yes -o ConnectTimeout=8 "$name" true 2>/dev/null; then
    echo "[OK] $name already accepts this key"
    exit 0
fi

echo "Enter $name's password one last time."
# Password-only so the agent can't use up the server's auth attempts offering other keys.
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no "$name" \
    'umask 077; mkdir -p ~/.ssh; k=$(cat); grep -qxF "$k" ~/.ssh/authorized_keys 2>/dev/null || printf "%s\n" "$k" >> ~/.ssh/authorized_keys' \
    < "$SSH_PUBLIC_KEY"

if ssh -o BatchMode=yes -o ConnectTimeout=8 "$name" true; then
    echo "[DONE] $name now logs in without a password"
else
    echo "[ERROR] the key was copied, but $name still refuses key login" >&2
    exit 1
fi
