# qyl-api-schema: release and pins

Who reads this: the one agent working on this repository's `main`. Agent, user and owner are
the same word. There is one agent per repository, six in all (qyl, qyl.mcp, qyl-api-schema,
Qyl.Telemetry.AutoInstrumentation, Qyl.Telemetry.SemanticConventions, qyl.at), each on its own
`main`. Commit and push to `main` directly: no pull requests, no CI, no branch rules. Builds,
emits, verifies and packs run through Fallout (`./build.sh <Target>`, gate `./build.sh Check`);
bun is the package manager (`bun.lock`); npm is used only for `npm version`, `npm pack` and
`npm publish`.

## This repository

- Publishes `@ancplua/qyl-api-schema` to npm and `Qyl.Api.Contracts` to NuGet, one version for
  both, from the same commit.
- Version source: the tag. `package.json` stays at `0.0.0-development` on `main`; the release
  command sets `<x.y.z>` in the working tree for the pack and restores it. Do not commit a
  version bump.
- Release command: `./release.sh <x.y.z> --dry-run`, then `./release.sh <x.y.z>` (Fallout
  `PackApiPackage` and `PackContractsNuget`, `npm publish` to npmjs.org with the `@ancplua`
  scope override and `--provenance=false`, `dotnet nuget push`, tag, GitHub release with both
  artifacts, wait for both indexes).
- Keys: `vitals keys` entries "qyl-api-schema and qyl.mcp manual publish and release (npm)"
  (`~/.config/vitals/npm-qyl-manual-publish-token`) and "qyl-dev manual publish and release
  (NuGet)" (`~/.config/vitals/nuget-qyl-manual-publish-key`). The script reads them; never
  print, paste, commit or log a key. If an entry is missing, its note's expiry has passed, or
  the script says "npm token rejected" or npm asks for a one-time password, stop and tell the
  owner.
- Upstream pins: none from the qyl-dev repos. This repo is the contract source; it must not
  take a telemetry dependency.
- Consumers to notify after both packages are indexed, in this order: qyl (`Version.props`
  `QylApiContractsVersion`, `services/qyl.dashboard/package.json`, its `bun.lock`, the README
  package table), then qyl.mcp (`server/`, `workbench/` and `dashboard/` `package.json`, root
  `bun.lock`), and qyl.at (`src/data/site.ts`).

## Before any work: the stale-version guard

1. `git pull --ff-only origin main`.
2. `mise install`, then `bun install --frozen-lockfile`.
3. Check what is published: `npm view @ancplua/qyl-api-schema version` and
   `curl -fsSL https://api.nuget.org/v3-flatcontainer/qyl.api.contracts/index.json` (last
   entry) must agree; the next release is one version above both. Never reuse a version that
   exists on either registry.

## Releasing

1. `./build.sh Check` is green on `main`.
2. `./release.sh <x.y.z> --dry-run` only when a step is new or unsure; otherwise go straight to
   the release, the script refuses before it publishes when anything is off.
3. `./release.sh <x.y.z>`.
4. Watch indexing: the script prints the npm version and polls the NuGet index. If it ends with
   "not indexed yet", keep polling every 30 s. Until both are indexed, do nothing else about
   this release.
5. The moment both are indexed: stop watching and notify the consumers (section "Notify"),
   qyl before qyl.mcp.
6. Run
   `/Users/alexandernachtmann/Downloads/qyl-codex-claude/refresh-published-versions.sh`, which rewrites
   `qyl-published-versions.yaml` beside it from the registries (the snapshot every agent reads first).

## Notify

One message per consumer repo, to its running agent through the session's agent-messaging
tool when there is one (Claude Code: `ListAgents`, then `SendMessage`). Text:

```
RELEASE @ancplua/qyl-api-schema + Qyl.Api.Contracts <version> indexed <UTC time>
repo: <qyl | qyl.mcp | qyl.at>
re-pin: <exact files from the consumer list>
then: regenerate the lockfile, run the gate, commit, push main
order: qyl first; qyl.mcp after https://api.qyl.at/health serves the new revision
```

## When a release lands and you are the consumer

This repo consumes no qyl-dev package. If a Renovate or TypeSpec dependency moved, re-pin in
`package.json`, run `bun install` (not frozen), `./build.sh Check`, commit, push `main`.

## Order rules that never change

- A release that changes the contract revision deploys in order: qyl (Collector) first, wait
  until `https://api.qyl.at/health` serves the new revision, then qyl.mcp. Deployment state:
  `railway deployment list --json` in the qyl clone (linked to service `qyl-collector`,
  environment `production`); the newest entry must show `status: SUCCESS` and
  `meta.commitHash` equal to the pushed commit.
- One release per repo per wave, only when shipped content changed.
- qyl.at lists a version only after the index confirms it.
