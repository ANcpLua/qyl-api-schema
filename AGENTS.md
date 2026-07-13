# qyl-api-schema engineering contract

This is the repository's only editable agent/contributor instruction file.
`CLAUDE.md` is a symlink to it. `README.md` is the public package front door;
generated reports are evidence, not additional authorities. Do not add migration
plans, progress diaries, handoff prompts, or a second rules file.

## Product-contract ownership

This TypeSpec repository is the sole owner of Qyl's client-visible product contract.
It emits the `@ancplua/qyl-api-schema` TypeSpec package, OpenAPI/JSON Schema,
`Qyl.Api.Contracts`, and generated TypeScript contract types.

There is one owner for each boundary:

- **Qyl product API:** every client-visible request, response, stream event, and
  error is authored in TypeSpec here and emitted through `Qyl.Api.Contracts` or a
  generated client.
- **OTLP ingestion:** the runtime uses official OpenTelemetry protobuf messages.
  This repository does not redefine OTLP receiver wire contracts.
- **Runtime internals:** collector storage rows, ingest batches, query models, and
  internal projections remain runtime-owned and must not cross an HTTP, gRPC, MCP,
  streaming, or generated-client boundary.
- **Telemetry JSON projections:** models under `otel/` that are used by Qyl routes
  are client-facing Qyl JSON projections. They are not substitutes for OTLP
  protobuf messages.

When an internal shape must become client-visible, define it here first, regenerate,
and map to the generated contract. Do not create public DTOs in `qyl.collector`,
Qyl.Host, dashboard code, or MCP code. Anything serialized across a client boundary
is a contract regardless of its source-language accessibility.

## Allowed and forbidden outputs

Allowed outputs are TypeSpec, OpenAPI, JSON Schema, BCL-only C# contracts, and
TypeScript contract types. Do not emit server scaffolds, controllers, mock business
logic, DuckDB/storage schemas, runtime services, or compatibility packages for
retired identities.

The package and namespace identities are:

- npm: `@ancplua/qyl-api-schema`
- NuGet: `Qyl.Api.Contracts`
- .NET namespaces: `Qyl.Api.Contracts.*`

## Generated ownership

- Authored TypeSpec under `api/`, `common/`, `models/`, and `otel/`
  owns the product contract.
- `generated/otel-keys.gen.tsp` is emitted by the sibling
  `Qyl.OpenTelemetry.SemanticConventions` repository's `emit_typespec_keys.py` from
  its resolved registry. It supplies names, not product models.
- Emitters under `emitters/` own generated C# and TypeScript contracts; TypeSpec's
  official emitters own OpenAPI and JSON Schema.
- Never hand-edit generated output. Change TypeSpec, an emitter, or an upstream
  generated input and regenerate deterministically.

## Versioning

Published npm and NuGet versions are derived from the release tag by CI; committed
package versions are non-authoritative development placeholders. TypeSpec
`@versioned` enums contain only the baseline and versions actually referenced by an
`@added` or `@removed` annotation. Remove empty version axes rather than preserving
timeline decoration.

Deprecated telemetry-key normalization is an ingestion concern in Qyl runtime. The
public contract describes current fields and does not retain old wire aliases as
compatibility DTOs.

## Verification

Run the local repository gate:

```bash
npm ci
./build.sh Check
```

At minimum, contract work must pass `npm run lint`, `npm run lint:public`,
`npm run compile`, deterministic generated-output comparison, npm packing, and
`./build.sh PackContractsNuget`. Restore the produced `Qyl.Api.Contracts` package
into a clean Qyl consumer for boundary changes.

## Publishing

Publication is GitHub Actions OIDC trusted publishing to npmjs.org and nuget.org.
Never add long-lived registry credentials or publish locally. The workflow publishes
in an ordered, restartable sequence; it is not atomic across registries. Release
completion requires both indexed artifacts and clean-consumer smoke tests.
