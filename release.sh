#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

NPM_PKG=@ancplua/qyl-api-schema
NUGET_PKG=Qyl.Api.Contracts
NPM_REGISTRY=https://registry.npmjs.org
NUGET_SOURCE=https://api.nuget.org/v3/index.json
NUGET_FLAT=https://api.nuget.org/v3-flatcontainer/qyl.api.contracts
NUGET_GALLERY=https://www.nuget.org/api/v2
NPM_TOKEN_FILE=$HOME/.config/vitals/npm-qyl-manual-publish-token          # vitals keys: "... manual publish and release (npm)"
NUGET_KEY_FILE=$HOME/.config/vitals/nuget-qyl-manual-publish-key  # vitals keys: "qyl-dev manual publish and release (NuGet)"
version=${1:-}
dry=0; [[ ${2:-} == --dry-run ]] && dry=1
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && $# -le 2 && ( $# -lt 2 || ${2:-} == --dry-run ) ]] || { echo "usage: $0 <x.y.z> [--dry-run]" >&2; exit 2; }
say() { printf '\n== %s\n' "$*"; }
die() { echo "release: $*" >&2; exit 1; }
# A check the real run enforces; a dry run reports it and goes on.
refuse() { (( dry )) || die "$*"; echo "warning: $*; the real run refuses"; }
# The key probe publishes nothing: it is NuGet's push-symbols handshake. The key mints a one-use
# package verification key for <id> <version> (only a live key with push scope can), and that key
# verifies with 200 only when the key's account owns <id>; the verify call consumes it. The key
# travels in a curl config on stdin, never on a command line.
key_probe() {
  local id=$1 version=$2 minted temp
  minted=$(printf 'header = "X-NuGet-ApiKey: %s"\n' "$(<"$NUGET_KEY_FILE")" |
    curl -fsS -X POST -H 'Content-Length: 0' -K - "$NUGET_GALLERY/package/create-verification-key/$id/$version") || return 1
  temp=$(sed -n 's/.*"Key":"\([^"]*\)".*/\1/p' <<<"$minted")
  [[ -n $temp ]] || return 1
  [[ $(printf 'header = "X-NuGet-ApiKey: %s"\n' "$temp" |
    curl -sS -o /dev/null -w '%{http_code}' -K - "$NUGET_GALLERY/verifykey/$id/$version") == 200 ]]
}

say "checks"
[[ -r $NPM_TOKEN_FILE ]]  || die "npm token missing: $NPM_TOKEN_FILE (vitals keys)"
[[ -r $NUGET_KEY_FILE ]]  || die "NuGet key missing: $NUGET_KEY_FILE (vitals keys)"
[[ $(git branch --show-current) == main ]] || die "not on main"
[[ -z $(git status --porcelain --untracked-files=no) ]] || die "working tree not clean"
git fetch -q origin main
[[ $(git rev-parse HEAD) == $(git rev-parse origin/main) ]] || die "main differs from origin/main"
release_commit=$(git rev-parse HEAD)  # the commit the checks and the pack run on; the tag names it
echo "release commit: $release_commit"
[[ -z $(git ls-remote --tags origin "refs/tags/v$version") ]] || refuse "tag v$version already on origin"
git rev-parse -q --verify "refs/tags/v$version" >/dev/null && refuse "tag v$version already exists locally"
npm_published=0
[[ -z $(npm view "$NPM_PKG@$version" version --registry="$NPM_REGISTRY" "--@ancplua:registry=$NPM_REGISTRY" 2>/dev/null) ]] ||
  { npm_published=1; refuse "$NPM_PKG@$version is already on npm"; }
curl -fsSL "$NUGET_FLAT/index.json" | grep -q "\"$version\"" && refuse "$NUGET_PKG $version is already on NuGet"
gh auth status >/dev/null 2>&1 || die "gh is not logged in"
grep -q "^## $version" CHANGELOG.md || refuse "CHANGELOG.md has no '## $version' entry at the top"

# npm auth through a private userconfig so the token never reaches a command line.
npmrc=$(mktemp); chmod 600 "$npmrc"
trap 'rm -f "$npmrc"' EXIT
printf '//registry.npmjs.org/:_authToken=%s\n' "$(<"$NPM_TOKEN_FILE")" >"$npmrc"
export NPM_CONFIG_USERCONFIG=$npmrc
who=$(npm whoami --registry="$NPM_REGISTRY") || die "npm token rejected (vitals keys)"
echo "npm token belongs to: $who"

