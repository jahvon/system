# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt.zsh"
fi

# -- zsh and oh-my-zsh configuration --
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

CASE_SENSITIVE="false"
HYPHEN_INSENSITIVE="false"
DISABLE_AUTO_UPDATE="false"
DISABLE_UPDATE_PROMPT="true"
ENABLE_CORRECTION="false"
COMPLETION_WAITING_DOTS="true"
HIST_STAMPS="mm/dd/yyyy"

export HISTSIZE=10000
export UPDATE_ZSH_DAYS=14

# -- Plugins --
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  brew
  golang
  kubectl
  history
)

source $ZSH/oh-my-zsh.sh

### To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

### For thefuck plugin which handles shell command corrections
eval $(thefuck --alias fix)

### Fixes slowness of pastes with zsh-syntax-highlighting.zsh
pasteinit() {
  OLD_SELF_INSERT=${${(s.:.)widgets[self-insert]}[2,3]}
  zle -N self-insert url-quote-magic
}

pastefinish() {
  zle -N self-insert $OLD_SELF_INSERT
}
zstyle :bracketed-paste-magic paste-init pasteinit
zstyle :bracketed-paste-magic paste-finish pastefinish

# -- Aliases --
alias ll="ls -al"
alias mkdir="mkdir -p"
alias e="$EDITOR"
alias v="$VISUAL"
alias c="clear"
alias h="history"

alias ozshrc="$EDITOR ~/.zshrc.local"
alias ozshenv="$EDITOR ~/.zshenv.local"

### Navigating
alias gohome="cd $HOME"
alias gocache="cd $CACHE_ROOT"
alias godev="cd $DEV_ROOT"
alias gonotes="cd $NOTES_ROOT"
alias godownloads="cd $DOWNLOADS_ROOT"
alias goapps="cd $APPS_ROOT"
alias golabs="cd $LABS_ROOT"
alias gotools="cd $TOOLS_ROOT"
alias gooss="cd $OSS_ROOT"
alias gows="cd $FLOW_WS_ROOT"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

### Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n}'

# -- Environment Variables --

### GoLand IDE for macos
export GOLAND_HOME="/Applications/GoLand.app/Contents/MacOS"
export PATH="$PATH:$GOLAND_HOME"

### Go and GVM
alias gvm="$GOPATH/bin/g"
export GOPATH="$HOME/go"; export GOROOT="$HOME/.go"; export PATH="$GOPATH/bin:$PATH"; # g-install: do NOT edit, see https://github.com/stefanmaric/g
export GOBIN="$GOPATH/bin"

### Kubernetes
DEFAULT_KUBECONFIG_FILE="$HOME/.kube/config"
if test -f "${DEFAULT_KUBECONFIG_FILE}"
then
  export KUBECONFIG="$DEFAULT_KUBECONFIG_FILE"
fi
ADD_KUBECONFIG_FILES="$HOME/.kube/configs"
OIFS="$IFS"
IFS=$'\n'
for kubeconfigFile in `find "${ADD_KUBECONFIG_FILES}" -type f -name "*.yml" -o -name "*.yaml"`
do
    export KUBECONFIG="$kubeconfigFile:$KUBECONFIG"
done
IFS="$OIFS"

# -- Local config --
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
