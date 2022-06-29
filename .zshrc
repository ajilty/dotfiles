#######################################################
# Oh My Zsh!
# Configure plug-ins and preferences
#######################################################
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
plugins=( zsh-autosuggestions zsh-syntax-highlighting zsh-completions git docker kubectl aws gcloud pip pipenv)
source $ZSH/oh-my-zsh.sh
source $ZSH_CUSTOM/themes/powerlevel10k/powerlevel10k.zsh-theme
source $ZSH_CUSTOM/themes/powerlevel10k/config/p10k-pure.zsh

# Customize
COMPLETION_WAITING_DOTS="true"

# Set coomon env variables
source ~/.env

# Set common aliases
source ~/.aliases

# Set common shell functions
source ~/.functions
