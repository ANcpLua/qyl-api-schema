# qyl-api-schema

Release, re-pin and agent hand-offs: follow [`SKILL.md`](SKILL.md) at this repo root (canonical clone `/Users/alexandernachtmann/RiderProjects/qyl-api-schema/SKILL.md`); the one command is `./release.sh`. Published versions: `/Users/alexandernachtmann/Downloads/qyl-codex-claude/qyl-published-versions.yaml`.

## Publishing across the qyl-dev repos

Push to `main` directly; no pull request, review, approval or CI exists. The only gate is the repo's local command named in SKILL.md, run before the push.

A release is done from the developer's machine with the registry API keys registered in Vitals (`vitals keys`): bump the version source, pack, push the packages to the registry, then tag `v<version>` on the released commit and create the GitHub release. No workflow publishes. `./release.sh <x.y.z>` does all of it in one command (npm with the scope override to npmjs.org and `--provenance=false`, NuGet, tag, GitHub release with both artifacts attached); `./release.sh <x.y.z> --dry-run` rehearses it against the live registries without publishing.

| Repo | Version source | Publishes |
|---|---|---|
| qyl-api-schema | `package.json` via `npm version` (one version for npm and NuGet) | `@ancplua/qyl-api-schema` (npm), `Qyl.Api.Contracts` (NuGet) |
| SemanticConventions | `Directory.Build.props` `VersionPrefix`, `registry/manifest.yaml` `schema_url` and a `CHANGELOG.md` entry; `scripts/generate.sh` must agree; `qyl.at/schemas/<version>` is served first | the three `Qyl.Telemetry.SemanticConventions*` packages (NuGet) |
| AutoInstrumentation | `Directory.Build.props` `Version` | the six `Qyl.Telemetry.*` packages (NuGet) |
| qyl | `Version.props` `QylVersion` | `qyl`, `qyl.<rid>` ×6, `Qyl.Api.Sdk` (NuGet) |
| qyl.mcp | `server/package.json` `version` plus a `server/README.md` release-notes entry | `qyl-mcp-server` (npm) |
| qyl.at | none | pushing `main` deploys `qyl.at` |

Downstream pins move in the change that consumes the publish: qyl-api-schema → qyl (`Version.props` `QylApiContractsVersion`, `services/qyl.dashboard/package.json`, `bun.lock`, the README table) → qyl.mcp (`server`, `workbench` and `dashboard` `package.json`, `bun.lock`); SemanticConventions → AutoInstrumentation (`Directory.Packages.props`, `SEMCONV_REF`) and qyl (`QylSemanticConventionsVersion`), with qyl.at serving `public/schemas/<version>`; AutoInstrumentation → qyl (`QylTelemetryVersion`); every producer → qyl.at `src/data/site.ts`. One production rule stays: when the contract revision changes, push the Collector (qyl `main`) first, wait until `api.qyl.at/health` serves the new revision, then push qyl.mcp; `mcp.qyl.at` refuses a Collector on another revision.

Pushing `main` also deploys: qyl → `qyl-collector` (`api.qyl.at`, Railway), qyl.mcp → `qyl-mcp` (`mcp.qyl.at`, Railway), qyl.at → the `qyl-at` Worker (`qyl.at`, Cloudflare).
