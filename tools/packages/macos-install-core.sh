#!/bin/bash

# f:verb=install f:name=macos
# f:alias=homebrew
# f:desc=Run brew bundle to install packages from Brewfile and update Homebrew

set -e

if (command -v brew > /dev/null); then
  echo "Homebrew is already installed"
else
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "Installing Homebrew packages..."
brew bundle --file="${FLOW_DEFINITION_DIR:-$(dirname "$0")}/Brewfile"

echo "Updating Homebrew..."
brew update && brew upgrade
brew cleanup -s
