#!/bin/bash
# .NET SDK configuration

if command -v dotnet >/dev/null 2>&1; then
    export DOTNET_ROOT=$(dirname $(which dotnet))
    export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true
    export DOTNET_CLI_TELEMETRY_OPTOUT=false
fi
