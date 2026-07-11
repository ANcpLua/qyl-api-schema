# TypeSpec Versioning In qyl-api-schema

This repository uses `@typespec/versioning` to record when schema elements were added or removed across qyl API versions and OpenTelemetry compatibility-model pins. The annotations live in TypeSpec so schema evolution is reviewable at the contract source.

## Release versioning (the package version)

Separate from the `@typespec/versioning` schema annotations below: the published **package** version
(npm `@ancplua/qyl-api-schema` and NuGet `Qyl.Api.Contracts`) is **CI-owned and tag-derived** — no
hand-bumped version lives in any committed file. To cut a release, publish a GitHub Release whose tag
is `vMAJOR.MINOR.PATCH[-prerelease]`; `publish.yml` strips the leading `v` and stamps that single
version onto both npm and NuGet (no build metadata — npm rejects it and NuGet strips it), so the two
registries are lockstep by construction. The committed `package.json` version is the non-authoritative
placeholder `0.0.0-development`, and `packaging/Qyl.Api.Contracts.csproj` carries no `<Version>`.

## Where it is used

- `models/genai.tsp` for GenAI semantic-convention shaped models
- `models/db.tsp` for DB semantic-convention shaped models
- `models/http.tsp` for HTTP semantic-convention shaped models
- `api/routes.tsp` for API versioning

## Pattern: version registry + annotations

```tsp
import "@typespec/versioning";
using TypeSpec.Versioning;

@versioned(GenAiVersions)
namespace Qyl.Api.Contracts.Domains.AI.GenAi;

enum GenAiVersions {
  v1_27: "1.27.0",
  v1_38: "1.38.0",
  v1_40: "1.40.0",
}
```

Keep version enums **minimal**: only the baseline plus versions actually
referenced by an `@added`/`@removed` annotation. Unreferenced members are
dead timeline points that rot (an axis with no annotations at all should
lose `@versioned` entirely — that happened to `HttpVersions`/`DbVersions`
in 0.4.0).

```tsp

model GenAiSpanAttributes {
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.UsageInputTokens)
  usageInputTokens?: TokenCount;

  @encodedName("application/json", "gen_ai.usage.input_tokens.cached")
  @added(GenAiVersions.v1_38)
  usageInputTokensCached?: TokenCount;
}
```

Note (v0.3.0): the pre-migration `gen_ai.*` fields that carried upstream-deleted
wire keys (`gen_ai.system`, `gen_ai.prompt`, `gen_ai.completion`,
`gen_ai.usage.prompt_tokens` / `.completion_tokens`, and the
`gen_ai.openai.*` vendor keys) were **removed from the contract surface**
when the OTel 1.42 GenAI-registry split was adopted. Old-key telemetry is a
collector *ingestion normalization* concern (mapping below), not a contract
field.

## Ingestion mapping (deprecated -> current)

Consumers can keep ingestion backward-compatible by normalizing deprecated attribute keys. Keep any downstream mapping aligned with the TypeSpec history.

```csharp
public static readonly FrozenDictionary<string, string> DeprecatedMappings =
    new Dictionary<string, string>(StringComparer.Ordinal)
    {
        ["gen_ai.system"] = "gen_ai.provider.name",
        ["gen_ai.usage.prompt_tokens"] = "gen_ai.usage.input_tokens",
        ["gen_ai.usage.completion_tokens"] = "gen_ai.usage.output_tokens",
        ["agents.tool.call_id"] = "gen_ai.tool.call.id",
        ["db.system"] = "db.system.name"
    }.ToFrozenDictionary(StringComparer.Ordinal);
```

Downstream consumers should cover these mappings in ingestion tests.

## Workflow for schema evolution

- Add a new version entry to the enum in the owning namespace.
- Mark additions and removals with `@added` and `@removed`.
- Update downstream normalization mappings to keep ingestion compatibility.
- Extend downstream ingestion tests to cover the new mapping.
- Run `npm run compile` after TypeSpec changes.
