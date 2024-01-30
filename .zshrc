#######################################################
# Oh My Zsh!
# Configure plug-ins and preferences
#######################################################

# echo "file: .zshrc"

source "$HOME/.profile"

# Set zsh site functions if Homebrew is installed
if type brew &>/dev/null
then
  export FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

# Enable Oh My Zsh
export ZSH=$HOME/.oh-my-zsh

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
 
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

# Enable oh-my-zsh plug-ins and themes
# Paths to binaries needs to be set before this in order for the plug-in to load
plugins=(history
  zsh-autosuggestions
  zsh-autocomplete
  zsh-syntax-highlighting
  # history-substring-search
  git
  git-auto-fetch
  urltools
  terraform
  docker
  kubectl
  helm
  aws
  gcloud
  azure
  pip
  # pipenv
  poetry
  nmap
  gh
  1password
  brew
 )

# Conditionally load pipenv plugin to avoid activation issues
if [ "$TERM_PROGRAM" != "vscode" ]; then
  plugins+=(pipenv)
fi

source $ZSH/oh-my-zsh.sh
source $ZSH_CUSTOM/themes/powerlevel10k/powerlevel10k.zsh-theme
# source $ZSH_CUSTOM/themes/powerlevel10k/config/p10k-pure.zsh
source ~/.p10k.zsh

# Customize
COMPLETION_WAITING_DOTS="true"
HIST_REDUCE_BLANKS="true"
HIST_FIND_NO_DUPS="true"
HIST_IGNORE_SPACE="true"
INC_APPEND_HISTORY="true"
SHARE_HISTORY="true"
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=60 # don't suggest large pastes
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd completion) # suggest recent match whose preceding history item matches, otherwise use completion

# Customize auto-complete
bindkey -M menuselect "^[OD" .backward-char # auto-complete: ← exits menu select
bindkey -M menuselect "^[OC" .forward-char  # auto-complete: → exits menu select
# bindkey -M menuselect '\r' .accept-line     # auto-complete: enter should accept a selection in menu select
# bindkey '^[v' .describe-key-briefly # Helper to find key bindings 