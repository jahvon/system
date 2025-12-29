#!/bin/bash

# f:verb=install f:name=brew
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

brew bundle --file=/dev/stdin <<EOF
tap "homebrew/bundle"
tap "homebrew/services"

# Core
brew "openssl@3"
brew "wget"
brew "telnet"
brew "jq"
brew "yq"
brew "gawk"
brew "tmux"

# Programming Languages
brew "openjdk@17"
brew "python@3.11"
# brew "go" # installing with version manager instead
brew "golangci-lint"
brew "node"
brew "yarn"

cask "goreleaser/tap/goreleaser"

# Databases
brew "postgresql"
brew "redis"
brew "mysql"
brew "sqlite"

# IDEs
cask "visual-studio-code"
cask "goland"
cask "jetbrains-gateway"

# Tools
brew "gh"
brew "podman"
brew "hugo"
brew "neovim"
brew "thefuck"

brew "age"
brew "git-recent"
brew "git-secret"
brew "protobuf"

# Kubernetes
brew "kubectl"
brew "kubectx"
brew "helm"
brew "fluxcd/tap/flux"
brew "talosctl"

brew "k9s"
brew "kind"
brew "operator-sdk"

# Cloud Providers
tap "hashicorp/tap"

brew "awscli"
brew "eksctl"
brew "hashicorp/tap/terraform"
EOF

echo "Updating Homebrew..."
brew update && brew upgrade
brew cleanup -s
