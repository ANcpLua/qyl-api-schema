# @ancplua/qyl-api-schema

The TypeSpec source of truth for Qyl's client-visible product API. This repository
emits the public schema and contract artifacts; it does not implement the server,
storage engine, or OTLP receiver.

The contract covers every client-visible surface of a qyl collector and runner:

- **Traces** — `GET /api/v1/traces`, one trace, and its spans (`api/routes.tsp`,
  `otel/span.tsp`).
- **Logs** — `GET /api/v1/logs` and the live SSE stream `GET /api/v1/stream/logs`
  with its heartbeat (`api/streaming.tsp`, `otel/logs.tsp`).
- **Metrics**, read-only — `GET /api/v1/metrics` lists the metric descriptors
  recorded for a project, `GET /api/v1/metrics/{metric_name}/series` lists the
  distinct attribute streams under one metric name, and
  `GET /api/v1/metrics/{metric_name}/query` aggregates one metric over a time range
  into buckets (`models/metrics.tsp`). Metric points are written over OTLP, which
  this contract does not describe. Profiles are not supported.
- **Sessions** — `GET /api/v1/sessions`, one session, its traces and `/stats`
  (`models/session.tsp`).
- **Health** — `GET /health` and `GET /alive`, whose `HealthReport` carries the
  `contract_revision` handshake (`models/health.tsp`).
- **MCP tools** — the input and structured-output models of the qyl MCP tools
  (`models/mcp-tools.tsp`).
- **Workbench** — the local MCP workbench: sessions, workspaces, servers, protocol
  streams, executions, test cases, suites, evaluation runs and exports
  (`api/workbench.tsp`, `models/workbench.tsp`).
- **Runner** — the local runner's loopback-only `/runner/resources` snapshot, SSE
  streams, logs and restart/stop actions for `collector`, `project` and `command`
  processes (`api/runner.tsp`, `models/runner.tsp`). MCP server identity and tool
  discovery are exposed by Workbench connection and discovery snapshots.
- **Shared** — RFC 9457 problem details (`common/errors.tsp`), cursor pagination
  (`common/pagination.tsp`) and the common scalars (`common/`), plus the OTel
  resource, span and log projections (`otel/`).

Telemetry itself is never changed or deleted through this contract; retention
removes it. The only writable resources are annotations (`/api/v1/annotations`,
a note of at most 2000 characters on a trace, span or session), saved queries
(`/api/v1/saved-queries`, a named structured filter for traces, logs or metrics,
run with `POST …/{saved_query_id}:run`) and failure status
(`PATCH /api/v1/failures/{failure_id}`, a recorded failure's status, assignee or
ignore-until time). Annotations and saved queries extend the shared write base in
`common/resource.tsp`: server-assigned `id`, `created_at`, `updated_at` and `etag`;
`Idempotency-Key` on create, which answers `201` with `Location`; `If-Match` on
`PATCH` and `DELETE`, refused with `428` when missing and `412` when stale. The
failure status `PATCH` takes the same `If-Match`. Collector keys carry the roles
`ingest`, `read`, `write` and `delete` (`CollectorKeyRole`); writes need `write`,
deletes `delete`.

## Errors and pages

Every error body is an RFC 9457 problem served as `application/problem+json`: `type`,
`title`, `status`, `detail` and `instance`, plus the extension member `code`. Each
problem type fixes its `type` URI (`https://qyl.at/problems/<name>`) and its `code`
(`not_found`, `validation_failed`, …), so a client branches on either and never on
`title` or `detail`. Problem bodies carry no headers. A response header is declared on
the operations whose server sends it: `X-Trace-Id` on the collector's 500 responses,
`WWW-Authenticate` on the workbench's 401 responses.

Every list operation pages forward with an opaque cursor. It takes `limit`
(`PageLimit`: 1 to 1000, 100 when omitted) and `cursor`, and its page carries
`has_more` and, on every page but the last, `next_cursor`, which the next request
sends back as `cursor`.

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

### Package exports

| Subpath | Content |
| --- | --- |
| `@ancplua/qyl-api-schema` | `index.tsp`, the whole TypeSpec contract |
| `@ancplua/qyl-api-schema/otel` | `otel/otel-conventions.tsp`: only the OTel-shaped resource, span and log models, for TypeSpec consumers that do not want the qyl API |
| `@ancplua/qyl-api-schema/types` | Generated TypeScript contract types and the `CONTRACT_REVISION` constant |
| `@ancplua/qyl-api-schema/openapi` | `qyl.openapi.json` |
| `@ancplua/qyl-api-schema/json-schema` | The bundled JSON Schema |
| `@ancplua/qyl-api-schema/zod` | Runtime validators, below |
| `@ancplua/qyl-api-schema/runtime` | Presentation helpers over the generated `AttributeValue` matcher (`decodeAttributeValue`, `formatAttributeValue`, `attributeString`, `attributeNumber`, `attributeIdentity`, `matchAttributeValue`) and the `UnixNanos` string helpers (`parseUnixNanos`, `compareUnixNanos`, `unixNanosDelta`, `unixNanosToEpochMs`, `unixNanosToIso`, `epochMsToUnixNanos`). Authored in `src/runtime/`, compiled to `generated/runtime/` |

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
generated faces during `bun run compile`. A collector reports the revision it was built
against on its health response, so a client can detect a peer built from a different
contract instead of discovering the mismatch one malformed field at a time. Read the
current value from a running collector or the generated artifacts; it is derived, never
hand-maintained.

The OpenAPI `info.version` is the release version: `prepack` stamps it into the packed
document from the release tag, and the tracked document keeps TypeSpec's `0.0.0`. The
digest excludes `info.version`, so a release that changes nothing but its version keeps
the revision.

## Investigation contracts

The generated `Mcp.Tools` surface covers the 32-tool qyl MCP set. Each of the 26 read tools has a distinct, typed `POST /api/v1/analysis/<tool_name>` operation. Structured predicates support the shared matcher operators; read results carry the absolute `window` and `coverage` with nullable unknown counts. Existing trace, log, metric and session REST routes remain available.

Failure status is updated through `PATCH /api/v1/failures/{failure_id}` with `If-Match`. Failure handles, verification tokens and cursors are scoped and validated by the collector. Annotation contracts support failure targets, labels, classifications and retry keys. These contracts carry product data only; telemetry runtime dependencies remain in their producer repositories.

The schema gate checks all read operation/type pairs, answer-key result shapes and invalid inputs, then verifies the packed npm and NuGet consumers. Collector behavior and the seeded live tool answers are tested by the collector and MCP suites against the same generated contracts.

## Contributing

How to build, lint, regenerate and publish is in [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Apache-2.0
