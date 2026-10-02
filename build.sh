#!/usr/bin/env bash
set -euo pipefail

# Standard Fallout bootstrap. Invokes the local build host (build/_build.csproj).
# All arguments are forwarded to the build host.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

dotnet run --project ./build/_build.csproj -- "$@"
