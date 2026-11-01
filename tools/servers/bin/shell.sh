#!/bin/sh
# Opens an interactive shell on a server in iTerm. Agents get the command printed instead.
#   usage: shell.sh <server>
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

open_interactive "ssh $(reg_require_server "${1:-}")"
