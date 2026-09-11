# @ancplua/qyl-api-schema

The TypeSpec source of truth for Qyl's client-visible product API. This repository
emits the public schema and contract artifacts; it does not implement the server,
storage engine, or OTLP receiver.

Qyl stores and exposes traces, logs, and metrics. The metric surface is read-only.
`GET /api/v1/metrics` lists the metric descriptors recorded for a project,
`GET /api/v1/metrics/{metric_name}/series` lists the distinct attribute streams
under one metric name, and `GET /api/v1/metrics/{metric_name}/query` aggregates one
metric over a time range into buckets. Metric points are written over OTLP, which
this contract does not describe. Profiles are not supported.

## Contract pipeline

```text
authored Qyl TypeSpec
        |
        +----> OpenAPI ----> bundled JSON Schema
        +----> Qyl.Api.Contracts
        +----> generated TypeScript contracts
```

Qyl domain models, routes, responses, stream events, and errors are authored here.
The OTel-compatible models target schema `https://opentelemetry.io/schemas/1.44.0`;
attribute keys cross the wire as open string maps, so this contract carries no
enumeration of the OpenTelemetry attribute registry.

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

## Runtime validation

`@ancplua/qyl-api-schema/zod` builds Zod validators from the bundled JSON Schema at
runtime. It is a translation layer over `z.fromJSONSchema` — authored in `src/zod/`
and compiled to `generated/zod-runtime/` — not a second hand-written schema, so a
contract change cannot leave a validator describing the previous shape.

```ts
import { publishedContractSchema } from "@ancplua/qyl-api-schema/zod";
import type { Span } from "@ancplua/qyl-api-schema/types";

const SpanSchema = publishedContractSchema<Span>("OTel.Traces.Span");
const span = SpanSchema.parse(await response.json());
```

`zod` is an optional peer dependency (`>=4.5.0 <5`): a consumer that does not
install it simply never imports this subpath, and the other subpaths do not depend
on it. Definition names are the published `$defs` keys — the same names the OpenAPI
components and the generated C# and TypeScript DTOs carry — and
`contractDefinitionNames()` lists all of them. The type argument is not checked
against the schema, so pair it with the matching type from `./types`.

## Contract revision

`scripts/emit-contract-revision.mjs` stamps a deterministic revision — `sha256:` plus
the first 16 hex characters of the contract's canonical semantic digest — into both
generated faces during `npm run compile`. A collector reports the revision it was built
against on its health response, so a client can detect a peer built from a different
contract instead of discovering the mismatch one malformed field at a time. Read the
current value from a running collector or the generated artifacts; it is derived, never
hand-maintained.

## Contributing

How to build, lint, regenerate and publish is in [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Apache-2.0
