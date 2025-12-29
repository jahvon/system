#!/bin/bash

set -euo pipefail

function is_not_main_or_master() {
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$current_branch" != "main" && "$current_branch" != "master" ]]; then
        return 0
    else
        return 1
    fi
}

if ! is_not_main_or_master; then
    echo "Cannot commit changes directly to the main or master branch."
    exit 1
fi

read -r -p "Enter the commit message: " commit_message
git add .
git commit -m "$commit_message" || {
    echo "Error: Commit failed. Leaving repository in its current state."
    exit 1
}
git push origin "$(git rev-parse --abbrev-ref HEAD)"
echo "Changes committed and pushed successfully to $(git rev-parse --abbrev-ref HEAD) branch."
