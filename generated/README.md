# generated

This directory holds the semconv TypeSpec key projection and the emitter
outputs. `otel-keys.gen.tsp` is Weaver-generated — **do not edit by hand**.
`otel-keys-legacy.tsp` is the one deliberate exception: hand-maintained,
see below.

## Files

| File | Source | Regenerate via |
| --- | --- | --- |
| `otel-keys.gen.tsp` | OpenTelemetry semantic-conventions core **v1.43.0** + the GenAI dev registry (`open-telemetry/semantic-conventions-genai`, pinned commit), merged and projected by the `Qyl.OpenTelemetry.SemanticConventions` repo's Weaver pipeline | In that repo: `src/…SourceGeneration/scripts/generate.sh` (refresh `Resources/resolved-registry.json`), then `src/…SourceGeneration/scripts/emit_typespec_keys.py --write <path-to-this-file>` |
| `otel-keys-legacy.tsp` | Hand-maintained. Frozen legacy wire keys (10 `gen_ai.*` consts) that upstream deleted at the 1.41→1.43 bump but that qyl's published contracts still carry on deprecated migration fields. Values are verbatim from the last registry that defined them (v1.41.0). | Never regenerated. Delete a const here only if upstream re-introduces the same name (the `VerifyKeysLockstep` Nuke target and the TypeSpec duplicate-declaration error both catch that). |

The predecessor projection was the npm package
[`@ancplua/typespec-otel-semconv@1.41.0-2`](https://github.com/ANcpLua/typespec-otel-semconv)
— its source repo is archived/deleted, so 1.41.0-2 was its last possible
release; it is no longer a dependency of this repo.

## What the key files provide

One TypeSpec namespace per OpenTelemetry root group, each declaring `const <Name>: string = "<dotted.key>"`. Extracted `.tsp` models reference these consts inside `@encodedName(...)` instead of hand-typing dotted attribute keys.

```tsp
@encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.System)
system?: string;
```

Deprecated upstream attributes are emitted with `#deprecated "..."` so models that reference them produce a TypeSpec compiler warning matching upstream's own deprecation notes. The legacy file's consts are all `#deprecated` by construction.

## Pin

The checked-in projection is pinned to core semantic-conventions **v1.43.0**
(commit in the file header) plus the GenAI dev registry commit pinned in the
SemanticConventions repo's `generate.sh` (`SEMCONV_GENAI_REF`). The
`VerifyKeysLockstep` Nuke target asserts the header pin matches the
`OtelKeysVersion` parameter (`.nuke/parameters.json`).

Bumping the pin: update the refs in that repo's `generate.sh`, re-run it plus
`emit_typespec_keys.py --write`, replace this checked-in projection, and keep
`SemConvSchemaVersion` in that repo's `Version.props` in lockstep — the .NET
constants and this TypeSpec projection must cite the same registry versions.
Direction is one-way: this repo never invokes Weaver directly.
