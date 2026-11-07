#!/usr/bin/env bash
# Configure the docker CLI for Colima and start Colima as a login service.
set -euo pipefail

[[ "$OSTYPE" == darwin* ]] || { echo "[SKIP] Colima setup is macOS-only; servers run Docker Engine natively"; exit 0; }

cpus="${COLIMA_CPUS:-4}"
memory="${COLIMA_MEMORY:-6}"
disk="${COLIMA_DISK:-60}"
brew_prefix="$(brew --prefix)"

for cmd in colima docker jq docker-credential-osxkeychain; do
  command -v "$cmd" >/dev/null || { echo "[ERROR] $cmd missing; run: flow install packages:homebrew" >&2; exit 1; }
done

config="$HOME/.docker/config.json"
mkdir -p "$(dirname "$config")"
[[ -s "$config" ]] || echo '{}' >"$config"
# Homebrew installs buildx and compose as plugins outside the CLI's default search path.
jq --arg dir "$brew_prefix/lib/docker/cli-plugins" '
  .cliPluginsExtraDirs = ((.cliPluginsExtraDirs // []) + [$dir] | unique)
  | .credsStore = "osxkeychain"
' "$config" >"$config.tmp" && mv "$config.tmp" "$config"
echo "[DONE] docker CLI config: plugins from Homebrew, credentials in the macOS keychain"

if ! colima status >/dev/null 2>&1; then
  if colima list -j 2>/dev/null | jq -e 'select(.name == "default")' >/dev/null; then
    # VM type and disk are fixed once created; CPU and memory can change on restart.
    colima start --cpus "$cpus" --memory "$memory"
  else
    colima start --vm-type vz --vz-rosetta --mount-type virtiofs \
      --cpus "$cpus" --memory "$memory" --disk "$disk"
  fi
fi

# A login service brings containers with restart policies back after a reboot.
brew services list | grep -q '^colima .*started' || brew services start colima

docker context use colima >/dev/null
docker info --format 'engine {{.ServerVersion}} on {{.OperatingSystem}}, {{.NCPU}} CPUs, {{.MemTotal}} bytes'
docker buildx version
docker compose version
echo "[DONE] Colima is the active container runtime"
