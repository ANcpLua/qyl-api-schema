# TASK — synced npmjs.org + nuget.org trusted publishing (all-or-nothing)

Status: **in progress** · Branch: `feat/synced-trusted-publishing` · Started 2026-06-25
This file is the resume anchor (per the global operating contract). If a session resumes, read this first.

## Goal

Publish the two lockstepped artifacts to the **public** registries via **trusted publishing (OIDC, no stored
secrets)**, released **all-or-nothing**:
- npm: `@ancplua/qyl-api-schema` → **registry.npmjs.org** (currently → GitHub Packages `npm.pkg.github.com`)
- nuget: `Qyl.Api.Contracts` → **nuget.org** (currently → GitHub Packages)

"All-or-nothing" = a version is only "released" if **both** registries accept it. Never half-publish.

## Current state (verified 2026-06-25)

- `.github/workflows/publish.yml` publishes both to **GitHub Packages** on `release: published` (+ dispatch).
  It already locksteps: packs+validates the C# NuGet **before** the (immutable) npm publish, so a pack failure
  aborts cleanly with nothing published. Keep this ordering.
- Versions are hand-maintained and lockstepped: `package.json` `0.2.0` and `packaging/Qyl.Api.Contracts.csproj`
  `<Version>0.2.0`. (Not tag-derived. Out of scope to change here; noted below.)
- npm side: `publishConfig.provenance: true` already; `id-token: write` already granted.
- nuget side: packed via Nuke `./build.sh PackContractsNuget`, pushed via `./build.sh PublishContractsNuget`.

## Target design

Transform `publish.yml` (keep the trigger + lockstep ordering); swap registries + auth to OIDC:

**nuget half — proven `NuGet/login` pattern (ANcpLua fleet):**
- `permissions: id-token: write`, `environment: release`.
- `NuGet/login@8d196754b4036150537f80ac539e15c2f1028841 # v1` with `user: ANcpLua` → temp 1-hour key.
- `dotnet nuget push <nupkg> --source https://api.nuget.org/v3/index.json --api-key ${{ steps.nuget-login.outputs.NUGET_API_KEY }} --skip-duplicate`.

**npm half — npmjs.org OIDC trusted publishing:**
- `setup-node` with `registry-url: https://registry.npmjs.org`, scope `@ancplua`, `id-token: write`.
- `npm publish --provenance --access public --tag $NPM_DIST_TAG` with **no** `NODE_AUTH_TOKEN` (OIDC).
- `--skip-duplicate`-equivalent: npm rejects re-publishing a version; a re-run after a partial failure must
  only re-push the side that failed.

**All-or-nothing sequencing (keep + extend the current discipline):**
1. Build emitters, lint (full + public surface), compile TypeSpec.
2. Pack **both** artifacts and validate fully — any failure aborts before any publish.
3. Publish npm (immutable) → then `NuGet/login` + push nuget (immutable, `--skip-duplicate`).
4. Residual risk: npm succeeds then nuget push fails (network). Mitigation: nuget `--skip-duplicate` makes a
   re-run idempotent — re-run only pushes nuget, npm is a no-op. Surface loudly; do not silently leave a
   half-released version.

## YOUR one-time setup (the only human-gated step — web consoles, no API)

**nuget.org** → click username → Trusted Publishing → Create:
| Field | Value |
|---|---|
| Policy Name | `Qyl.Api.Contracts` |
| Package Owner | `ANcpLua` |
| Repository Owner | `ANcpLua` |
| Repository | `qyl-api-schema` |
| Workflow File | `publish.yml`  *(file name only — no `.github/workflows/` prefix)* |
| Environment | `release` |
(There is no "package" field — by design; the policy applies to all packages owned by the owner.)

**npmjs.com** → package `@ancplua/qyl-api-schema` → Settings → Trusted Publisher (GitHub Actions):
| Field | Value |
|---|---|
| Organization / user | `ANcpLua` |
| Repository | `qyl-api-schema` |
| Workflow filename | `publish.yml` |
| Environment | `release` |

After both policies exist, re-run the publish job; the first green publish pins each policy permanently.

## Checklist

- [x] Branch + this task-state.
- [ ] Read the Nuke build (`build/`) to find the `PackContractsNuget` output path (the `.nupkg` to push).
- [ ] Verify the npm CLI version that supports OIDC trusted publishing; pin/upgrade npm in the workflow if Node 24's bundled npm is too old.
- [ ] Rewrite `publish.yml`: registries → npmjs.org + nuget.org, auth → OIDC, `environment: release`, drop `packages: write`, keep lockstep ordering + `--skip-duplicate`.
- [ ] (You) create the two trusted-publishing policies above.
- [ ] Test-publish to validate the full OIDC path end-to-end (a real release; can't be proven locally).
- [ ] PR review→merge; cut a release to exercise it.

## Out of scope (noted, not doing here)

- Moving to CI-owned tag-derived versioning (skill recommends it; current model is file-pinned + lockstepped).
  Revisit only if the file-versions drift.
- The existing GitHub Packages publish: decide keep-as-mirror vs replace. Default: replace (customers consume
  the public registries).
