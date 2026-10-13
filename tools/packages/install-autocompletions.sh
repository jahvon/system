#!/bin/bash

# f:verb=install f:name=autocompletions
# f:alias=completions
# f:desc=Install autocompletions for shell tools

set -e

COMPLETIONS_DIR="$HOME/.zsh/completions"
mkdir -p "$COMPLETIONS_DIR"

if (command -v flow > /dev/null); then
  echo "Updating flow zsh autocompletion..."
  flow completion zsh > "$COMPLETIONS_DIR/_flow"
fi

MOCHI_BIN="$(command -v mochi || true)"
MOCHI_BIN="${MOCHI_BIN:-$FLOWEXEC/mochi/bin/mochi}"
if [ -x "$MOCHI_BIN" ]; then
  echo "Updating mochi zsh autocompletion..."
  "$MOCHI_BIN" completion zsh > "$COMPLETIONS_DIR/_mochi"
fi

# Force a full compinit on the next shell so new completions are picked up
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"*
