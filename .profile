#######################################################
# SHELL
#######################################################

# dotfile debug
if [ -n "$DOTFILE_DEBUG" ]; then
    echo "Loading ~/.profile"
fi

# Use Zsh if it is installed
if [ -f /bin/zsh ]; then
    export SHELL=/bin/zsh
    exec /bin/zsh -l
fi

if [ -f ~/.bashrc ]; then . ~/.bashrc; fi