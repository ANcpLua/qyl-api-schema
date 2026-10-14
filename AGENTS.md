# qyl-api-schema

The qyl API contract source: TypeSpec emitted to OpenAPI, JSON Schema, TypeScript (`@ancplua/qyl-api-schema`) and C# (`Qyl.Api.Contracts`). Layout and generated outputs: [`CONTRIBUTING.md`](CONTRIBUTING.md).

Push to `main` directly. Gate before every push: `mise run check` (ends in Fallout `./build.sh Check`; prints a summary, `QYL_VERBOSE=1` prints everything). Releases and consumers: [`SKILL.md`](SKILL.md).

## Telemetry boundary

API models, schemas, validators and the contract handshake live here; telemetry definitions come from Qyl.Telemetry.SemanticConventions. Official SDKs and exporters stay in the consumer repos; the contracts take no telemetry runtime dependency.