say "version $version (working tree only, restored on exit)"
tgz=ancplua-qyl-api-schema-$version.tgz
trap 'git checkout -q -- package.json; rm -f "$npmrc" "$tgz"' EXIT
npm version "$version" --no-git-tag-version >/dev/null

say "pack"
bun install --frozen-lockfile
# npm's prepack generates both language contracts and its postpack restores the
# development OpenAPI version. The same generated C# sources feed the NuGet pack.
npm pack
[[ -n $(find generated/contracts -type f -name '*.cs' ! -path 'generated/contracts/Qyl/Api/ContractRevision.cs' -print -quit) ]] ||
  die "the emitter produced no C# contracts; refusing to pack an empty assembly"
dotnet pack packaging/Qyl.Api.Contracts.csproj --configuration Release --output artifacts/nuget -p:Version="$version"
nupkg=artifacts/nuget/$NUGET_PKG.$version.nupkg
[[ -f $tgz ]]   || die "npm tarball not found: $tgz"
[[ -f $nupkg ]] || die "nupkg not found: $nupkg"
nuspec_version=$(unzip -p "$nupkg" '*.nuspec' | sed -n 's:.*<version>\([^<]*\)</version>.*:\1:p' | head -1)
[[ $nuspec_version == "$version" ]] || die "$nupkg carries version '$nuspec_version', not $version"

say "npm publish"
# .npmrc maps @ancplua to GitHub Packages for dependencies; the scope override sends this
# publish to npmjs.org. --provenance=false: publishConfig asks for provenance, which only
# CI OIDC can supply.
if (( dry && npm_published )); then
  # npm's publish --dry-run refuses a published version; npm whoami above proved the token.
  echo "dry run: $NPM_PKG@$version is on npm already, so npm publish --dry-run is skipped"
else
  npm publish "./$tgz" --registry="$NPM_REGISTRY" "--@ancplua:registry=$NPM_REGISTRY" \
    --provenance=false --access public $( (( dry )) && echo --dry-run )
fi

say "NuGet push"
if (( dry )); then
  published=$(curl -fsSL "$NUGET_FLAT/index.json" 2>/dev/null | grep -o '"[0-9][^"]*"' | tail -1 | tr -d '"' || true)
  [[ -n $published ]] || die "cannot read the published versions of $NUGET_PKG from NuGet"
  # A rejected key fails every attempt; a dropped connection does not.
  probed=0
  for _ in 1 2 3; do key_probe "$NUGET_PKG" "$published" && { probed=1; break; }; sleep 3; done
  (( probed )) || die "the NuGet key failed the probe for $NUGET_PKG three times: expired, revoked, without push scope, or its account does not own $NUGET_PKG (vitals keys)"
  echo "key probe: $NUGET_PKG ok (verified against $published, nothing published)"
else
  # --skip-duplicate: a rerun after a partial failure (pushed, not indexed yet) goes on.
  NUGET_API_KEY="$(<"$NUGET_KEY_FILE")" dotnet nuget push "$nupkg" --source "$NUGET_SOURCE" --skip-duplicate
fi

if (( dry )); then
  git checkout -q -- package.json
  say "dry run finished: nothing published, nothing tagged"
  git status --short --untracked-files=no
  exit 0
fi

say "tag and GitHub release"
git checkout -q -- package.json
[[ $(git rev-parse HEAD) == "$release_commit" ]] ||
  echo "warning: HEAD moved to $(git rev-parse --short HEAD) during the release; v$version tags the packed $release_commit"
git tag -a "v$version" "$release_commit" -m "v$version"
git push -q origin "v$version"
notes=$(mktemp); git show "$release_commit:CHANGELOG.md" | awk -v v="$version" 'index($0, "## " v) == 1 {on=1; next} on && /^## / {exit} on' >"$notes"
if gh release view "v$version" >/dev/null 2>&1; then
  gh release upload "v$version" "./$tgz" "$nupkg" --clobber
else
  gh release create "v$version" --title "v$version" --notes-file "$notes" "./$tgz" "$nupkg"
fi
rm -f "$notes"

say "published $version: both registries accepted the packages; indexing and installed consumers have not been verified"
echo "re-pin $NPM_PKG $version in qyl (Collector) first, wait for its Railway deployment and api.qyl.at to serve the new revision, then in qyl.mcp."
