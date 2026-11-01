#!/bin/sh
# Prepares a server to read flow secrets from 1Password with a service account. Copies vault references,
# never secret values. The token is created separately, and is piped straight to the server by the user.
#   usage: secrets.sh <server>
set -eu
SERVERS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
. "$SERVERS_DIR/lib/registry.sh"

name=$(reg_require_server "${1:-}")
vault=$(flow config get -o json 2>/dev/null | jq -r '.currentVault')
local_root="$HOME/Library/Caches/flow/vaults"
config="$local_root/configs/$vault.json"
links="$local_root/$vault/vault-$vault.links.json"
[ -f "$config" ] && [ -f "$links" ] || { echo "no external vault files for '$vault' under $local_root" >&2; exit 1; }
op_version=$(op --version)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
jq 'del(.external.storage_path)' "$config" > "$tmp/config.json"

ssh -o BatchMode=yes -o ConnectTimeout=8 "$name" 'umask 077; mkdir -p ~/.config/op; chmod 700 ~/.config/op; cat > ~/.config/op/flow-vault.json' < "$tmp/config.json"
ssh -o BatchMode=yes -o ConnectTimeout=8 "$name" 'umask 077; cat > ~/.config/op/flow-links.json' < "$links"

ssh -o BatchMode=yes -o ConnectTimeout=8 "$name" sh -s -- "$vault" "$op_version" <<'EOF'
set -eu
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
vault="$1"
version="$2"

if command -v op >/dev/null; then
    echo "[OK] op $(op --version)"
else
    case "$(uname -m)" in
        x86_64) arch=amd64 ;;
        aarch64) arch=arm64 ;;
        *) echo "unsupported architecture" >&2; exit 2 ;;
    esac
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL -o "$tmp/op.zip" "https://cache.agilebits.com/dist/1P/op2/pkg/v$version/op_linux_${arch}_v$version.zip"
    unzip -q "$tmp/op.zip" -d "$tmp"
    GNUPGHOME="$tmp/gnupg"; export GNUPGHOME
    mkdir -m 700 "$GNUPGHOME"
    # 1Password's published release signing key.
    gpg -q --keyserver hkps://keyserver.ubuntu.com --receive-keys 3FEF9748469ADBE15DA7CA80AC2D62742012EA22
    gpg -q --verify "$tmp/op.sig" "$tmp/op"
    mkdir -p "$HOME/.local/bin"
    install -m 755 "$tmp/op" "$HOME/.local/bin/op"
    echo "[DONE] installed op $(op --version), signature verified"
fi

# Loaded in every shell, including the non-interactive ones flow and systemd sessions use.
line='[ -s ~/.config/op/service-account-token ] && export OP_SERVICE_ACCOUNT_TOKEN="$(cat ~/.config/op/service-account-token)"'
touch "$HOME/.zshenv.local"
sed -i '/^\[ -f ~\/.config\/op\/service-account-token \]/d' "$HOME/.zshenv.local"
grep -qxF "$line" "$HOME/.zshenv.local" || printf '%s\n' "$line" >> "$HOME/.zshenv.local"
echo "[DONE] ~/.zshenv.local loads the token file when it exists"

if ! flow vault get "$vault" -o json >/dev/null 2>&1; then
    flow vault create "$vault" --type external --config "$HOME/.config/op/flow-vault.json" >/dev/null
    echo "[DONE] created flow vault $vault"
fi
store=$(flow vault get "$vault" -o json | jq -r '.path')
mkdir -p "$store"
install -m 600 "$HOME/.config/op/flow-links.json" "$store/vault-$vault.links.json"
rm -f "$HOME/.config/op/flow-links.json" "$HOME/.config/op/flow-vault.json"
flow vault switch "$vault" >/dev/null
echo "[DONE] flow vault $vault is current, with $(jq '.links | length' "$store/vault-$vault.links.json") references"
[ -s "$HOME/.config/op/service-account-token" ] && echo "[OK] token file present" || echo "[NEXT] no token file yet"
EOF
