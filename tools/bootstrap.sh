#!/bin/sh

# f:verb=run f:name=system-bootstrap
# <f|description>
# Bootstrap a new system (macOS or Ubuntu) with Flow, tools, and dotfiles.
# </f|description>

set -e

# Detect OS
OS_TYPE="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS_TYPE="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == "ubuntu" ]]; then
      OS_TYPE="ubuntu"
    fi
  fi
fi

echo "Starting System Bootstrap"
echo "========================="
echo "Detected OS: $OS_TYPE"
echo ""

if [ "$OS_TYPE" = "unknown" ]; then
  echo "[ERROR] Unsupported operating system: $OSTYPE"
  echo "This script supports macOS and Ubuntu only."
  exit 1
fi

export BINDIR=${BINDIR:-"$HOME/.local/bin"}
mkdir -p $BINDIR

echo ""
echo "Installing Flow CLI..."
if (command -v flow > /dev/null); then
  echo "[OK] Flow is already installed"
  flow --version
else
  echo "Downloading and installing Flow..."
  curl -sSL https://raw.githubusercontent.com/jahvon/flow/main/scripts/install.sh | bash

  # Add to PATH for current session only
  # Dotfiles will handle permanent PATH setup in .zshenv
  export PATH="$HOME/.local/bin:$PATH"
fi

if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  # We're in a git repo, get the root
  REPO_PATH=$(git rev-parse --show-toplevel)
  echo "Using existing repository at: $REPO_PATH"
else
  # Not in a repo, clone it
  REPO_PATH="$HOME/workspaces/github.com/jahvon/system"
  if [ ! -d "$REPO_PATH" ]; then
    echo "Cloning system repository to $REPO_PATH..."
    mkdir -p "$(dirname "$REPO_PATH")"
    git clone https://github.com/jahvon/system.git "$REPO_PATH" || \
    git clone git@github.com:jahvon/system.git "$REPO_PATH"
  fi
fi

echo ""
echo "Initalizing workspace..."
cd "$REPO_PATH"
flow workspace init main "$REPO_PATH" || true
flow sync -x

echo ""
echo "Bootstrapping..."
flow apply flow:config
flow run bootstrap: