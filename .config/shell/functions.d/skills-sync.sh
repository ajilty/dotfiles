#!/bin/bash
# skills-sync: thin wrapper that sources the real implementation from
# ~/skills/skills-sync.sh — kept there so it lives next to the homegrown
# skills it manages. This wrapper is tracked in dotfiles for portability;
# the implementation is local to each machine's ~/skills/ workspace and
# must be (re)created during fresh-machine bootstrap.

[[ -f ~/skills/skills-sync.sh ]] && source ~/skills/skills-sync.sh
