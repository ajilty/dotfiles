#######################################################
# SHELL
#######################################################

# echo "file: .profile"

# Source common shell configurations
for config_file in ~/.config/shell/{aliases,environment,functions}; do
    [ -f "$config_file" ] && source "$config_file"
done