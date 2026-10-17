# qyl-api-schema

The qyl API contract source: TypeSpec emitted to OpenAPI, JSON Schema, TypeScript (`@ancplua/qyl-api-schema`) and C# (`Qyl.Api.Contracts`). Layout and generated outputs: [`CONTRIBUTING.md`](CONTRIBUTING.md).

Push to `main` directly. Verify changed contracts, generators and affected consumers; reuse passing results while their inputs remain unchanged. Prose-only changes need no execution check. `mise run check` is the full source gate when needed and CI runs it for reporting. Keep the actual native release checks, without adding a full-suite rerun solely for a commit or release. Releases and consumers: [`SKILL.md`](SKILL.md).

## Telemetry boundary

API models, schemas, validators and the contract handshake live here; telemetry definitions come from Qyl.Telemetry.SemanticConventions. Official SDKs and exporters stay in the consumer repos; the contracts take no telemetry runtime dependency.
