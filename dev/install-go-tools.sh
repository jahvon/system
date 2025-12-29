#!/bin/sh

# f:verb=install f:name=tools
# f:desc=Install go version manager and go tools

set -e

GOBIN="$GOPATH/bin"
if [[ -f $GOBIN/g ]]; then
  goversion=$(go version | awk '{print $3}')
  echo "go version manager (g) is already installed (go version: $goversion)"
else
  echo "Installing go version manager (g)..."
  curl -sSL https://git.io/g-install | sh -s -- -y
  $GOBIN/g install latest
fi

if (command -v mockgen > /dev/null); then
  mockgenversion=$(mockgen --version)
  echo "go mockgen is already installed ($mockgenversion)"
else
  echo "Installing go mockgen..."
  go install go.uber.org/mock/mockgen@latest
fi

if (command -v dlv > /dev/null); then
  dlvversion=$(dlv version)
  echo "dlv is already installed ($dlvversion)"
else
  echo "Installing dlv..."
  go install github.com/go-delve/delve/cmd/dlv@latest
fi
