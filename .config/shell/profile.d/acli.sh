# Atlassian CLI

# if acli command is installed and available in the PATH, then enable autocompletion for zsh
#  eval "$(acli completion zsh)"
if command -v acli &> /dev/null; then
  eval "$(acli completion zsh)"
fi

