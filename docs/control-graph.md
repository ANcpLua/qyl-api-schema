# Telemetry contract projection

This repository treats TypeSpec as the source of truth for qyl telemetry contracts.
The control graph is a generated contract view over existing schema inputs:
generation profiles, signal shapes, signal predicates, resource/profile models, and
typed semantic-convention keys.

The projection does not define a runtime implementation. It emits verifier inputs and
review artifacts used to compare declared telemetry against observed collector data.

## Source of truth

| Source | Role |
|---|---|
| `models/configurator.tsp` | Defines generation profiles used by instrumentation code generation. |
| `intelligence/signals.tsp` | Defines atomic signal predicates and attribute conditions. |
| `otel/*.tsp` | Defines trace, log, metric, resource, and profile shapes. |
| `generated/otel-keys.gen.tsp` | Provides typed OpenTelemetry semantic-convention keys. |
| `models/control-graph.tsp` | Composes services, declared signals, attributes, and export edges. |

## Generated outputs

The authoritative emitted contract is the graph JSON and the conformance plan. Everything
else is a view or a typed projection of the same source — never an independent contract.

| Output | Role |
|---|---|
| `generated/control-graph/control-graph.json` | Canonical machine-readable graph contract. |
| `generated/control-graph/conformance-plan.json` | Verifier input: expected services, signals, attributes, and exporters. |
| `generated/control-graph/control-graph.schema.json` | JSON Schema for the emitted graph shape. |
| `generated/contracts/Qyl/**` | Typed C# contract types emitted by `@ancplua/typespec-emit-csharp` — the same source, projected for .NET consumers. |

Views and debug slices (generated, not independent sources):

| Output | Role |
|---|---|
| `generated/control-graph/control-graph.yaml` | Human-readable serialization of the graph. |
| `generated/control-graph/control-graph.report.md` | Optional review summary. |
| `generated/control-graph/instrumentation-profiles.json` | Profile references used by service nodes. |
| `generated/control-graph/declared-signals.json` | Service-to-signal declaration view. |
| `generated/control-graph/export-edges.json` | Service/signal-kind to exporter routing view. |

## The shape of the pipeline

```text
TypeSpec sources -> control graph -> conformance plan -> verifier
```

Not: many JSON files, all of them treated as truth. The authority is
`models/control-graph.tsp` -> `control-graph.json` -> `conformance-plan.json`. The C# types,
YAML, report, and slices are projections of that single source.

## Validation

The TypeSpec compile validates structural graph invariants:

| Check | Boundary |
|---|---|
| Service node has a profile binding | TypeSpec model / graph validation |
| Profile reference resolves | TypeSpec reference validation where modeled as a reference |
| Signal reference resolves | TypeSpec reference validation where modeled as a reference |
| Attribute key is typed semconv or approved qyl key | Linter policy |
| Service declares at least one signal | Graph validation |
| Declared signal is routed or explicitly local-only | Graph validation |
| Export target resolves | Graph validation |
| Node identifiers are unique | Graph validation |

Policy checks live in `otelconventions-lint`. Broken graph shape lives in the control-graph
emitter validation.

## Out of scope

The control graph emitter does not generate runtime services, collector storage schemas,
HTTP handlers, mock implementations, or exporter configuration.

Exporter configuration may be generated later from the graph after the verifier contract is
stable. Until then, the graph describes expected telemetry behavior; it does not mutate runtime
configuration.
