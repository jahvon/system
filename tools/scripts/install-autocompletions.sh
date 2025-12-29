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

if (command -v flux > /dev/null); then
  echo "Updating flux zsh autocompletion..."
  touch ~/.oh-my-zsh/completions/_flux
  flux completion zsh > ~/.oh-my-zsh/completions/_flux
fi
