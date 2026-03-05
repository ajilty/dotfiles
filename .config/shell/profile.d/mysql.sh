#!/bin/bash
# MySQL client configuration

if [[ -n "$HOMEBREW_PREFIX" && -d "$HOMEBREW_PREFIX/opt/mysql-client/bin" ]]; then
    export PATH="$HOMEBREW_PREFIX/opt/mysql-client/bin:$PATH"
    export LDFLAGS="-L$HOMEBREW_PREFIX/opt/mysql-client/lib"
    export CPPFLAGS="-I$HOMEBREW_PREFIX/opt/mysql-client/include"
    export PKG_CONFIG_PATH="$HOMEBREW_PREFIX/opt/mysql-client/lib/pkgconfig"
fi
