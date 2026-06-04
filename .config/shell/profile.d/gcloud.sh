#!/bin/bash
# gcloud: point CLOUDSDK_HOME at the Homebrew SDK so OMZP::gcloud sources its
# completion.zsh.inc. The plugin's built-in search list omits the linuxbrew
# prefix, and Homebrew's site-functions symlink has no #compdef tag, so without
# this neither completion path fires. Loaded after 01-homebrew.sh (glob order),
# so HOMEBREW_PREFIX is set; runs before the deferred OMZP::gcloud plugin.
if [[ -n "$HOMEBREW_PREFIX" && -d "$HOMEBREW_PREFIX/share/google-cloud-sdk" ]]; then
    export CLOUDSDK_HOME="$HOMEBREW_PREFIX/share/google-cloud-sdk"
fi
