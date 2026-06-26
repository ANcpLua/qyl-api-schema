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
  v1_28: "1.28.0",
  v1_29: "1.29.0",
  v1_37: "1.37.0",
  v1_38: "1.38.0",
  v1_39: "1.39.0",
  v1_40: "1.40.0",
  v1_41: "1.41.0",
}

model GenAiSpanAttributes {
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.System)
  @removed(GenAiVersions.v1_37)
  system?: string;

  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.UsagePromptTokens)
  @removed(GenAiVersions.v1_28)
  usagePromptTokens?: TokenCount;

  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.UsageInputTokens)
  usageInputTokens?: TokenCount;

  @encodedName("application/json", "gen_ai.usage.input_tokens.cached")
  @added(GenAiVersions.v1_38)
  usageInputTokensCached?: TokenCount;
}
```

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
