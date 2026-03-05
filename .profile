#######################################################
# SHELL
#######################################################

# Source common shell configurations
for config_file in ~/.config/shell/{aliases,profile,functions}; do
    [ -f "$config_file" ] && source "$config_file"
done