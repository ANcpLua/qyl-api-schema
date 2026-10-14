#!/usr/bin/env bash
# Publish and release @ancplua/qyl-api-schema (npm) and Qyl.Api.Contracts (NuGet)
# from this machine with the registry keys registered in Vitals. No workflow publishes.
#
#   ./release.sh <x.y.z>            pack, publish both packages, tag v<x.y.z>, GitHub release; returns
#                                   once both registries accepted the push and the tag and the GitHub
#                                   release exist, and leaves the verification below running detached
#   ./release.sh <x.y.z> --dry-run  every check, the real pack at <x.y.z>, `npm publish --dry-run`
#                                   and a NuGet key probe; registries and git stay unchanged; prints
#                                   what the detached job would do
#   ./release.sh --wait <x.y.z>     blocks until artifacts/release-<x.y.z>-verify.log ends in VERIFIED
#                                   (exit 0) or FAILED (exit 1; exit 3 when not indexed in time),
#                                   printing the log as it grows
#   ./release.sh --verify <x.y.z>   starts the detached verification again for a released version
#
# The detached verification (own session, survives the caller's shell) runs
# `./build.sh VerifyRelease --published-version <x.y.z>` (waits until npm and nuget.org serve the
# version, up to 45 min, then installs both registry packages into the consumer probes), then
# qyl.at's scripts/refresh-published-versions.sh, and ends its log with VERIFIED or FAILED.
# Registry versions are immutable: a failed consumer after the fact is a patch release, and the
# log says so.
#
# The tag is the only version source: package.json stays at 0.0.0-development on main.
# `npm version` sets <x.y.z> in the working tree for the pack and is restored on exit.
set -euo pipefail
cd "$(dirname "$0")"

NPM_PKG=@ancplua/qyl-api-schema
NUGET_PKG=Qyl.Api.Contracts
NPM_REGISTRY=https://registry.npmjs.org
NUGET_SOURCE=https://api.nuget.org/v3/index.json
NUGET_FLAT=https://api.nuget.org/v3-flatcontainer/qyl.api.contracts
NPM_TOKEN_FILE=$HOME/.config/vitals/npm-qyl-manual-publish-token          # vitals keys: "... manual publish and release (npm)"
NUGET_KEY_FILE=$HOME/.config/vitals/nuget-qyl-manual-publish-key  # vitals keys: "qyl-dev manual publish and release (NuGet)"
RELEASE_NAME="$NPM_PKG + $NUGET_PKG"
VERIFY_COMMAND="./build.sh VerifyRelease"
VERIFY_WHAT="npm and nuget.org index up to 45 min, then both registry packages in the consumer probes"
QYL_AT_DIR=${QYL_AT_DIR:-$(cd .. && pwd)/qyl.at}

mode=release
case ${1:-} in --wait | --verify | __verify) mode=${1#--}; shift ;; esac
version=${1:-}
dry=0; [[ $mode == release && ${2:-} == --dry-run ]] && dry=1
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "usage: $0 <x.y.z> [--dry-run] | --wait <x.y.z> | --verify <x.y.z>" >&2; exit 2; }
say() { printf '\n== %s\n' "$*"; }
die() { echo "release: $*" >&2; exit 1; }
utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }
verify_log="$PWD/artifacts/release-$version-verify.log"
index_status="$PWD/artifacts/release-$version-index.status"  # "waiting|indexed|timed-out elapsed=<s>s at=<utc>"
verify_pid() { sed -n '1s/.* pid \([0-9][0-9]*\) .*/\1/p' "$verify_log"; }
index_state() { [[ -f $index_status ]] && cut -d' ' -f1 "$index_status"; }
index_elapsed() { sed -n 's/.* elapsed=\([^ ]*\) .*/\1/p' "$index_status" 2>/dev/null; }

