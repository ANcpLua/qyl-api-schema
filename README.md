# `@ancplua/qyl-api-schema`

`qyl-api-schema` is the TypeSpec source of truth for qyl's public observability API.

It is not an OpenTelemetry package and it is not a server implementation. OpenTelemetry is one
compatibility layer for qyl ingestion and instrumentation; qyl's API contracts are product contracts
owned by qyl.

## Contract pipeline

```text
open-telemetry/semantic-conventions @ v1.41.0
        |
        | Weaver
        v
@ancplua/typespec-otel-semconv
        |
        | TypeSpec import / lockstep key projection
        v
@ancplua/qyl-api-schema
        |
        | TypeSpec emit
        v
OpenAPI JSON + JSON Schema + Qyl.Api.Contracts + TS contract types
        |
        v
qyl services, dashboard, tools, and generated clients
```

The generic OpenTelemetry key projection lives in
`@ancplua/typespec-otel-semconv` under
`ANcpLua.OpenTelemetry.SemanticConventions.Keys.*`. This repo defines qyl domain
models, routes, and response contracts under `Qyl.Api.Contracts.*`.

## Published artifacts

| Ecosystem | Package | Purpose |
| --- | --- | --- |
| TypeSpec/npm | `@ancplua/qyl-api-schema` | Source schema for qyl API consumers and generators |
| NuGet | `Qyl.Api.Contracts` | BCL-only generated C# DTOs for qyl services and consumers |

Client packages are intentionally not committed here. Generate clients from the OpenAPI document
when needed, or add a dedicated `Qyl.Api.Client` package later. Do not generate a second C# model
world through a client emitter.

## Repository layout

| Path | Role |
| --- | --- |
| `main.tsp` | Local compile entry point. Includes build-only emit routing. |
| `index.tsp` | Published TypeSpec entry point. Excludes local emitter wiring. |
| `api/` | REST and streaming API operations. |
| `common/`, `models/`, `otel/`, `intelligence/` | qyl contract models. |
| `emitters/` | Local TypeSpec emitters for C#, TS types, and qyl schema linting. |
| `generated/` | Generated artifacts from `npm run compile`; never edit by hand. |
| `packaging/Qyl.Api.Contracts.csproj` | Packs `generated/contracts` as the `Qyl.Api.Contracts` NuGet. |

## Local development

```bash
npm ci
npm run lint
npm run lint:public
npm run compile
./build.sh PackContractsNuget
```

`npm run compile` emits:

- `generated/openapi/qyl.openapi.json`
- `generated/json-schema/qyl-api-schema.json`
- `generated/contracts/**/*.cs`
- `generated/ts-types/**`

## Hard boundaries

- Do not add TypeSpec C# server scaffold emitters.
- Do not add DuckDB/storage schema emitters. Physical storage schema lives in qyl runtime mapping specs.
- Do not commit generated ASP.NET projects, controllers, mocks, or starter
  docs that tell maintainers to fill in mock business logic.
- Do not add compatibility shims for old package IDs or namespaces.
- Do not hand-edit generated output. Fix TypeSpec, emitter code, or generator inputs, then regenerate.
- Do not reintroduce legacy qyl API package IDs or namespaces.

## Publishing

Publishing is fully automated via GitHub Actions OIDC **trusted publishing** — no stored secrets, no
API keys. Publish a GitHub Release whose tag is `vMAJOR.MINOR.PATCH[-prerelease]`; `publish.yml` then,
all-or-nothing, packs and validates the artifacts, stamps that single tag-derived version onto both,
pushes `Qyl.Api.Contracts` to nuget.org (NuGet/login OIDC) and publishes `@ancplua/qyl-api-schema` to
npmjs.org (npm trusted publishing + provenance). NuGet pushes first (idempotent) and npm last
(immutable), so a partial failure re-runs cleanly. See [VERSIONING.md](VERSIONING.md) for how the
version is derived from the tag. There are no long-lived publish tokens to manage or rotate.
