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
################
# setopt RE_MATCH_PCRE   # _fix-omz-plugin function uses this regex style
# Workaround for zinit issue#504: remove subversion dependency. Function clones all files in plugin
# directory (on github) that might be useful to zinit snippet directory. Should only be invoked
# via zinit atclone"_fix-omz-plugin"
_fix-omz-plugin() {
   echo "RUNNING _fix-omz-plugin"
   local PLUG_DIR="$(pwd)" # not sure why after clone, the directory is not the plugin directory

  if [[ ! -f ._zinit/teleid ]] then return 0; fi
  if [[ ! $(cat ._zinit/teleid) =~ "^OMZP::.*" ]] then return 0; fi
  local OMZP_NAME=$(cat ._zinit/teleid | sed -n 's/OMZP:://p')
  git clone --quiet --no-checkout --depth=1 --filter=tree:0 https://github.com/ohmyzsh/ohmyzsh
  cd $PLUG_DIR
  cd ohmyzsh
  git sparse-checkout set --no-cone plugins/$OMZP_NAME
  git checkout --quiet
  cd ..
  local OMZP_PATH="ohmyzsh/plugins/$OMZP_NAME"
  local file
  echo "Copying files from $OMZP_PATH to $(pwd)..."
  for file in ohmyzsh/plugins/$OMZP_NAME/*~(.gitignore|*.plugin.zsh)(D); do
    local filename="${file:t}"
    echo "Copying $file to $(pwd)/$filename..."
    cp $file $filename
  done
  rm -rf ohmyzsh
}

# Install zinit plugin manager
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
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
    OMZP::direnv \
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
    OMZP::npm
# These plugins have more than one file, so we need to clone the whole repo
zinit atpull"%atclone" atclone"_fix-omz-plugin" wait lucid for \
    OMZP::gitfast

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
