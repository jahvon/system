#!/bin/sh
# Opens a server's desktop over RDP with FreeRDP, in iTerm so it can ask for the password.
# FreeRDP rather than Windows App, which hangs after login against libfreerdp 3.32.1:
# https://github.com/FreeRDP/FreeRDP/issues/13845
#   usage: desktop.sh <server>
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

name=$(reg_require_server "${1:-}")
[ "$(reg_get "$name" .desktop.protocol)" = "rdp" ] || { echo "'$name' has no RDP desktop in the registry" >&2; exit 2; }
command -v sdl-freerdp >/dev/null || { echo "FreeRDP isn't installed. Run: flow install server:desktop $name" >&2; exit 1; }

address="$name.$(yq -r '.network.domain' "$INVENTORY")"
port=$(reg_get "$name" .desktop.port)
user=$(reg_get "$name" .user)
open_interactive "sdl-freerdp /v:$address:$port /u:$user /cert:tofu /dynamic-resolution +clipboard /from-stdin:force"
