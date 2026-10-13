# Sourced from both .zshenv and .zprofile: macOS /etc/zprofile runs path_helper, which
# moves system paths ahead of these in login shells.
typeset -U path

if [[ -d /opt/homebrew ]]; then
  export HOMEBREW_PREFIX=/opt/homebrew
elif [[ -d /home/linuxbrew/.linuxbrew ]]; then
  export HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew
fi

path=(
  $HOME/.local/share/mise/shims
  $HOME/go/bin
  $HOME/.cargo/bin
  $HOME/.local/bin
  ${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/bin}
  ${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/sbin}
  $path
)
export PATH
