#!/bin/sh
# Runs one non-interactive command on a server and returns its output and exit code.
#   usage: command.sh <server> <command>
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

name=$(reg_require_server "${1:-}")
[ -n "${2:-}" ] || { echo "usage: command.sh <server> <command>" >&2; exit 2; }
exec ssh -o BatchMode=yes -o ConnectTimeout=8 "$name" "$2"
