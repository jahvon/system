# Sourced by tools/servers/bin/*. Expects SERVERS_DIR to be set to tools/servers.
INVENTORY="$SERVERS_DIR/inventory.yaml"
OP_SSH_ITEM="homelab ssh"
OP_ACCOUNT="my.1password.com"
# The private key stays in 1Password. This public half tells ssh which agent key to use.
SSH_PUBLIC_KEY="$HOME/.ssh/homelab.pub"

# Prints the canonical name for a server name or alias, or fails listing the known names.
reg_resolve() {
    name=$(N="$1" yq -r '.servers | to_entries | .[]
        | select(.key == env(N) or ((.value.aliases // []) | any_c(. == env(N)))) | .key' "$INVENTORY")
    if [ -z "$name" ]; then
        echo "unknown server '$1'. known servers:" >&2
        yq -r '.servers | keys | .[]' "$INVENTORY" | sed 's/^/  /' >&2
        return 2
    fi
    echo "$name"
}

# Prints a field of a server, such as `reg_get devbox .user`. Empty when unset.
reg_get() {
    N="$1" yq -r ".servers[env(N)]$2 // \"\"" "$INVENTORY"
}

# Resolves a name and fails unless it is a machine we can operate on.
reg_require_server() {
    name=$(reg_resolve "$1") || return $?
    if [ "$(reg_get "$name" .kind)" != "server" ]; then
        echo "'$name' is an appliance, which has no remote operations" >&2
        return 2
    fi
    echo "$name"
}

# Runs a command in a new iTerm window, because Mochi and flow have no usable terminal.
# Agents get the command printed instead of windows opening on the user's desktop.
open_interactive() {
    if [ -n "${CLAUDECODE:-}" ] || [ "${FLOW_RUN_SOURCE:-}" = "mcp" ]; then
        echo "This step is interactive. Run it in a terminal:"
        echo "  $1"
        return 0
    fi
    if [ "$(uname)" != "Darwin" ]; then
        exec /bin/sh -c "$1"
    fi
    # The trailing read keeps the window open so the result can be read.
    wrapped="/bin/zsh -lc '$1; read -r \"?Press return to close \"'"
    escaped=$(printf '%s' "$wrapped" | sed 's/\\/\\\\/g; s/"/\\"/g')
    osascript -e "tell application \"iTerm\" to create window with default profile command \"$escaped\"" >/dev/null
    echo "Opened in iTerm."
}
