#!/usr/bin/env bash
set -euo pipefail

# Standard Fallout bootstrap. Invokes the local build host (build/_build.csproj).
# All arguments are forwarded to the build host.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

dotnet build ./build/_build.csproj -maxcpucount:4 -nodeReuse:false -p:UseSharedCompilation=false
dotnet run --no-build --project ./build/_build.csproj -- "$@"
