#!/usr/bin/env bash
set -euo pipefail

# Standard Fallout bootstrap. Invokes the local build host (build/_build.csproj).
# All arguments are forwarded to the build host.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Quiet unless --verbose or QYL_VERBOSE=1: scripts/quiet.sh prints the target table, PASS or FAIL
# and the failing target's last lines, and keeps the whole output in
# artifacts/logs/build-<targets>.log. --help prints as before.
verbose=${QYL_VERBOSE:-0}
arguments=()
name=build
for argument in "$@"; do
    case $argument in
        --verbose) verbose=1; continue ;;
        --help | -h) verbose=1 ;;
        -*) parameters=1 ;;
        *) [[ -n ${parameters:-} ]] || name+="-$argument" ;;
    esac
    arguments+=("$argument")
done
if [[ $verbose != 1 ]]; then
    exec "$SCRIPT_DIR/scripts/quiet.sh" "${name//[^A-Za-z0-9._-]/_}" -- "$SCRIPT_DIR/build.sh" ${arguments[@]+"${arguments[@]}"}
fi
set -- ${arguments[@]+"${arguments[@]}"}

dotnet build ./build/_build.csproj -maxcpucount:4 -nodeReuse:false -p:UseSharedCompilation=false
dotnet run --no-build --project ./build/_build.csproj -- "$@"