# The detached job: VerifyRelease (index wait, then the registry consumers), then the snapshot
# refresh. Its first log line names its pid, its last line is the verdict; exit 3 = not indexed in time.
verify_published() {
  local step="start" next_patch="${version%.*}.$(( ${version##*.} + 1 ))"
  printf 'verify %s %s pid %s started %s\n' "$RELEASE_NAME" "$version" "$$" "$(utc)"
  trap 'rc=$?; (( rc == 0 )) || printf "FAILED %s %s %s: %s stopped (exit %s); fix the cause, then ./release.sh --verify %s\n" "$RELEASE_NAME" "$version" "$(utc)" "$step" "$rc" "$version"' EXIT
  fail() { local code=$1; shift; printf 'FAILED %s %s %s: %s\n' "$RELEASE_NAME" "$version" "$(utc)" "$*"; trap - EXIT; exit "$code"; }
  rm -f "$index_status"

  step="VerifyRelease"
  say "$VERIFY_COMMAND --published-version $version ($VERIFY_WHAT)"
  if ! $VERIFY_COMMAND --published-version "$version"; then
    [[ $(index_state) == timed-out ]] &&
      fail 3 "not indexed after $(index_elapsed); nothing is wrong with the release yet: ./release.sh --verify $version checks again"
    fail 1 "a published package failed VerifyRelease (above; full log under artifacts/logs/); $version is immutable: fix the cause and ship $next_patch as a patch release (a transient network failure: ./release.sh --verify $version)"
  fi

  step="snapshot refresh"
  [[ $(index_state) == indexed ]] || fail 1 "VerifyRelease passed but $index_status does not say indexed; the snapshot stays as it is"
  say "refresh the published-versions snapshot in qyl.at"
  "$QYL_AT_DIR/scripts/refresh-published-versions.sh" ||
    fail 1 "$version is published and verified, but the snapshot refresh failed (above); ./release.sh --verify $version retries it"

  trap - EXIT
  printf 'VERIFIED %s %s %s: indexed after %s, registry consumers passed, snapshot refreshed\n' "$RELEASE_NAME" "$version" "$(utc)" "$(index_elapsed)"
}

# nohup plus a new session (python3's setsid; macOS has no setsid command): neither the end of the
# caller's shell nor a signal to its process group reaches the job. It needs no registry credential.
start_verification() {
  local pid
  mkdir -p artifacts
  if [[ -f $verify_log ]] && ! tail -n 1 "$verify_log" | grep -Eq '^(VERIFIED|FAILED) '; then
    pid=$(verify_pid)
    [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null && die "the verification of $version is still running (pid $pid): ./release.sh --wait $version"
  fi
  : >"$verify_log"
  env -u NPM_CONFIG_USERCONFIG -u NPM_CONFIG_TOKEN nohup python3 -I -c 'import os, sys; os.setsid(); os.execv(sys.argv[1], sys.argv[1:])' \
    "$PWD/release.sh" __verify "$version" </dev/null >>"$verify_log" 2>&1 &
  disown
  # Return only once the job has logged its pid, so a --wait right after this finds it.
  for _ in $(seq 1 50); do [[ -n $(verify_pid) ]] && break; sleep 0.2; done
  [[ -n $(verify_pid) ]] || die "the detached verification did not start; read $verify_log"
  say "verification runs detached (pid $!)"
  echo "log:  $verify_log"
  echo "wait: ./release.sh --wait $version   (or: tail -f $verify_log)"
}

wait_for_verification() {
  local printed=0 lines pid alive
  [[ -f $verify_log ]] || die "no verification log for $version at $verify_log; ./release.sh --verify $version starts one"
  while :; do
    pid=$(verify_pid); alive=0
    [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null && alive=1
    lines=$(wc -l <"$verify_log" | tr -d ' ')
    (( lines > printed )) && { sed -n "$((printed + 1)),${lines}p" "$verify_log"; printed=$lines; }
    case $(tail -n 1 "$verify_log") in
      VERIFIED\ *) return 0 ;;
      FAILED\ *) [[ $(index_state) == timed-out ]] && return 3; return 1 ;;
    esac
    (( alive )) || die "the verification job (pid ${pid:-unknown}) ended without VERIFIED or FAILED; read $verify_log, then ./release.sh --verify $version"
    sleep 5
  done
}

case $mode in
  __verify) verify_published; exit 0 ;;
  wait) wait_for_verification; exit ;;
  verify)
    [[ -n $(git ls-remote --tags origin "refs/tags/v$version") ]] || die "tag v$version is not on origin; release it first"
    gh release view "v$version" >/dev/null 2>&1 || die "GitHub release v$version does not exist; release it first"
    start_verification
    exit 0 ;;
esac

say "checks"
[[ -r $NPM_TOKEN_FILE ]]  || die "npm token missing: $NPM_TOKEN_FILE (vitals keys)"
[[ -r $NUGET_KEY_FILE ]]  || die "NuGet key missing: $NUGET_KEY_FILE (vitals keys)"
[[ $(git branch --show-current) == main ]] || die "not on main"
[[ -z $(git status --porcelain --untracked-files=no) ]] || die "working tree not clean"
git fetch -q origin main
[[ $(git rev-parse HEAD) == $(git rev-parse origin/main) ]] || die "main differs from origin/main"
[[ -z $(git ls-remote --tags origin "refs/tags/v$version") ]] || die "tag v$version already on origin"
git rev-parse -q --verify "refs/tags/v$version" >/dev/null && die "tag v$version already exists locally"
[[ -z $(npm view "$NPM_PKG@$version" version --registry="$NPM_REGISTRY" "--@ancplua:registry=$NPM_REGISTRY" 2>/dev/null) ]] || die "$NPM_PKG@$version is already on npm"
curl -fsSL "$NUGET_FLAT/index.json" | grep -q "\"$version\"" && die "$NUGET_PKG $version is already on NuGet"
gh auth status >/dev/null 2>&1 || die "gh is not logged in"
if ! grep -q "^## $version" CHANGELOG.md; then
  (( dry )) || die "CHANGELOG.md has no '## $version' entry at the top"
  echo "warning: CHANGELOG.md has no '## $version' entry yet; the real run refuses without it"
