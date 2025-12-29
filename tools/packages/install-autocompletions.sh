#!/bin/bash

# f:verb=install f:name=autocompletions
# f:alias=completions
# f:desc=Install autocompletions for shell tools

set -e

mkdir -p ~/.oh-my-zsh/completions

if (command -v flow > /dev/null); then
  echo "Updating flow zsh autocompletion..."
  touch ~/.oh-my-zsh/completions/_flow
  flow completion zsh > ~/.oh-my-zsh/completions/_flow
fi
