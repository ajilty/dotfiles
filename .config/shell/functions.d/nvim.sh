#!/bin/bash
# nvim: Neovim helpers
#
# Functions:
#   cheat - Open the VSCode-to-nvim cheatsheet (same as :Cheat inside nvim)

cheat ()
{
    nvim "$HOME/.config/nvim/CHEATSHEET.md"
}