fi

# npm auth through a private userconfig so the token never reaches a command line.
npmrc=$(mktemp); chmod 600 "$npmrc"
probe_dir=$(mktemp -d)
trap 'rm -rf "$npmrc" "$probe_dir"' EXIT
printf '//registry.npmjs.org/:_authToken=%s\n' "$(<"$NPM_TOKEN_FILE")" >"$npmrc"
export NPM_CONFIG_USERCONFIG=$npmrc
who=$(npm whoami --registry="$NPM_REGISTRY") || die "npm token rejected (vitals keys)"
echo "npm token belongs to: $who"

say "version $version (working tree only, restored on exit)"
trap 'git checkout -q -- package.json; rm -rf "$npmrc" "$probe_dir"' EXIT
npm version "$version" --no-git-tag-version >/dev/null

say "pack (Fallout)"
./build.sh PackApiPackage
./build.sh PackContractsNuget
tgz=ancplua-qyl-api-schema-$version.tgz
nupkg=Artifacts/nuget/$NUGET_PKG.$version.nupkg
[[ -f $tgz ]]   || die "npm tarball not found: $tgz"
[[ -f $nupkg ]] || die "nupkg not found: $nupkg"
nuspec_version=$(unzip -p "$nupkg" '*.nuspec' | sed -n 's:.*<version>\([^<]*\)</version>.*:\1:p' | head -1)
[[ $nuspec_version == "$version" ]] || die "$nupkg carries version '$nuspec_version', not $version"

say "npm publish"
# .npmrc maps @ancplua to GitHub Packages for dependencies; the scope override sends this
# publish to npmjs.org. --provenance=false: publishConfig asks for provenance, which only
# CI OIDC can supply.
npm publish "./$tgz" --registry="$NPM_REGISTRY" "--@ancplua:registry=$NPM_REGISTRY" \
  --provenance=false --access public $( (( dry )) && echo --dry-run )

say "NuGet push"
if (( dry )); then
  latest=$(curl -fsSL "$NUGET_FLAT/index.json" | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["versions"][-1])')
  curl -fsSL -o "$probe_dir/probe.nupkg" "$NUGET_FLAT/$latest/qyl.api.contracts.$latest.nupkg"
  echo "dry run: pushing the published $latest again with --skip-duplicate to prove the key (expect 'already exists')"
  dotnet nuget push "$probe_dir/probe.nupkg" --api-key "$(<"$NUGET_KEY_FILE")" --source "$NUGET_SOURCE" --skip-duplicate
else
  # --skip-duplicate: a rerun after a partial failure (pushed, not indexed yet) goes on.
  dotnet nuget push "$nupkg" --api-key "$(<"$NUGET_KEY_FILE")" --source "$NUGET_SOURCE" --skip-duplicate
fi

if (( dry )); then
  rm -f "$tgz"
  git checkout -q -- package.json
  say "dry run finished: nothing published, nothing tagged"
  git status --short --untracked-files=no
  echo "The real run then starts the detached verification ($verify_log, ./release.sh --wait $version):"
  echo "  $VERIFY_COMMAND --published-version $version ($VERIFY_WHAT),"
  echo "  then $QYL_AT_DIR/scripts/refresh-published-versions.sh; the log ends with VERIFIED or FAILED."
  exit 0
fi

say "tag and GitHub release"
git checkout -q -- package.json
git tag -a "v$version" -m "v$version"
git push -q origin "v$version"
notes=$(mktemp); awk -v v="$version" 'index($0, "## " v) == 1 {on=1; next} on && /^## / {exit} on' CHANGELOG.md >"$notes"
if gh release view "v$version" >/dev/null 2>&1; then
  gh release upload "v$version" "./$tgz" "$nupkg" --clobber
else
  gh release create "v$version" --title "v$version" --notes-file "$notes" "./$tgz" "$nupkg"
fi
rm -f "$notes"
rm -f "$tgz"

start_verification
say "next (SKILL.md): ./release.sh --wait $version, then notify the consumers"
echo "re-pin $NPM_PKG $version in qyl (Collector) first, wait for its Railway deployment and api.qyl.at to serve the new revision, then in qyl.mcp."
