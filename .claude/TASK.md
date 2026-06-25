# TASK — synced npmjs.org + nuget.org trusted publishing (all-or-nothing)

Status: **workflow written; blocked on one-time human setup** · Branch `feat/synced-trusted-publishing` · PR #64
Resume anchor (per the global operating contract). Read this first on resume.

## Goal

Publish both lockstepped artifacts to the **public** registries via **OIDC trusted publishing** (no stored
secrets), released **all-or-nothing**:
- npm `@ancplua/qyl-api-schema` → **registry.npmjs.org**
- nuget `Qyl.Api.Contracts` → **nuget.org**

## What was implemented (this branch)

- `.github/workflows/publish.yml` rewritten: registries → npmjs.org + nuget.org, auth → OIDC,
  `environment: release`, dropped `packages: write` (now `packages: read` for install), kept the
  pack-validate-before-publish lockstep, `--skip-duplicate` on the nuget push.
- `package.json` `publishConfig.registry` → `https://registry.npmjs.org` (routes THIS package's publish to
  npmjs while the committed `.npmrc` keeps `@ancplua` → GitHub Packages for *installing* internal deps).
- npm half: `npm install -g npm@latest` (trusted publishing needs **npm ≥ 11.5.1**, Node ≥ 22.14.0; Node 24
  bundles an older npm). `npm publish` runs with **no NODE_AUTH_TOKEN** (OIDC); provenance is automatic
  (and `--provenance` kept explicit). `repository.url` already matches the `ANcpLua` casing — required.
- nuget half: `NuGet/login@…v1` (`user: ANcpLua`) → 1-hour key → `dotnet nuget push Artifacts/nuget/*.nupkg`
  to `https://api.nuget.org/v3/index.json --skip-duplicate`. Pack output path confirmed: `Artifacts/nuget/`.

## ⚠️ Blocker — npm chicken-and-egg (HUMAN, one-time)

`@ancplua/qyl-api-schema` is **404 on npmjs.org** (only on GitHub Packages today). npm only lets you attach a
trusted publisher to a package that **already exists** on npmjs. So a one-time bootstrap publish is required
**before** the OIDC workflow can ever succeed:

```bash
# locally, once, signed in to an npmjs.org account that owns/will own @ancplua:
npm login
npm ci && npm run compile          # generate generated/ so the package is complete
npm publish --access public        # publishConfig.registry now = npmjs, so this goes to npmjs.org
```
(nuget.org has **no** such requirement — its policy can predate the package; the first OIDC push creates it.)

## YOUR one-time setup (web consoles — no API, no secrets)

**npmjs.com** → package `@ancplua/qyl-api-schema` → Settings → Trusted Publisher (GitHub Actions):
Org/user `ANcpLua` · Repository `qyl-api-schema` · Workflow filename `publish.yml` · Environment `release`
(Casing must match the GitHub URL — `ANcpLua`. A mismatch = opaque 404 on publish.)

**nuget.org** → username → Trusted Publishing → Create:
Policy Name `Qyl.Api.Contracts` · Package Owner `ANcpLua` · Repository Owner `ANcpLua` ·
Repository `qyl-api-schema` · Workflow File `publish.yml` (filename only) · Environment `release`

## Checklist

- [x] Branch + task-state.
- [x] Nuke `PackContractsNuget` output path → `Artifacts/nuget/*.nupkg`.
- [x] npm OIDC requirements verified (npm ≥ 11.5.1 / Node ≥ 22.14; provenance auto; no token; publishConfig.registry).
- [x] Rewrite `publish.yml` + flip `publishConfig.registry`.
- [ ] **(You)** bootstrap-publish `@ancplua/qyl-api-schema` to npmjs once.
- [ ] **(You)** create the npmjs + nuget.org trusted-publisher policies above.
- [ ] Test-publish (cut a release) to validate the OIDC path end-to-end — the only true validation; cannot be proven locally.
- [ ] On green: PR review→merge.

## Verification risks to watch on the first real publish

- npm routing: `publishConfig.registry=npmjs` should override the `@ancplua` scope map for publish. If the
  first publish lands on GitHub Packages instead, force it with `npm publish --@ancplua:registry=https://registry.npmjs.org`.
- npm version: if "trusted publisher not found / 404", confirm `npm -v` ≥ 11.5.1 ran (the `npm install -g npm@latest` step).

## Out of scope (noted)

- CI-owned tag-derived versioning (current model is file-pinned 0.2.0, lockstepped npm+csproj). Revisit if they drift.
- Keeping the GitHub Packages publish as a mirror — default here is **replace** (customers consume the public registries).
