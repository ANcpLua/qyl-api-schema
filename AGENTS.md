# qyl-api-schema repository contract

Owns qyl's public HTTP, SSE, Runner, Workbench, workflow, and named MCP-tool
contracts. It does not own OTLP, MCP envelopes, DuckDB schemas, runtime services,
or foreign discovered tool schemas.

Author contracts in TypeSpec, then generate C#, TypeScript, runtime-validation,
OpenAPI, and JSON Schema artifacts. Never hand-maintain parallel consumer DTOs
or edit generated output. Preserve one explicit mapping at private/public
boundaries.

Validate with `npm ci` and `./build.sh Check`; boundary changes also restore
the produced `Qyl.Api.Contracts` into a clean consumer. npm and NuGet publishing
is CI OIDC only and completes only after both artifacts are indexed and consumed.
A registry write that is not a publish goes through `~/.claude/bin/npm-authed` —
the script header is the runbook.
