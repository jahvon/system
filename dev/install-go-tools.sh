#!/bin/sh

# f:verb=install f:name=tools
# f:desc=Install Go developer tools (mockgen, dlv); Go itself comes from mise

set -e

if ! command -v go > /dev/null; then
  echo "go is not on PATH; run 'flow install dotfiles:mise' first"
  exit 1
fi
echo "Using $(go version)"

echo "Installing mockgen..."
go install go.uber.org/mock/mockgen@latest

echo "Installing dlv..."
go install github.com/go-delve/delve/cmd/dlv@latest

echo "[DONE] Go tools installed to $(go env GOBIN)"
