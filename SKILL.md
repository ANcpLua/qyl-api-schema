# qyl-api-schema: release and pins

One agent per qyl-dev repo (qyl, qyl.mcp, qyl-api-schema, Qyl.Telemetry.AutoInstrumentation, Qyl.Telemetry.SemanticConventions, qyl.at), each on its own `main`; agent, user and owner are one word. No PR and no publishing workflow; CI only reports: releases run on this machine with the keys in Vitals (`vitals keys`). bun is the package manager; npm only runs `npm version`, `npm pack` and `npm publish`.

## This repository

- Publishes `@ancplua/qyl-api-schema` (npm) and `Qyl.Api.Contracts` (NuGet) at one version from one commit.
- Version source: the tag, plus a `## <x.y.z>` entry at the top of `CHANGELOG.md` (release.sh refuses without it and uses it as the GitHub release notes). `package.json` stays `0.0.0-development` on `main`; never commit a version bump (`./release.sh` sets and restores it; its header says the rest).
- Keys: Vitals entries "qyl-api-schema and qyl.mcp manual publish and release (npm)" (`~/.config/vitals/npm-qyl-manual-publish-token`) and "qyl-dev manual publish and release (NuGet)" (`~/.config/vitals/nuget-qyl-manual-publish-key`), read by the script. Never print, paste, commit or log a key. Entry missing, note expired, "npm token rejected" or an npm one-time-password prompt: stop and tell the owner.
- Upstream pins: none from the qyl-dev repos.

## Stale-version guard, before any work

1. `git pull --ff-only origin main`, `mise install`, `bun install --frozen-lockfile`.
2. `npm view @ancplua/qyl-api-schema version` and the last entry of `curl -fsSL https://api.nuget.org/v3-flatcontainer/qyl.api.contracts/index.json` agree; the next release is one above both. Never reuse a version that exists on either registry.

## Release

1. `mise run check` green on `main`.
2. `./release.sh <x.y.z>` (`--dry-run` first only when a step is new or unsure; the script refuses before publishing when anything is off). A dry run pushes nothing: it proves the NuGet key for Qyl.Api.Contracts through NuGet's package-verification handshake (a one-use key minted and verified against the latest published version, three attempts) and runs `npm publish --dry-run` (npm refuses it for a version it already holds, so it is skipped there); an existing tag or published version only warns. The real run returns before indexing, once both registries accepted the push and the tag and GitHub release exist; a detached job runs `./build.sh VerifyRelease --published-version <x.y.z>` (index wait, registry consumers) and then the snapshot refresh (`published-versions.yaml` in qyl.at), logging to `artifacts/release-<x.y.z>-verify.log`. Do not run the snapshot refresh by hand.
3. `./release.sh --wait <x.y.z>` blocks until that log ends in VERIFIED or FAILED; nothing else about this release until then. A subagent never runs it: it stops after step 2 and reports, and the main session runs `--wait` in a background shell (a subagent's prompt cache lives 5 minutes, so a blocking wait re-reads its whole context cold). Exit 3 = not indexed in time, `./release.sh --verify <x.y.z>` checks again; any other FAILED after publication is a patch release.
4. VERIFIED: notify the consumers, qyl before qyl.mcp.

## Notify

| Consumer | Re-pins |
|---|---|
| qyl | `Version.props` `QylApiContractsVersion`, `services/qyl.dashboard/package.json`, its `bun.lock`, the README package table |
| qyl.mcp | `server/`, `workbench/`, `dashboard/` `package.json`, root `bun.lock` |
| qyl.at | `src/data/site.ts` |

One message per consumer through the session's agent-messaging tool (Claude Code: `ListAgents`, then `SendMessage`):

```
RELEASE @ancplua/qyl-api-schema + Qyl.Api.Contracts <version> indexed <UTC time>
repo: <qyl | qyl.mcp | qyl.at>
re-pin: <exact files from the table>
then: regenerate the lockfile, run the gate, commit, push main
order: qyl first; qyl.mcp after https://api.qyl.at/health serves the new revision
```

## Order rules

- A contract-revision change deploys qyl (the Collector) first; qyl.mcp only after `https://api.qyl.at/health` serves the new revision. Deployment state: `railway deployment list --json` in the qyl clone (service `qyl-collector`, environment `production`): the newest entry shows `status: SUCCESS` and `meta.commitHash` = the pushed commit.
- One release per repo per wave, only when shipped content changed.
- A Renovate or TypeSpec dependency move: re-pin `package.json`, `bun install` (not frozen), `mise run check`, commit, push `main`.
