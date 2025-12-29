#!/bin/bash

# f:verb=setup f:name=git
# f:desc=Setup Git configuration on Ubuntu systems

set -e

echo "Setting up Git configuration..."

GIT_USER_NAME=$(git config --global user.name || echo "")
GIT_USER_EMAIL=$(git config --global user.email || echo "")

if [ -z "$GIT_USER_NAME" ]; then
  read -p "Enter your Git user name: " GIT_USER_NAME
  git config --global user.name "$GIT_USER_NAME"
fi

if [ -z "$GIT_USER_EMAIL" ]; then
  read -p "Enter your Git email: " GIT_USER_EMAIL
  git config --global user.email "$GIT_USER_EMAIL"
fi

git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor "vim"

SSH_KEY="$HOME/.ssh/id_ed25519"
if [ ! -f "$SSH_KEY" ]; then
  echo "No SSH key found. Generating new SSH key..."
  ssh-keygen -t ed25519 -C "$GIT_USER_EMAIL" -f "$SSH_KEY" -N ""

  echo ""
  echo "[DONE] SSH key generated at: $SSH_KEY"
  echo ""
  echo "Your public key (add this to GitHub/GitLab):"
  echo "================================================"
  cat "$SSH_KEY.pub"
  echo "================================================"
  echo ""
else
  echo "SSH key already exists at: $SSH_KEY"
fi

eval "$(ssh-agent -s)"
ssh-add "$SSH_KEY"

echo "[DONE] Git configured successfully"
echo "       Name:  $GIT_USER_NAME"
echo "       Email: $GIT_USER_EMAIL"
