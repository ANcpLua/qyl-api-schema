# Qyl.Api.Contracts

Generated C# request, response, enum and model types for the qyl observability API, emitted from
the TypeSpec contract in
[`@ancplua/qyl-api-schema`](https://www.npmjs.com/package/@ancplua/qyl-api-schema). BCL only: the package has no
dependencies, is marked AOT-compatible, and nothing in it reflects.

```bash
dotnet add package Qyl.Api.Contracts
```

```csharp
using Qyl.Api.Contracts;

// Every client-visible request, response, stream event and error of the qyl API,
// with the wire names the collector serves.
var revision = ContractRevision.Value;   // "sha256:…", the contract this package was generated from
```

## What is in it

- Traces, logs and metrics as the collector serves them over `/api/v1/`: the OTel-shaped models
  are client-facing JSON projections of the wire, targeting OpenTelemetry schema
  `https://opentelemetry.io/schemas/1.44.0`.
- The runner and workbench models, the streaming events, and the error shapes.
- `ContractRevision`, the deterministic digest of the contract. A collector reports the revision
  it was built against on its health response, so a client can detect a peer built from a
  different contract instead of discovering the mismatch one malformed field at a time.

OTLP ingestion is not in this package; it uses the official OpenTelemetry protobuf messages.

## Versioning

The contract advances on its own major cadence, shared with the npm package from one release
tag, and does not track the qyl product version. The
[OpenAPI document](https://github.com/ANcpLua/qyl-api-schema/blob/main/generated/openapi/qyl.openapi.json)
this package was generated from is committed beside its source.

## More

- The TypeSpec source, the pipeline and the boundary rules:
  [github.com/ANcpLua/qyl-api-schema](https://github.com/ANcpLua/qyl-api-schema#readme)
- The product these contracts describe: [qyl.at](https://qyl.at/)
