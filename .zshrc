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

# Skip the not really helping Ubuntu global compinit
skip_global_compinit=1

# ZSH Customizations
COMPLETION_WAITING_DOTS="true"
HIST_REDUCE_BLANKS="true"
HIST_FIND_NO_DUPS="true"
HIST_IGNORE_SPACE="true"
INC_APPEND_HISTORY="true"
SHARE_HISTORY="true"
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=60 # don't suggest large pastes
ZSH_AUTOSUGGEST_STRATEGY=(match_prev_cmd completion) # suggest recent match whose preceding history item matches, otherwise use completion

# ZSH Plugins
zinit wait lucid for \
    OMZP::git \
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
    OMZP::nmap
    # OMZP::pyenv


# These plugins have more than one file, so we need to clone the whole repo
zinit wait lucid for \
    atpull"%atclone" atclone"_fix-omz-plugin" \
        OMZP::gitfast

PS1="READY >" # provide a simple prompt till the theme loads
setopt promptsubst
zinit ice depth=1; zinit light romkatv/powerlevel10k
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# 
# zi for \
#     atload"zicompinit; zicdreplay" \
#     blockf \
#     lucid \
#     wait \
#         zsh-users/zsh-completions \
#         zsh-users/zsh-autosuggestions \
#         zdharma-continuum/fast-syntax-highlighting \
#     ver"23.07.13" \
#     atload'zicompinit' \
#         marlonrichert/zsh-autocomplete




zinit wait lucid for \
 atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
 blockf \
    zsh-users/zsh-completions \
 atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions

# zinit wait lucid for \
#   atload"zicdreplay" \
#   ver"23.07.13" \
#     marlonrichert/zsh-autocomplete

# zinit ice ver"23.07.13" atload'zicompinit'
# zinit light marlonrichert/zsh-autocomplete
# zinit ice ver"23.07.13"; zinit load marlonrichert/zsh-autocomplete

# # Customize auto-complete
# bindkey -M menuselect "^[OD" .backward-char # auto-complete: ← exits menu select
# bindkey -M menuselect "^[OC" .forward-char  # auto-complete: → exits menu select
# bindkey -M menuselect '\r' .accept-line     # auto-complete: enter should accept a selection in menu select
# bindkey '^[v' .describe-key-briefly # Helper to find key bindings 
