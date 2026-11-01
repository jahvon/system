#!/bin/sh
# Prepares GNOME Desktop Sharing over RDP for a server with auto-login and no monitor. Safe to re-run.
# Adds no firewall rules: ufw is off on k3s nodes, so the RDP port is reachable from the LAN and tailnet.
# Needs a terminal for sudo and the new RDP password.
#   usage: desktop-setup.sh <server> [--here]
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

name=$(reg_require_server "${1:-}")
[ "$(reg_get "$name" .desktop.protocol)" = "rdp" ] || { echo "'$name' has no RDP desktop in the registry" >&2; exit 2; }

if [ "${2:-}" != "--here" ]; then
    open_interactive "$SERVERS_DIR/bin/desktop-setup.sh $name --here"
    exit 0
fi

command -v sdl-freerdp >/dev/null || brew install freerdp

user=$(reg_get "$name" .user)

echo "Configuring $name. Enter its sudo password when asked."
# Remote Login stays off: it logs credentials through pkexec and conflicts with the running session.
ssh -t "$name" "
    { sudo grdctl --system rdp clear-credentials; sudo grdctl --system rdp disable; sudo systemctl disable --now gnome-remote-desktop; true; }
"

# Runs in the auto-login session. Screen lock off and the passwordless keyring are deliberate for a home
# server: auto-login leaves other keyrings locked, and Desktop Sharing stores its login in the default one.
# extend mode gives a virtual screen, because mirroring fails with no monitor attached.
ssh -t "$name" '
    export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus XDG_RUNTIME_DIR=/run/user/$(id -u)
    gsettings set org.gnome.desktop.screensaver lock-enabled false
    gsettings set org.gnome.desktop.session idle-delay 0
    keyrings=~/.local/share/keyrings
    if [ ! -e "$keyrings/rdp.keyring" ]; then
        cp -p "$keyrings/default" "$keyrings/default.bak-rdp" 2>/dev/null
        (umask 077; printf "[keyring]\ndisplay-name=rdp\nctime=0\nmtime=0\nlock-on-idle=false\nlock-after=false\n" > "$keyrings/rdp.keyring")
        printf rdp > "$keyrings/default"
        systemctl --user restart gnome-keyring-daemon.service
        sleep 2
    fi
    gsettings set org.gnome.desktop.remote-desktop.rdp screen-share-mode extend
    printf "New RDP password (Return keeps the current one): "; stty -echo; read -r pw; stty echo; echo
    [ -z "$pw" ] || grdctl rdp set-credentials '"$user"' "$pw"
    unset pw
    chmod 600 ~/.local/share/gnome-remote-desktop/certificates/rdp-tls.key 2>/dev/null
    grdctl rdp disable-view-only
    grdctl rdp enable
    systemctl --user enable --now gnome-remote-desktop
    systemctl --user restart gnome-remote-desktop
    grdctl status | grep -E "Status|Port"
'
echo "[DONE] Now run: flow open server:desktop $name"
