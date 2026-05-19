# ANcpLua.OtelConventions.Api — Agent Notes

You're an AI coding agent (Claude Code, Codex, aider, Gemini CLI, …) working on this repo.

This is the **downstream consumer** in a two-repo split. The upstream OpenTelemetry semantic-conventions generator lives at <https://github.com/ANcpLua/typespec-otel-semconv> and publishes `@ancplua/typespec-otel-semconv` (Weaver-based). This repo publishes `@o-ancpplua/otel-conventions-api` to GitHub Packages — qyl's API surface for OpenTelemetry-shaped TypeSpec definitions plus domain models, routes, and four local emitters.

Direction is one-way: this repo never invokes Weaver. Only the generator touches upstream YAML.

## Surfaces

| File | Role |
| --- | --- |
| `main.tsp` | **Local-development** entry. Pulls in `emit-config.tsp` + `emit-duckdb.tsp` which depend on the local `file:` emitter devDependencies. **Not shipped.** |
| `index.tsp` | **Published** entry. Same imports as `main.tsp` minus emit routing. This is what `import "@o-ancpplua/otel-conventions-api"` resolves to. |
| `otel/otel-conventions.tsp` | Barrel for `import "@o-ancpplua/otel-conventions-api/otel"`. |
| `generated/otel-keys.gen.tsp` | **Read-only.** Hand-copied from the upstream generator until the lockstep flip lands. Do not edit; do not regenerate from this repo. |
| `emitters/{csharp,duckdb,ts-types,otelconventions-lint}/` | Local TypeSpec emitters. Built by `npm run build:emitters`; not shipped. |

## Lint surfaces

Both must stay green:

```bash
npm run lint          # full surface; compiles main.tsp with emitters
npm run lint:public   # published surface; compiles index.tsp standalone (no emitter devDependencies)
```

`lint:public` is the regression gate that catches accidentally pulling a build-only import into the published surface. If you add a new top-level `.tsp` and want it shipped, add it to `package.json#files` *and* import it from `index.tsp`. If it's build-only, leave it out of `files` and import from `main.tsp` only.

## Tarball boundary

`package.json#files` is an explicit allowlist — no `*.tsp` glob at the root, so build-only top-level files (`main.tsp`, `emit-config.tsp`, `emit-duckdb.tsp`) stay out of the tarball. Verify before publishing:

```bash
npm pack --dry-run
```

The tarball should contain `index.tsp`, `otel/`, `api/`, `common/`, `intelligence/`, `models/`, `generated/*.tsp` + `generated/README.md`, `tspconfig.yaml`, `README.md`, `VERSIONING.md`, `LICENSE`. Nothing else.

## Exports map

Subpath imports are explicit. Adding a new directory consumers should reach into requires both a `files` entry *and* an `exports` entry. Nested directories (`models/agent/*`, `intelligence/seed/*`) need their own export lines — they don't fall under the parent `./models/*` or `./intelligence/*` rules.

## Peer dep

`@typespec/compiler: ^1.11.0 || >=1.12.0-dev.0`. Don't loosen this to `>=1.0.0` again — the locked transitive TypeSpec deps require `^1.10.0`/`^1.11.0`, so a permissive peer would just let consumers fail at compile time.

## Publishing

GitHub Packages npm (`https://npm.pkg.github.com`), scope `@o-ancpplua`, OIDC trusted-publishing — no `NPM_TOKEN` in repo secrets. The publish flow:

1. Cut a GitHub Release (or `workflow_dispatch` with optional `tag` input matching `^[A-Za-z0-9._-]+$`).
2. `.github/workflows/publish.yml` runs: `npm ci`, `build:emitters`, full `lint`, `lint:public`, then `npm publish --access public --provenance --tag <resolved>`.
3. Prereleases auto-route to the `next` dist-tag; stable releases go to `latest`. Manual `inputs.tag` overrides both.

The `github-packages` environment must exist in repo settings before the first run.

## Commit / PR conventions

- Conventional Commits with required scope: one of `dashboard`, `ingestion`, `mcp`, `loom`, `infra`. Workflow / package / publish changes use `chore(infra)`.
- PR title is checked by CodeRabbit; bare `chore:` will fail.
- Renovate handles all dependency bumps. Don't manually `npm install` to bump versions.
- The Apache-2.0 LICENSE is in `files` and shipped. Don't change the license header without flagging it.

## Nuke (planned)

The `ANcpLua.OpenTelemetry.Conventions.Nuke` shared package (repo: O-ANcppLua/ANcpLua.OpenTelemetry.Conventions.Nuke) will land an `IDomainConventionsApi` component that this repo's `Build.cs` will implement. Targets: `RestoreTypeSpecDeps`, `VerifyKeysLockstep` (assert `generated/otel-keys.gen.tsp` matches the locked `@ancplua/typespec-otel-semconv` version), `CompileDomainSpec`, `EmitAll`, `VerifyEmitDeterministic`, `BuildCSharpEmit`, `VerifyNoManualEditsToGenerated`, `PackApiPackage`, `PublishApiPackage`. Until that lands, the npm scripts above are the source of truth.

## What not to do

- Don't add new top-level `.tsp` files without deciding whether they're build-only (`main.tsp` only, exclude from `files`) or published (`index.tsp` import + `files` entry + `exports` entry).
- Don't regenerate `generated/otel-keys.gen.tsp` from this repo — it's produced upstream.
- Don't add `emit-*.tsp` imports to `index.tsp`. They depend on `file:` devDependencies that consumers don't have.
- Don't replace the explicit `files` allowlist with `*.tsp` — that's the bug the current shape fixes.
- Don't bump the `@typespec/compiler` peer without checking the transitive ranges in `package-lock.json` first.
