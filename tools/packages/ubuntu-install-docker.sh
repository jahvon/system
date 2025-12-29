#!/bin/bash

# f:verb=install f:name=docker
# f:desc=Install Docker Engine on Ubuntu systems

set -e

if (command -v docker > /dev/null); then
  echo "Docker is already installed"
  docker --version
  exit 0
fi

echo "Installing Docker on Ubuntu..."

# Remove old Docker installations
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

# Install prerequisites
sudo apt-get update
sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group
sudo usermod -aG docker $USER

echo "[DONE] Docker installed successfully"
echo "[INFO] You may need to log out and back in for group changes to take effect"
echo "[INFO] To verify installation, run: docker run hello-world"
