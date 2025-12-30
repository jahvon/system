#!/bin/bash

# f:verb=setup f:name=git
# f:desc=Setup Git configuration

set -e

echo "Setting up Git configuration..."

GIT_USER_NAME=$(git config --global user.name || echo "")
GIT_USER_EMAIL=$(git config --global user.email || echo "")
GITHUB_USER=$(git config --global github.user || echo "")

if [ -z "$GIT_USER_NAME" ]; then
  read -p "Enter your Git user name: " GIT_USER_NAME
  git config --global user.name "$GIT_USER_NAME"
fi

if [ -z "$GIT_USER_EMAIL" ]; then
  read -p "Enter your Git email: " GIT_USER_EMAIL
  git config --global user.email "$GIT_USER_EMAIL"
fi

if [ -z "$GITHUB_USER" ]; then
  read -p "Enter your GitHub username: " GITHUB_USER
  git config --global github.user "$GITHUB_USER"
fi

# Credential helper (platform-specific)
if [ "$(uname)" = "Darwin" ]; then
  git config --global credential.helper osxkeychain
else
  git config --global credential.helper store
fi

# Core settings
git config --global core.excludesfile "~/.gitignore_global"
git config --global core.editor "nvim"

# Include local config
git config --global include.path "~/.gitconfig.local"

# Aliases
git config --global alias.unstage "reset HEAD --"
git config --global alias.last "log -1 HEAD"

# URL rewrites for SSH
git config --global url."ssh://git@github.com/".insteadOf "https://github.com/"
git config --global url."ssh://git@github.com/".insteadOf "gh:"

# Init settings
git config --global init.defaultBranch main

# Commit settings
git config --global commit.template "~/.gitmessage"

# Push/Pull settings
git config --global push.autoSetupRemote true
git config --global pull.ff only

# Color settings
git config --global color.ui auto
git config --global color.branch.current "yellow reverse"
git config --global color.branch.local yellow
git config --global color.branch.remote green
git config --global color.diff.meta "yellow bold"
git config --global color.diff.frag "magenta bold"
git config --global color.diff.old "red bold"
git config --global color.diff.new "green bold"
git config --global color.status.added yellow
git config --global color.status.changed green
git config --global color.status.untracked red

# Create local override file
touch "$HOME/.gitconfig.local"

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
