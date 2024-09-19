# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

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


# ZSH Customizations
COMPLETION_WAITING_DOTS="true"
HIST_REDUCE_BLANKS="true"
HIST_FIND_NO_DUPS="true"
HIST_IGNORE_SPACE="true"
INC_APPEND_HISTORY="true"
SHARE_HISTORY="true"
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=60 # don't suggest large pastes
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd completion) # suggest recent match whose preceding history item matches, otherwise use completion

# ===  Plugin and Theme Installation with Zinit  ===

# Enable Plugin Completion Management
zinit cdclear -q  # Clear any existing compdef entries
# Skip global compinit on Ubuntu
skip_global_compinit=1

# if .cache/zinit/completions doesn't exist, create it
[ ! -d ~/.cache/zinit/completions ] && mkdir -p ~/.cache/zinit/completions
zinit wait lucid for \
      OMZP::git \
      OMZP::gitfast \
      OMZP::git-auto-fetch \
      OMZP::gh \
      OMZP::dotenv \
      OMZP::aws \
      OMZP::azure \
      OMZP::gcloud \
      OMZP::kubectl \
      OMZP::helm \
      OMZP::docker \
      OMZP::docker-compose \
      OMZP::vagrant \
      OMZP::terraform \
      OMZP::pip \
      OMZP::pipenv \
      OMZP::poetry \
      OMZP::npm \
      OMZP::yarn \
      OMZP::node \
      OMZP::1password \
      OMZP::vscode \
      OMZP::brew \
      OMZP::nmap \
      OMZP::pyenv

# stuft that unproven
#    atpull"%atclone" atclone"_fix-omz-plugin" multisrc"{1password.plugin.zsh _opswd opswd}" \
#       OMZP::terraform/_terraform \
#       OMZP::vagrant/_vagrant \
#       OMZP::docker-compose/_docker-compose \
#       OMZP::docker/completions/_docker \
# zi ice as"completion"
# zi snippet OMZP::gitfast/_git
zi ice as"completion"
zi snippet OMZP::vagrant/_vagrant

# These plugins have more than one file, so we need to clone the whole repo
zinit wait lucid for \
    atpull"%atclone" atclone"_fix-omz-plugin" \
        OMZP::gitfast
# zinit wait lucid as"completion" for \
   


# Install Powerlevel10k
PS1="Loading..." # provide a simple prompt till the theme loads
setopt promptsubst
zinit ice depth'1' lucid nocd atload'source ~/.p10k.zsh; _p9k_precmd'
zinit light romkatv/powerlevel10k 

# Install Plugins for Enhanced Completion, Syntax Highlighting, and Autosuggestions - Load with Turbo
zinit wait lucid for \
   atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
      zdharma-continuum/fast-syntax-highlighting \
   atload"!_zsh_autosuggest_start" \
      zsh-users/zsh-autosuggestions 

zi for \
      atload"zicompinit; zicdreplay" \
      blockf \
      lucid \
      wait \
   zsh-users/zsh-completions \
   zsh-users/zsh-autosuggestions \
   zdharma-continuum/fast-syntax-highlighting 
   
# zi ice ver"23.07.13"
# zi load marlonrichert/zsh-autocomplete



# # Customize auto-complete
# bindkey -M menuselect "^[OD" .backward-char # auto-complete: ← exits menu select
# bindkey -M menuselect "^[OC" .forward-char  # auto-complete: → exits menu select
# bindkey -M menuselect '\r' .accept-line     # auto-complete: enter should accept a selection in menu select
# bindkey '^[v' .describe-key-briefly # Helper to find key bindings 

# Powerlevel10k Instant Prompt
(( ! ${+functions[p10k]} )) || p10k finalize