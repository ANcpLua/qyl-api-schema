# TASK — synced npmjs.org + nuget.org trusted publishing (all-or-nothing)

Status: **COMPLETE & VERIFIED** — first synced OIDC release `v0.2.1` published to npmjs.org + nuget.org (2026-06-26).
npm `@ancplua/qyl-api-schema@0.2.1` (latest, provenance) and nuget `Qyl.Api.Contracts 0.2.1` both live; trusted-publisher
policies on both registries. Original work: PR #64 (merged). Fixes: PR #66 (merged). Release bump: PR #70 (merged).

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
# locally, once, signed in to the npmjs.org user `ancplua` (the @ancplua scope = that user's
# personal scope; the user exists with 0 orgs, so NO npm org is needed):
npm login
npm ci && npm run compile          # generate generated/ so the package is complete
# IMPORTANT: publishConfig.registry does NOT win over the committed .npmrc @ancplua scope map
# (verified via `npm publish --dry-run` -> it routed to npm.pkg.github.com). Force npmjs explicitly:
npm publish --access public --provenance=false --@ancplua:registry=https://registry.npmjs.org
# (--provenance=false because provenance can only be generated in CI; a local publish errors otherwise.)
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
- [x] **Fixed `npm ci` build race** — the four emitter `prepare: tsc -p .` scripts ran concurrently
      (npm builds file: deps in parallel, ignoring inter-dep order), so `otelconventions-lint` compiled
      against `@qyl/telemetry-control-graph` before its `dist/` existed → TS2307 (+ 3 cascade errors).
      Removed the per-emitter `prepare`; added a single ordered root `prepare: npm run build:emitters`.
      Verified: clean `npm ci` + `npm run lint` + `npm run lint:public` + `./build.sh Check` all green.
- [x] **Fixed npm publish routing** — `npm publish --dry-run` proved `publishConfig.registry` does NOT
      win over the `.npmrc` @ancplua scope map (it routed to npm.pkg.github.com). `publish.yml` now passes
      `--@ancplua:registry=https://registry.npmjs.org` on the publish step.
- [x] Confirmed npm user `ancplua` exists (0 pkgs, 0 orgs) → publishes under personal user scope, no org needed.
- [x] Authenticated to npmjs (user `ancplua`, WebAuthn) and nuget.org (Sign in with Microsoft).
- [x] **Bootstrap-published** `@ancplua/qyl-api-schema@0.2.0` to npmjs.org (web-2FA via PTY; registry 200, `+ @ancplua/qyl-api-schema@0.2.0`).
- [x] **Created npmjs trusted-publisher**: `ANcpLua/qyl-api-schema` · `publish.yml` · env `release` · allow `npm publish`.
- [x] **Created nuget.org trusted-publisher**: `Qyl.Api.Contracts` · owner `ANcpLua` · `ANcpLua/qyl-api-schema` · `publish.yml` · env `release` (Active, IDs pinned).
- [x] Bumped 0.2.0 → 0.2.1 lockstep (package.json + package-lock + packaging/Qyl.Api.Contracts.csproj) — fresh version for the first OIDC release (npm 0.2.0 already taken by bootstrap; npm has no --skip-duplicate).
- [x] Cut release `v0.2.1` → publish workflow run 28229011375 succeeded (all steps green, OIDC, no secrets).
- [x] Confirmed live: npm `@ancplua/qyl-api-schema@0.2.1` (latest + provenance attestations) on npmjs.org;
      nuget `Qyl.Api.Contracts 0.2.1` on nuget.org (flat-container). Both via OIDC trusted publishing.

## Verification risks to watch on the first real publish

- npm routing: CONFIRMED `publishConfig.registry` is overridden by the `@ancplua` scope map. Both the
  bootstrap and `publish.yml` now force `--@ancplua:registry=https://registry.npmjs.org`. Do not remove it.
- npm version: if "trusted publisher not found / 404", confirm `npm -v` ≥ 11.5.1 ran (the `npm install -g npm@latest` step).
- npm version collision: bootstrap publishes 0.2.0; the OIDC validation release MUST use a fresh version
  (bump package.json + packaging/Qyl.Api.Contracts.csproj to 0.2.1 in lockstep) or `npm publish` hard-fails
  on the duplicate (npm is immutable; nuget push has --skip-duplicate but npm has no equivalent).

## Out of scope (noted)

- CI-owned tag-derived versioning (current model is file-pinned 0.2.0, lockstepped npm+csproj). Revisit if they drift.
- Keeping the GitHub Packages publish as a mirror — default here is **replace** (customers consume the public registries).
