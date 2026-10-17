# qyl-api-schema: release and pins

Use the existing clone on `main`, with one writer. Do not create an agent, branch, worktree or PR unless requested. Current owner instructions and verified source take precedence over historical plans. CI reports; use the repository’s actual release script and existing Vitals credentials. bun is the package manager; npm only runs `npm version`, `npm pack` and `npm publish`.

## This repository

- Publishes `@ancplua/qyl-api-schema` (npm) and `Qyl.Api.Contracts` (NuGet) at one version from one commit.
- Version source: the tag, plus a `## <x.y.z>` entry at the top of `CHANGELOG.md` (release.sh refuses without it and uses it as the GitHub release notes). `package.json` stays `0.0.0-development` on `main`; never commit a version bump (`./release.sh` sets and restores it; its header says the rest).
- Keys: Vitals entries "qyl-api-schema and qyl.mcp manual publish and release (npm)" (`~/.config/vitals/npm-qyl-manual-publish-token`) and "qyl-dev manual publish and release (NuGet)" (`~/.config/vitals/nuget-qyl-manual-publish-key`), read by the script. Never print, paste, commit or log a key. Entry missing, note expired, "npm token rejected" or an npm one-time-password prompt: stop and tell the owner.
- Upstream pins: none from the qyl-dev repos.

## Refresh changed inputs

1. Pull when the tree is clean and no other writer owns it. Install missing tools and restore changed lockfile/package inputs.
2. `npm view @ancplua/qyl-api-schema version --registry=https://registry.npmjs.org --@ancplua:registry=https://registry.npmjs.org` and the last entry of `curl -fsSL https://api.nuget.org/v3-flatcontainer/qyl.api.contracts/index.json` agree. Override the scoped registry as well: a global `@ancplua:registry` can otherwise redirect the probe to GitHub Packages. Choose the next version for the change, including a new major for breaking contracts. Never reuse a version that exists on either registry.

## Release

1. The changed contracts and consumers are verified on `main`; reuse valid results and keep the native release checks.
2. `./release.sh <x.y.z>` (`--dry-run` first only when a step is new or unsure; the script refuses before publishing when anything is off). A dry run pushes nothing: it proves the NuGet key for Qyl.Api.Contracts through NuGet's package-verification handshake (a one-use key minted and verified against the latest published version, three attempts) and runs `npm publish --dry-run` (npm refuses it for a version it already holds, so it is skipped there); an existing tag or published version only warns. The real run returns before indexing, once both registries accepted the push and the tag and GitHub release exist; a detached job runs `./build.sh VerifyRelease --published-version <x.y.z>` (index wait, registry consumers) and then the snapshot refresh (`published-versions.yaml` in qyl.at), logging to `artifacts/release-<x.y.z>-verify.log`. Do not run the snapshot refresh by hand.
3. `./release.sh --wait <x.y.z>` follows that job until its log ends in VERIFIED or FAILED. One job owns the attempt. Continue independent work while it waits; do not restart a healthy job after a fixed interval or duplicate its registry polling. Exit 3 = not indexed in time, `./release.sh --verify <x.y.z>` checks again; any other FAILED after publication is a patch release.
4. VERIFIED: notify the consumers, qyl before qyl.mcp.

## Consumers

| Consumer | Re-pins |
|---|---|
| qyl | `Version.props` `QylApiContractsVersion`, `services/qyl.dashboard/package.json`, its `bun.lock`, the README package table |
| qyl.mcp | `server/`, `workbench/`, `dashboard/` `package.json`, root `bun.lock` |
| qyl.at | `src/data/site.ts` |

After VERIFIED, update authorized consumers in their existing clones, keeping package identity and deployment order intact. Coordinate with an existing writer when necessary; do not create an agent merely to notify a consumer.

## Order rules

- A contract-revision change deploys qyl (the Collector) first; qyl.mcp only after `https://api.qyl.at/health` serves the new revision. Deployment state: `railway deployment list --json` in the qyl clone (service `qyl-collector`, environment `production`): the newest entry shows `status: SUCCESS` and `meta.commitHash` = the pushed commit.
- One release per repo per wave, only when shipped content changed.
- A Renovate or TypeSpec dependency move: re-pin `package.json`, `bun install` (not frozen), affected contract/consumer checks, commit, push `main`.
