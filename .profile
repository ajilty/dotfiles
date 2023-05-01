#######################################################
# SHELL
#######################################################

# echo "file: .profile"

# Set common aliases
if [ -f ~/.aliases ]; then
. ~/.aliases
fi

# Set common env variables
if [ -f ~/.env ]; then
. ~/.env
fi

# Use Zsh if it is installed
if [ -f /bin/zsh ]; then
    export SHELL=/bin/zsh
    exec /bin/zsh -l
fi

if [ -f ~/.bashrc ]; then . ~/.bashrc; fi