# `@o-ancpplua/otel-conventions-api`

TypeSpec library projecting OpenTelemetry semantic conventions into a reusable API surface for qyl. Distributed on **GitHub Packages** under the `@o-ancpplua` scope (matches the `O-ANcppLua` GitHub org). **Not an official OpenTelemetry artifact** — the upstream OpenTelemetry semantic-conventions YAML model remains the authority; this is a TypeSpec API projection under the ANcpLua namespace.

Extracted from <https://github.com/O-ANcppLua/qyl> after PR #255.

## How this repo relates to `typespec-otel-semconv`

Two repos, two scopes, one contract:

| Repo | Role | Package | Inputs | Outputs |
| --- | --- | --- | --- | --- |
| [`ANcpLua/typespec-otel-semconv`](https://github.com/ANcpLua/typespec-otel-semconv) | **Upstream OTel semconv generator** (Weaver-based, long-term OpenTelemetry contribution target — see [How to write semantic conventions](https://opentelemetry.io/docs/specs/semconv/general/how-to-write-conventions/)) | `@ancplua/typespec-otel-semconv` | OpenTelemetry semantic-conventions YAML model, pinned at `v1.41.0` | `lib/otel-keys.tsp` (TypeSpec projection of OTel keys) |
| **This repo** | **Downstream qyl API surface** (consumes the generator's output to define qyl's domain API contracts) | `@o-ancpplua/otel-conventions-api` | The generator's `otel-keys.tsp` (currently checked in as `generated/otel-keys.gen.tsp` until the lockstep flip) | C# / DuckDB / TS-types / lint emitter outputs via local `emitters/` |

```
┌─────────────────────────────┐                    ┌─────────────────────────────────┐
│ typespec-otel-semconv       │                    │ ANcpLua.OtelConventions.Api     │
│                             │                    │                                 │
│ Weaver + YAML @ v1.41.0     │ ── npm publish ──▶ │ npm ci → tsp compile domain     │
│   → lib/otel-keys.tsp       │  @ancplua/...      │   → emitters/{csharp,duckdb,…}  │
│   → @ancplua/...@1.41.0-N   │  @1.41.0-N         │   → @o-ancpplua/...@x.y.z       │
└─────────────────────────────┘                    └─────────────────────────────────┘
```

The split keeps the upstream contribution clean — `typespec-otel-semconv` could be donated, forked, or evolved on the official semconv release cadence without dragging qyl's domain models with it. Consumers who want only the OTel signal projection install `@ancplua/typespec-otel-semconv`; consumers who want the full qyl API surface install `@o-ancpplua/otel-conventions-api` (which depends on it transitively once the lockstep flip lands).

Direction is one-way: this repo never regenerates from YAML. Only the generator touches Weaver and the upstream model.

## Package identities

This repo publishes two lockstep artifacts from the same `package.json` version:

| Ecosystem | Package | Registry | Consumer |
| --- | --- | --- | --- |
| TypeSpec/npm | `@o-ancpplua/otel-conventions-api` | GitHub Packages npm (`https://npm.pkg.github.com`) | TypeSpec projects importing the qyl API surface |
| .NET/NuGet | `ANcpLua.OtelConventions.Api` | GitHub Packages NuGet (`https://nuget.pkg.github.com/O-ANcppLua/index.json`) | qyl C# projects consuming emitted contract POCOs |

qyl references the NuGet package. The npm package is still the source contract package; the NuGet package is emitted from it during pack/publish.

## Install

Add `.npmrc` to your project root pointing the `@o-ancpplua` scope at GitHub Packages:

```ini
@o-ancpplua:registry=https://npm.pkg.github.com
```

Then install normally:

```bash
npm install @o-ancpplua/otel-conventions-api --save-dev
```

In CI, set `NODE_AUTH_TOKEN=${{ secrets.GITHUB_TOKEN }}` and add `always-auth=true` to your `.npmrc`. For local dev, run `npm login --scope=@o-ancpplua --registry=https://npm.pkg.github.com` once with a GitHub PAT that has `read:packages`.

In your `main.tsp`:

```typespec
import "@o-ancpplua/otel-conventions-api";
```

Sub-paths are exposed for consumers that want narrower imports:

```typespec
import "@o-ancpplua/otel-conventions-api/otel";          // OTel signal models only
import "@o-ancpplua/otel-conventions-api/models/genai";  // a single qyl model
import "@o-ancpplua/otel-conventions-api/generated/otel-keys";  // generated semconv keys
```

## Contents

- `index.tsp` — published TypeSpec entry point reached via `import "@o-ancpplua/otel-conventions-api"`.
- `main.tsp` — local-development entry point that additionally wires the build-only emit routing (`emit-config.tsp`, `emit-duckdb.tsp`); not shipped to consumers.
- `otel/` — OpenTelemetry-shaped core models; consumers reach the barrel via `import "@o-ancpplua/otel-conventions-api/otel"`.
- `generated/otel-keys.gen.tsp` — generated semantic-convention key constants from upstream pinned at v1.41.0.
- `models/`, `api/`, `common/`, `intelligence/` — API models and routes.
- `emitters/` — local TypeSpec emitters required by `tspconfig.yaml` (csharp, duckdb, ts-types, otelconventions-lint); not shipped to consumers.

## Local development

```bash
npm install
npm run lint       # tsp compile --no-emit --warn-as-error
npm run compile    # full emit; outputs under generated/
npm run format     # tsp format **/*.tsp
```

## Publishing

Uses **GitHub Packages** (no separate npmjs.com account needed — auth flows through the `GITHUB_TOKEN` minted automatically inside GitHub Actions).

1. On this repo: Settings → Environments → create an environment named `github-packages` (no protection rules required unless you want manual approval before each publish).
2. Cut a GitHub Release. The `.github/workflows/publish.yml` workflow runs on `release: published`, calls `npm publish --access public --provenance`, and emits an npm provenance attestation tied to the workflow run.

Workflow can also be triggered manually via `workflow_dispatch` with a custom `tag` input (e.g. `next`, `rc`, `beta`).

## Versioning

See [`VERSIONING.md`](./VERSIONING.md). Stays in `0.x` until the OpenTelemetry community decides on the upstream PR shape; bump to `1.0.0` only after that lands.

## Naming

The npm scope is `@o-ancpplua` (lowercase, matches the GitHub org name as GitHub Packages requires). If this ever migrates to npmjs.com, the scope can be flattened to `@ancplua` at that time.
