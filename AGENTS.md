# qyl-api-schema engineering contract

This is the repository's only editable agent/contributor instruction file.
`CLAUDE.md` is a symlink to it. `README.md` is the public package front door;
generated reports are evidence, not additional authorities. Do not add migration
plans, progress diaries, handoff prompts, or a second rules file.

## Place in the 1.0.0 taxonomy

This repository is not one of the nine runtime components; it is where the
**product API contract** is authored, and the collector consumes it through
`Qyl.Api.Contracts`. The collector explicitly disables OpenAPI generation for
that reason — it is not a contract or client-generation source. Keep it that
way: one owner per contract.

It also consumes the TypeSpec key projection from
`Qyl.Telemetry.SemanticConventions` (today
`Qyl.OpenTelemetry.SemanticConventions`). That projection is generated from the
same Weaver registry as the producer constants and the collector's
`CollectorSemanticAttributeCatalog.g.cs`, which is what keeps wire names
consistent across all three. Never hand-author a name that the registry owns.

The full ledger and the boundary law live in `qyl-workspace/AGENTS.md` — that
file is binding and this one does not restate it.

## Product-contract ownership

This TypeSpec repository is the sole owner of Qyl's client-visible product contract.
It emits the `@ancplua/qyl-api-schema` TypeSpec package, OpenAPI/JSON Schema,
`Qyl.Api.Contracts`, and generated TypeScript contract types.

Qyl's stored and queryable telemetry surface is traces and logs. Metrics have no
product DTOs or query routes because the collector accepts and discards them only
at its OTLP boundary. Profiles are not supported.

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
logic, DuckDB/storage schemas, runtime services, or alternate package and namespace
identities.

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
  official emitter owns OpenAPI, and `scripts/openapi-to-json-schema.mjs` owns the
  bundled JSON Schema projection with the same wire names.
- Never hand-edit generated output. Change TypeSpec, an emitter, or an upstream
  generated input and regenerate deterministically.

## Wire naming

The product contract has exactly one wire-naming convention: **snake_case for every
JSON body property and for every query and path parameter.** There is no
camelCase-passthrough population and no dotted key anywhere in a product DTO —
dotted semantic-convention keys are attribute *values* at the OTLP ingestion
boundary, which this repository does not own.

Names are written explicitly with `@encodedName("application/json", …)` rather than
derived by an emitter policy, so `index.tsp` compiled by any consumer produces the
same wire names as the artifacts published beside it. Writing a name is not the same
as choosing one: the wire name must equal `snake_case(propertyName)` unless the pair
is registered in `WIRE_NAME_EXCEPTIONS`, so casing is derived and never a per-property
judgement call. The registry holds only the five cases where the wire name genuinely
differs from the property name — `InstrumentationScope.scopeName` → `name`,
`scopeVersion` → `version`, `scopeAttributes` → `attributes` (OTLP names those fields
bare because the object already *is* the scope), `ProblemDetails.problemType` → `type`
(RFC 7807 fixes the member name and `type` is reserved in TypeSpec), and
`SessionStats.sessionsWithGenAi` → `sessions_with_genai` (`genai` is one semconv
token). An exception may never be a casing fix.

An identity has one scalar, one property name, and one wire key everywhere it
appears — `TraceId`/`traceId`/`trace_id`, `SessionId`/`sessionId`/`session_id`. A
field carrying an identity is typed as its scalar and never as a bare `string`, so
it keeps that scalar's pattern and length validation. A second spelling of the same
identity is the defect this convention exists to prevent: values pass between
routes and MCP tool arguments, and a mismatched key yields an empty result rather
than an error.

`@ancplua/typespec-qyl-lint` enforces all of the above. It is loaded by name from
`tspconfig.yaml` and is never imported by a `.tsp` file, which keeps the published
entry point free of build-only dependencies while `npm run lint` and
`npm run lint:public` still check the exact source that ships. Its `src/policy.ts`
is the single declaration of the convention and of the identity table.

The two identity directions are asymmetric on purpose. A name is reserved for an
identity by an *exact* list, never an `endsWith("Id")` test — the contract has some
twenty-five other `*Id` properties (`WorkbenchServerId`, `WorkbenchExecutionId`, …)
that are their own types and must not be captured. The other direction is closed the
same way: a property that *carries* an identity is spelled with the bare token
(`traceId`), its plural (`traceIds`), or one of the qualified edges registered in the
identity's `edges` table with the relationship it expresses — `parentSpanId`,
`previousSessionId`, `selectedTraceId`. A suffix test would have been shorter, but it
silently admits `candidateTraceId`, `rootTraceId`, and every future coinage, which is
exactly how one identity acquires a second spelling; a new edge is a deliberate
one-line entry instead. A resource's own `@key` is exempt from that name check.

`npm run verify:lint-rules` compiles `emitters/qyl-lint/test/violations.tsp`, a
fixture that must be rejected, and fails unless every declared rule produces at
least one diagnostic. A linter whose rules match nothing passes exactly like a clean
tree; this is what keeps the guarantee from going quietly vacuous. Add a case there
for any rule you add.

## Versioning

Published npm and NuGet versions are derived from the release tag by CI; committed
package versions are non-authoritative development placeholders. TypeSpec
`@versioned` enums contain only the baseline and versions actually referenced by an
`@added` or `@removed` annotation. Remove empty version axes rather than preserving
timeline decoration.

Telemetry-key normalization is an ingestion concern in Qyl runtime. Product DTOs
expose canonical fields only and do not include ingestion aliases.

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
