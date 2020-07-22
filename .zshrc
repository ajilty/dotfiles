export ZSH=$HOME/.oh-my-zsh
export ZSH_CUSTOM=$HOME/.zsh_custom
COMPLETION_WAITING_DOTS="true"
plugins=( zsh-autosuggestions zsh-syntax-highlighting zsh-completions git docker kubectl aws)
source $ZSH/oh-my-zsh.sh
source $ZSH_CUSTOM/themes/powerlevel10k/powerlevel10k.zsh-theme
source $ZSH_CUSTOM/themes/powerlevel10k/config/p10k-pure.zsh
