#!/bin/bash

set -euo pipefail

function has_dirty_changes() {
  if [[ $(git status --porcelain) ]]; then
    return 0
  else
    return 1
  fi
}

function get_default_branch() {
  local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
  echo "$default_branch"
}

function confirm() {
  read -r -p "$1 [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY])
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

if has_dirty_changes; then
  echo "There are dirty changes in your working directory."
  git status
  if confirm "Do you want to keep these changes?"; then
    read -r -p "Enter stash name: " stash_name
    git stash push -m "$stash_name"
  else
    git reset --hard
  fi
fi

default_branch=$(get_default_branch)
echo "Pulling latest changes from $default_branch branch..."
git checkout "$default_branch"
git pull

read -r -p "Enter the name of the new branch: " branch_name
git checkout -b "$branch_name"
echo "Branch updated to $branch_name"