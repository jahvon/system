#!/bin/bash

# f:verb=install f:name=ubuntu
# f:desc=Install core packages on Ubuntu systems (equivalent to core Brewfile packages)

set -e

echo "Updating package lists..."
sudo apt-get update

echo "Installing core Ubuntu packages..."

# Core utilities (equivalent to macOS Homebrew core)
sudo apt-get install -y \
  curl \
  wget \
  telnet \
  openssl \
  jq \
  gawk \
  tmux \
  zsh \
  git \
  build-essential

# Development tools
sudo apt-get install -y \
  python3 \
  python3-pip \
  nodejs \
  npm

# Additional tools from the Brewfile
sudo apt-get install -y \
  neovim \
  gh

# Install yq (not available in standard apt repos)
echo "Installing yq..."
YQ_VERSION="v4.40.5"
sudo wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
sudo chmod +x /usr/local/bin/yq

echo "Cleaning up..."
sudo apt-get autoremove -y
sudo apt-get clean

echo "[DONE] Core packages installed successfully"
