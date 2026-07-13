# @ancplua/qyl-api-schema

The TypeSpec source of truth for Qyl's client-visible product API. This repository
emits the public schema and contract artifacts; it does not implement the server,
storage engine, or OTLP receiver.

## Contract pipeline

```text
Qyl.OpenTelemetry.SemanticConventions
        |
        | generated semantic key projection
        v
generated/otel-keys.gen.tsp
        |
        v
authored Qyl TypeSpec
        |
        +----> OpenAPI and JSON Schema
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

| Ecosystem | Artifact | Purpose |
| --- | --- | --- |
| npm/TypeSpec | `@ancplua/qyl-api-schema` | Authored schema for TypeSpec consumers |
| NuGet | `Qyl.Api.Contracts` | BCL-only generated .NET contracts |
| Generated | OpenAPI, JSON Schema, TypeScript | Client and validation inputs |

`main.tsp` is the local compile entry point and includes emitter routing. `index.tsp`
is the published TypeSpec entry point and contains only the client-facing contract.

## Develop

```bash
npm ci
npm run lint
npm run lint:public
npm run compile
./build.sh Check
```

Important generated outputs include:

- `generated/openapi/qyl.openapi.json`
- `generated/json-schema/qyl-api-schema`
- `generated/contracts/**/*.cs`
- `generated/ts-types/**`

Generated files are not editing surfaces. Change TypeSpec or the owning emitter and
regenerate.

## Publish

GitHub Actions publishes both registries through OIDC trusted publishing. A release
tag supplies one version for npm and NuGet. The workflow validates and packs first,
publishes in an ordered restartable sequence, waits for indexed artifacts, and then
smokes clean consumers. No long-lived npm or NuGet token is stored.

## License

Apache-2.0
