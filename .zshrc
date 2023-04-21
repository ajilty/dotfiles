#######################################################
# Oh My Zsh!
# Configure plug-ins and preferences
#######################################################

# dotfile debug
if [ -n "$DOTFILE_DEBUG" ]; then
    echo "Loading ~/.zshrc"
fi

# If we have homebrew, add site functions BEFORE oh-my-zsh which runs compinit
if type brew &>/dev/null
then
  export FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

# Enable Oh My Zsh
export ZSH=$HOME/.oh-my-zsh

### Fix slowness of pastes with zsh-syntax-highlighting.zsh
pasteinit() {
  OLD_SELF_INSERT=${${(s.:.)widgets[self-insert]}[2,3]}
  zle -N self-insert url-quote-magic # I wonder if you'd need `.url-quote-magic`?
}
pastefinish() {
  zle -N self-insert $OLD_SELF_INSERT
}
zstyle :bracketed-paste-magic paste-init pasteinit
zstyle :bracketed-paste-magic paste-finish pastefinish

# Set location of plug-ins and themes
export ZSH_CUSTOM=$HOME/.zsh_custom
# Enable plug-ins and themes
plugins=(history
  zsh-autosuggestions
  zsh-syntax-highlighting
  history-substring-search
  git
  git-auto-fetch
  urltools
  terraform
  docker
  kubectl
  helm
  aws
  gcloud
  pip
  pipenv
  poetry
  nmap
  gh
  1password
 )
source $ZSH/oh-my-zsh.sh
source $ZSH_CUSTOM/themes/powerlevel10k/powerlevel10k.zsh-theme
source $ZSH_CUSTOM/themes/powerlevel10k/config/p10k-pure.zsh

# Customize
COMPLETION_WAITING_DOTS="true"
HIST_REDUCE_BLANKS="true"
HIST_FIND_NO_DUPS="true"
HIST_IGNORE_SPACE="true"
INC_APPEND_HISTORY="true"
SHARE_HISTORY="true"

# Set coomon env variables
source ~/.env

# Set common aliases
source ~/.aliases

# Set common shell functions
source ~/.functions
