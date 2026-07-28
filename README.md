# @ancplua/qyl-api-schema

The TypeSpec source of truth for Qyl's client-visible product API. This repository
emits the public schema and contract artifacts; it does not implement the server,
storage engine, or OTLP receiver.

Qyl stores and exposes traces and logs. Metrics are accepted and discarded only by
the collector's OTLP wire-compatibility handlers, so this product contract exposes
no metric DTOs or routes. Profiles are not supported.

## Contract pipeline

```text
Qyl.Telemetry.SemanticConventions
        |
        | generated semantic key projection
        v
generated/otel-keys.gen.tsp
        |
        v
authored Qyl TypeSpec
        |
        +----> OpenAPI ----> bundled JSON Schema
        +----> Qyl.Api.Contracts
        +----> generated TypeScript contracts
```

The semantic-key projection is generated from the sibling conventions repository's
pinned core and GenAI registries. It supplies typed names for telemetry attributes;
Qyl domain models, routes, responses, stream events, and errors are authored here.

## Boundary

- Every client-visible Qyl request, response, stream event, and error is defined in
  this repository.
- OTLP ingestion uses official OpenTelemetry protobuf messages in the runtime and is
  not redefined here.
- Models under `otel/` used by Qyl routes are client-facing JSON projections, not
  OTLP wire messages.
- Collector storage rows, ingest batches, query models, and internal projections do
  not cross an HTTP, gRPC, MCP, streaming, or generated-client boundary.

If a runtime shape needs to become client-visible, add it to TypeSpec first,
regenerate the artifacts, and map the runtime model to the generated contract.

## Published artifacts

Both registries carry the same version from one release tag. The contract advances on
its own major cadence and does not track the qyl product version — it was already at
`5.0.0` when qyl launched at `1.0.0`. Read the current version from npm or nuget.org
rather than from prose here; this line moves faster than a README is revised.

| Ecosystem | Artifact | Purpose |
| --- | --- | --- |
| npm/TypeSpec | `@ancplua/qyl-api-schema` | Authored schema for TypeSpec consumers |
| NuGet | `Qyl.Api.Contracts` | BCL-only generated .NET contracts |
| Generated | OpenAPI, JSON Schema, TypeScript | Client and validation inputs |

`main.tsp` is the local compile entry point and includes emitter routing. `index.tsp`
is the published TypeSpec entry point and contains only the client-facing contract.

## Contract revision

`scripts/emit-contract-revision.mjs` stamps a deterministic revision — `sha256:` plus
the first 16 hex characters of the contract's canonical semantic digest — into both
generated faces during `npm run compile`. A collector reports the revision it was built
against on its health response, so a client can detect a peer built from a different
contract instead of discovering the mismatch one malformed field at a time. Read the
current value from a running collector or the generated artifacts; it is derived, never
hand-maintained.

## Develop

Development and CI use Node.js 24 LTS. Published npm artifacts support maintained
Node.js releases from 22 onward.

```bash
npm ci
npm run lint
npm run lint:public
npm run compile
./build.sh Check
```

Important generated outputs include:

- `generated/openapi/qyl.openapi.json`
- `generated/json-schema/qyl-api-schema.json`
- `generated/contracts/**/*.cs`
- `generated/ts-types/**`

Generated files are not editing surfaces. OpenAPI comes from the official TypeSpec
emitter; the bundled JSON Schema is a deterministic projection of its component
schemas and exposes inline route bodies as stable
`Operations.<operationId>.Request` and
`Operations.<operationId>.Response.<status>` definitions. Both artifacts preserve
the same wire names. Change TypeSpec or the owning generator and regenerate.

## Publish

GitHub Actions publishes both registries through OIDC trusted publishing. A release
tag supplies one version for npm and NuGet. The workflow validates and packs first,
publishes in an ordered restartable sequence, waits for indexed artifacts, and then
smokes clean consumers. No long-lived npm or NuGet token is stored.

## License

Apache-2.0
