# Changelog

`@ancplua/qyl-api-schema` (npm) and `Qyl.Api.Contracts` (NuGet), released together. Each entry becomes the GitHub release notes of its tag; releases before 12.1.0 keep GitHub's generated notes.

## 13.0.0 — 2026-10-16

- Remove unsupported runner resource kinds `stdio`, `http` and `inproc`. The process runner exposes `collector`, `project` and `command`; MCP transports, initialization and tool discovery remain in the Workbench API.
- Remove the runner's never-populated `server_identity`, `tool_count` and `restarts` fields. Process restart actions remain supported. Read MCP server identity and discovered tools from Workbench connection and discovery snapshots.
- Verify the runner's exact wire shape and retained MCP contracts in clean npm and NuGet consumers.
- Probe npmjs.org explicitly when checking the published version, including the scoped registry override.

## 12.1.2 — 2026-10-14

- docs: state defaults, accepted values and paging in the MCP tool inputs
- docs: drop CLAUDE.md; AGENTS.md is the one instruction file
- skill: drop the Codex hand-off file from the release steps

## 12.1.1 — 2026-10-12

- fix: align analysis paging, matcher limits and failure status contracts

## 12.1.0 — 2026-10-12

- feat: define typed contracts for the 32-tool investigation surface
- docs: SKILL.md: the dry run is optional; release.sh refuses before publishing
- docs: SKILL.md: the versions snapshot is rewritten by refresh-published-versions.sh
- docs: punctuate consumer dependency list
- docs: separate shared telemetry registry from API contracts
- docs: SKILL.md names the Railway deployment-state command
- docs: CONTRIBUTING names the one local gate instead of the removed pull-request workflows
- docs: AGENTS.md: no CI, review or approval gates a push; the gate is the local command in SKILL.md
- docs: SKILL.md: release, re-pin and agent hand-off procedure; AGENTS.md points to it
- chore: release.sh reads the shared qyl-dev NuGet key
- chore: release.sh publishes and releases from this machine
- chore: publish from the developer machine; push to main directly
- ci(publish): accept commits reachable from a release/* branch; AGENTS.md names the release-branch rule (#52)

