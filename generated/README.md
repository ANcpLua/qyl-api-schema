# generated

This directory holds Weaver-generated TypeSpec files. **Do not edit by hand.**

## Files

| File | Source | Regenerate via |
| --- | --- | --- |
| `otel-keys.gen.tsp` | OpenTelemetry semantic-conventions v1.41.0 YAML model, converted by the upstream generator [`ANcpLua/typespec-otel-semconv`](https://github.com/ANcpLua/typespec-otel-semconv) (Weaver-based) | Re-run that generator's pipeline (`scripts/generate.mjs`) and replace this checked-in TypeSpec projection. Lockstep flip planned: this directory becomes a dep on `@ancplua/typespec-otel-semconv@<semconv-version>-<N>` and stops being a checked-in artifact. |

## What `otel-keys.gen.tsp` provides

One TypeSpec namespace per OpenTelemetry root group, each declaring `const <Name>: string = "<dotted.key>"`. Extracted `.tsp` models reference these consts inside `@encodedName(...)` instead of hand-typing dotted attribute keys.

```tsp
@encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.System)
system?: string;
```

Deprecated upstream attributes are emitted with `#deprecated "..."` so models that reference them produce a TypeSpec compiler warning matching upstream's own deprecation notes.

## Pin

The checked-in projection is pinned to upstream OpenTelemetry semantic-conventions v1.41.0.

Bumping the pin requires regenerating this file from the upstream YAML model with Weaver — done in [`ANcpLua/typespec-otel-semconv`](https://github.com/ANcpLua/typespec-otel-semconv) — before updating this repository. Direction is one-way: this repo never invokes Weaver directly.
