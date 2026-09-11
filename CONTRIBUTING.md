# Contributing to qyl-api-schema

The consumer-facing overview is the [README](README.md); this file is the working side.

## Develop

Development and CI use Node.js 24 LTS. Published npm artifacts support maintained
Node.js releases from 22 onward.

```bash
npm ci
npm run lint
npm run lint:public
npm run compile
./build.sh Check
```

Important generated outputs include:

- `generated/openapi/qyl.openapi.json`
- `generated/json-schema/qyl-api-schema.json`
- `generated/contracts/**/*.cs`
- `generated/ts-types/**`

Generated files are not editing surfaces. OpenAPI comes from the official TypeSpec
emitter; the bundled JSON Schema is a deterministic projection of its component
schemas and exposes inline route bodies as stable
`Operations.<operationId>.Request` and
`Operations.<operationId>.Response.<status>` definitions. Both artifacts preserve
the same wire names. Change TypeSpec or the owning generator and regenerate.

## Publish

GitHub Actions publishes both registries through OIDC trusted publishing. A release
tag supplies one version for npm and NuGet. The workflow validates and packs first,
publishes in an ordered restartable sequence, waits for indexed artifacts, and then
smokes clean consumers. No long-lived npm or NuGet token is stored.
