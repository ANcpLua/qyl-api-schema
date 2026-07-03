# TASK — Resolve all 6 Dependabot alerts → clean-tree release v0.2.2 (npm + NuGet)

Status: **COMPLETE & VERIFIED** (2026-06-30; re-verified 2026-07-03). Prior task (synced OIDC
trusted publishing, v0.2.1) also COMPLETE — see git history / PRs #64,#66,#70,#74-#78.

No task is currently in progress in this repo.

## End goal — MET
`ANcpLua/qyl-api-schema` shows **0 open** "Security and quality" (Dependabot) alerts, and the
dual-registry release **v0.2.2** is published (npm `@ancplua/qyl-api-schema` + NuGet
`Qyl.Api.Contracts`), both live and lockstep.

## Evidence (verified 2026-07-03)
- PR #80 (lockfile tar & vite bumps) merged to main.
- GitHub Release v0.2.2 published 2026-06-30T13:54:58Z; `publish.yml` run "v0.2.2 — resolve all
  6 Dependabot alerts": success.
- npmjs `@ancplua/qyl-api-schema` dist-tag latest = 0.2.2; nuget.org `Qyl.Api.Contracts`
  index lists 0.2.2.
- Dependabot open alerts: 0.

## Checklist — all done
- [x] Branch `fix/dependabot-tar-vite-lockfiles` off green main
- [x] Bump `tar` in 4 lockfiles + `vite` in otelconventions-lint via per-dir `npm update --package-lock-only`
- [x] Verify minimal diff + resolved versions >= patched in every lockfile
- [x] Verify emitter lockfiles independently
- [x] Local build/lint gates green
- [x] Commit, push, PR #80 (honest dev-dep framing)
- [x] CodeRabbit + Nuke CI green → merged
- [x] Tag + GitHub Release v0.2.2 → publish.yml fired (NuGet first, npm last)
- [x] Publish run green; npm 0.2.2 AND NuGet 0.2.2 live; all 6 alerts CLOSED

## Versioning (still true — DO NOT hand-bump)
Package version is tag-derived and CI-owned: `package.json` stays `0.0.0-development`, the csproj
carries no `<Version>`, and `publish.yml` stamps both registries from the git tag. The only
version action for a release is creating the tag/GitHub Release.
