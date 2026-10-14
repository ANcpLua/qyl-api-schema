#!/usr/bin/env bash
# Publish and release @ancplua/qyl-api-schema (npm) and Qyl.Api.Contracts (NuGet)
# from this machine with the registry keys registered in Vitals. No workflow publishes.
#
#   ./release.sh <x.y.z>            pack, publish both packages, tag v<x.y.z>, GitHub release
#   ./release.sh <x.y.z> --dry-run  every check, the real pack at <x.y.z>, `npm publish --dry-run`
#                                   and a NuGet key probe; registries and git stay unchanged
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

version=${1:-}
dry=0; [[ ${2:-} == --dry-run ]] && dry=1
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "usage: $0 <x.y.z> [--dry-run]" >&2; exit 2; }
say() { printf '\n== %s\n' "$*"; }
die() { echo "release: $*" >&2; exit 1; }

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
grep -q "^## $version" CHANGELOG.md || die "CHANGELOG.md has no '## $version' entry at the top"

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
  dotnet nuget push "$nupkg" --api-key "$(<"$NUGET_KEY_FILE")" --source "$NUGET_SOURCE"
fi

if (( dry )); then
  rm -f "$tgz"
  git checkout -q -- package.json
  say "dry run finished: nothing published, nothing tagged"
  git status --short --untracked-files=no
  exit 0
fi

say "tag and GitHub release"
git checkout -q -- package.json
git tag -a "v$version" -m "v$version"
git push -q origin "v$version"
notes=$(mktemp); awk -v v="$version" 'index($0, "## " v) == 1 {on=1; next} on && /^## / {exit} on' CHANGELOG.md >"$notes"
gh release create "v$version" --title "v$version" --notes-file "$notes" "./$tgz" "$nupkg"; rm -f "$notes"
rm -f "$tgz"

say "verify"
echo "npm:   $(npm view "$NPM_PKG@$version" version --registry="$NPM_REGISTRY" "--@ancplua:registry=$NPM_REGISTRY")"
for _ in $(seq 1 20); do
  if curl -fsSL "$NUGET_FLAT/index.json" | grep -q "\"$version\""; then echo "nuget: $version indexed"; break; fi
  sleep 30
done
curl -fsSL "$NUGET_FLAT/index.json" | grep -q "\"$version\"" || echo "nuget: $version pushed, not indexed yet; check $NUGET_FLAT/index.json later"

say "next (SKILL.md): notify the consumers once both are indexed, then refresh the snapshot"
echo "re-pin $NPM_PKG $version in qyl (Collector) first, wait for its Railway deployment and api.qyl.at to serve the new revision, then in qyl.mcp."
