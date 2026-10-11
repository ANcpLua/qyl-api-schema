# Contributing to qyl-api-schema

The consumer-facing overview is the [README](README.md); this file is the working side.

## Develop

Development and CI use Node.js 24 LTS, with Bun as the package manager; `mise.toml`
pins both. The three emitters under `emitters/` are workspace members, not `file:`
dependencies: bun copies a `file:` dependency before `prepare` builds it, which leaves
TypeSpec resolving a library with no `dist/`. Published npm artifacts support
maintained Node.js releases from 22 onward.

```bash
bun install --frozen-lockfile
bun run lint
bun run lint:public
bun run compile
./build.sh Check
```

`bun run compile` writes everything under `generated/`. Only the OpenAPI document is
tracked; the rest is gitignored, rebuilt by `compile` and by `prepack`, and packed from
there:

- `generated/openapi/qyl.openapi.json` — tracked; `VerifyGeneratedArtifactsCurrent`
  fails when it lags the `.tsp` sources. Its `info.version` is TypeSpec's `0.0.0`:
  `prepack` stamps the package version into the packed copy
  (`scripts/stamp-openapi-version.mjs`) and `postpack` puts `0.0.0` back, so a local
  pack leaves no diff
- `generated/json-schema/qyl-api-schema.json` — the `./json-schema` export, projected
  from the OpenAPI document
- `generated/contracts/**/*.cs` — the `Qyl.Api.Contracts` NuGet, including
  `Qyl/Api/ContractRevision.cs` from `scripts/emit-contract-revision.mjs`
- `generated/ts-types/**` — the TypeScript emitter's `api.ts` (with the
  `CONTRACT_REVISION` block appended by the same script), `runtime.ts` and `schemas.ts`
- `generated/ts-runtime/**` — the `./types` export: `generated/ts-types` compiled to
  `.js` + `.d.ts` by `tsconfig.contracts.json`
- `generated/zod-runtime/**` — the `./zod` export: `src/zod/` compiled by
  `tsconfig.zod.json`
- `generated/runtime/**` — the `./runtime` export: `src/runtime/` compiled by
  `tsconfig.runtime.json`

Two pull-request gates run: `ci.yml` is the fast bun-only pass (lint both TypeSpec
surfaces, `compile`, `lint:js`), and `fallout.yml` is the full `./build.sh Check`
(adds the generated-current, route, fixture, Zod-parity, lint-rule and determinism
invariants and installs the packed npm and NuGet artifacts into clean consumers), so
a contract break is named within minutes while the release path is still proven on
every PR.

Generated files are not editing surfaces. OpenAPI comes from the official TypeSpec
emitter; the bundled JSON Schema is a deterministic projection of its component
schemas and exposes inline route bodies as stable
`Operations.<operationId>.Request` and
`Operations.<operationId>.Response.<status>` definitions. Both artifacts preserve
the same wire names. Change TypeSpec or the owning generator and regenerate.

## Publish

npm remains only for `npm version`, `npm pack` and `npm publish`. Install, lint, emit and every
verify target run on bun.

A release is published from your machine by `./release.sh <x.y.z>`: it sets the one version for npm and
NuGet in the working tree, runs the Fallout pack targets, publishes with `npm publish` (scope override to
npmjs.org, `--provenance=false`) and `dotnet nuget push` using the npm token and the NuGet API key
registered in Vitals (never in the repository), then tags `v<x.y.z>` and creates the GitHub release.
`./release.sh <x.y.z> --dry-run` rehearses every step without publishing. The tag is the only version
source; package.json stays at `0.0.0-development` on `main`.
