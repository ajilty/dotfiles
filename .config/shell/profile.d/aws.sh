#!/bin/bash
# AWS CLI configuration

export AWS_PAGER=""
if [ -f ~/.local/config/aws/config ]; then
    export AWS_CONFIG_FILE=~/.local/config/aws/config
else
    export AWS_CONFIG_FILE=~/.config/aws/config
fi
