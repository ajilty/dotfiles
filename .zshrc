# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Load profile
source "$HOME/.profile"

if type brew &>/dev/null
then
  export FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

# Zinit
###############################

# Install zinit plugin manager
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"


# Oh My Zsh! Customizations
COMPLETION_WAITING_DOTS="true"
# HIST_* settings are mostly set by OMZL::history.zsh


# ===  Completions, Plugins and Theme Installation with Zinit  ===

# Completion Management
zinit cdclear -q  # Clear any existing compdef entries
skip_global_compinit=1 # Skip global compinit on Ubuntu
[ ! -d ~/.cache/zinit/completions ] && mkdir -p ~/.cache/zinit/completions # Create completion cache directory

zinit wait lucid for \
    OMZP::git-auto-fetch \
    OMZP::gh \
    OMZP::urltools \
    OMZL::functions.zsh \
    OMZL::termsupport.zsh \
    OMZL::directories.zsh \
    OMZL::history.zsh \
    OMZP::aws \
    OMZP::azure \
    OMZP::gcloud \
    OMZP::kubectl \
    OMZP::helm \
    OMZP::docker \
  as"completion" \
    OMZP::docker/completions/_docker \
    OMZP::docker-compose \
  as"completion" \
    OMZP::docker-compose/_docker-compose \
    OMZP::vagrant \
  as"completion" \
    OMZP::vagrant/_vagrant \
    OMZP::terraform \
  as"completion" \
    OMZP::terraform/_terraform \
    OMZP::pip \
    OMZP::pipenv \
    OMZP::poetry \
    OMZP::node \
  if'[[ -n "$commands[op]" ]]' atload'eval "$(op completion zsh)"; compdef _op o' \
    OMZP::1password \
    OMZP::vscode \
    OMZP::brew \
    OMZP::nmap \
    OMZP::pyenv \
    nix-community/nix-zsh-completions \
    OMZP::npm \
  as"snippet" \
    https://github.com/ajilty/ohmyzsh/blob/master/plugins/direnv/direnv.plugin.zsh

# Theme Management
PS1="Loading..." # provide a simple prompt till the theme loads
setopt promptsubst
zinit ice depth'1' lucid nocd atload'source ~/.p10k.zsh; _p9k_precmd'
zinit light romkatv/powerlevel10k 

# Plugin Management
## Configure OMZ plugin AWS to not show prompt
SHOW_AWS_PROMPT=false

## Configure marlonrichert/zsh-autocomplete
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=60                    # don't suggest large pastes
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd completion)  # suggest recent match whose preceding history item matches, otherwise use completion
# bindkey -M menuselect "^[OD" .backward-char # auto-complete: ← exits menu select
# bindkey -M menuselect "^[OC" .forward-char  # auto-complete: → exits menu select
# bindkey -M menuselect '\r' .accept-line     # auto-complete: enter should accept a selection in menu select
# bindkey '^[v' .describe-key-briefly # Helper to find key bindings 

zi ice \
  ver"23.07.13" 
setopt interactivecomments
zi load marlonrichert/zsh-autocomplete


zi for \
      atload"zicompinit; zicdreplay" \
      blockf \
      lucid \
      wait \
   zsh-users/zsh-completions \
   zsh-users/zsh-autosuggestions \
   zdharma-continuum/fast-syntax-highlighting 
   
# Powerlevel10k Instant Prompt
(( ! ${+functions[p10k]} )) || p10k finalize

# MANUALLY FORCE HOME
# If we are stuck in the zinit repo (which happens after first-run compiles), go home.
[[ "$PWD" == *"zinit.git"* ]] && cd "$HOME"