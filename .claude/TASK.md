# TASK — Resolve all 6 Dependabot alerts → clean-tree release v0.2.2 (npm + NuGet)

Status: **IN PROGRESS** (started 2026-06-30). Prior task (synced OIDC trusted publishing, v0.2.1)
is COMPLETE & VERIFIED — see git history / PRs #64,#66,#70,#74-#78.

## End goal
`ANcpLua/qyl-api-schema` shows **0 open** "Security and quality" (Dependabot) alerts, and a new
dual-registry release **v0.2.2** is published (npm `@ancplua/qyl-api-schema` + NuGet
`Qyl.Api.Contracts`), both live and lockstep.

## Context (verified 2026-06-30)
6 open alerts, all **transitive npm dev/build-tooling deps** in committed lockfiles — NOT deps that
reach consumers (shipped artifacts are `.tsp` files for npm + generated C# DTOs for the NuGet):
- `tar` <= 7.5.15 (patched 7.5.16; latest 7.5.19) — via `@typespec/compiler@1.13.0` (`tar: ^7.5.13`)
  - root `package-lock.json` (#22), `emitters/csharp` (#15), `emitters/ts-types` (#19), `emitters/otelconventions-lint` (#18)
- `vite` 8.0.0-8.0.15 (patched 8.0.16) — via `vitest` (`vite: ^6||^7||^8`)
  - `emitters/otelconventions-lint` (#16 HIGH 8.2, #17 MOD 5.5). Root already has vite 8.1.0 (clean).

Both parent ranges are carets → `npm update --package-lock-only` moves the pins; no `overrides` needed.

## Versioning (DO NOT hand-bump)
Tag-derived (CI-owned, commit 35c956c). `package.json` = `0.0.0-development`; csproj reads package.json
at pack time; `publish.yml` stamps BOTH npm + NuGet from the git tag. So the ONLY version action is
creating the `v0.2.2` tag/release. No version files change in the PR.

## Plan / checklist
- [x] Branch `fix/dependabot-tar-vite-lockfiles` off green main (main currently green @ d38826f)
- [ ] Bump `tar` in 4 lockfiles + `vite` in otelconventions-lint via per-dir `npm update --package-lock-only`
- [ ] Verify minimal diff (only tar/vite moved) + resolved versions >= patched in EVERY lockfile
- [ ] Verify emitter lockfiles independently (root `npm ci` does NOT exercise them)
- [ ] Local `npm ci` + `npm run build:emitters` + `npm run lint` + `npm run lint:public` green (or rely on Nuke CI)
- [ ] Commit, push, open PR (honest dev-dep framing)
- [ ] CodeRabbit + Nuke `./build.sh Check` CI green → merge (public repo, contract-authorized)
- [ ] Tag + GitHub Release **v0.2.2** → publish.yml fires (NuGet first, npm last)
- [ ] Watch publish run to green; verify npm 0.2.2 AND NuGet 0.2.2 live; all 6 alerts CLOSED

## Honest framing
Resolves 6 Dependabot **dev-dependency** lockfile alerts. Clean-tree release, NOT a patch of a
vulnerability reaching consumers. PR/release body must not over-claim.
