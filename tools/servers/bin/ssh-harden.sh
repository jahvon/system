#!/bin/sh
# Turns off SSH password login on a server, with an automatic rollback in case it locks anyone out.
# Needs a terminal for sudo. Safe to re-run. Console login and the RDP desktop are unaffected.
#   usage: ssh-harden.sh <server> [--here]
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

name=$(reg_require_server "${1:-}")

if [ "${2:-}" != "--here" ]; then
    open_interactive "$SERVERS_DIR/bin/ssh-harden.sh $name --here"
    exit 0
fi

if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "$name" true; then
    echo "[ERROR] key login to $name doesn't work, so passwords stay on. Run: flow install server:ssh-access $name" >&2
    exit 1
fi

conf=/etc/ssh/sshd_config.d/00-flow-hardening.conf
rollback=flow-ssh-rollback

echo "Applying on $name. Enter its sudo password when asked. Rollback runs in 5 minutes unless cancelled."
# Files in this directory are read in order and the first value wins, so 00- beats 50-cloud-init.conf.
ssh -t "$name" "
    sudo sh -c 'printf \"PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin no\n\" > $conf' &&
    if ! sudo sshd -t; then sudo rm -f $conf; echo '[ERROR] invalid sshd config, removed it'; exit 1; fi &&
    sudo systemd-run --quiet --unit=$rollback --on-active=300 /bin/sh -c 'rm -f $conf; systemctl reload ssh' &&
    sudo systemctl reload ssh &&
    sudo sshd -T | grep -E '^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin) '
"

# Fresh connections, because an existing session proves nothing about new logins.
sleep 2
ok=true
if ssh -o BatchMode=yes -o ConnectTimeout=8 "$name" true; then
    echo "[OK] key login works"
else
    echo "[FAIL] key login doesn't work"
    ok=false
fi
methods=$(ssh -o BatchMode=yes -o ConnectTimeout=8 -o PreferredAuthentications=none "$name" true 2>&1 | sed -n 's/.*Permission denied (\(.*\)).*/\1/p')
echo "server offers: ${methods:-unknown}"
case "$methods" in
    publickey) echo "[OK] passwords are refused" ;;
    *) echo "[FAIL] passwords may still be accepted"; ok=false ;;
esac

if [ "$ok" = true ]; then
    ssh -t "$name" "sudo systemctl stop $rollback.timer $rollback.service 2>/dev/null; sudo systemctl reset-failed $rollback.timer $rollback.service 2>/dev/null; true"
    echo "[DONE] $name accepts SSH keys only"
else
    echo "[ERROR] leaving the rollback in place. $name returns to its previous SSH settings within 5 minutes." >&2
    exit 1
fi
