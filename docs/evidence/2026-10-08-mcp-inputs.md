# MCP input contract extension — 2026-10-08

This is point 8 of the owner instructions in
[qyl.mcp's goal](https://github.com/ANcpLua/qyl.mcp/blob/a6192a9e31149b21760ee59e0afc61eddeaf2ac1/goal-objective.md).
Work started after qyl.mcp PR #106 merged. On 2026-10-08,
`gh pr view 106 --repo ANcpLua/qyl.mcp --json mergedAt,mergeCommit,url`
returned merge `a6192a9e31149b21760ee59e0afc61eddeaf2ac1`, at
`2026-10-08T05:50:16Z`. `git rev-parse origin/main` in this schema checkout
returned `9c576b01fc4279fe25a9d1b0927c01b93b66f653`; the branch starts there.

The first branch-switch command accidentally ran from `/private/tmp` after the
clone; Git returned `fatal: not a git repository (or any of the parent directories): .git`,
exit 128. Running `git switch -c codex/mcp-bounded-inputs origin/main` inside
this checkout then succeeded. No reset or existing checkout overwrite occurred.

## Contract choices

`models/mcp-tools.tsp` is the authoring surface, per `cat CONTRIBUTING.md`.
The optional fields preserve existing input validity: `errors_only` defaults
to false, `include_attributes` to true, absent `max_spans` keeps all matching
spans, and `service_prefix` defaults to `qyl-ci`. Explicit `max_spans` accepts
integers 1–1000 after filtering; prefix length is 1–256. These are the contract
choices made in this change, not claims that a downstream server implements them.

On 2026-10-08, `git diff --stat` before this evidence file reported:

```text
 .github/workflows/fallout.yml        |  3 ++-
 bun.lock                            |  8 ++++----
 generated/openapi/qyl.openapi.json   | 24 ++++++++++++++++++++++++
 models/mcp-tools.tsp                 | 20 ++++++++++++++++++++
 package.json                        |  8 ++++----
 scripts/verify-contract-fixtures.mjs | 28 ++++++++++++++++++++++++++++
```

The generated OpenAPI comes from `bun run compile`, not manual edits. The
fixture corpus adds valid old/new requests, false/true flags, count boundaries,
wrong types, wrong wire names and prefix boundaries. The existing Zod-parity
gate replays the same corpus.

## Verification commands and actual output

All commands in this section ran on 2026-10-08 in the schema checkout.
`bun --version` returned `1.4.2`; `node --version` returned `v24.21.0`.
The initial `bun install --frozen-lockfile` exited 0; output:

```text
bun install v1.4.2 (744846f84)

$ bun run build:emitters
$ tsc -p emitters/csharp && tsc -p emitters/ts-types && tsc -p emitters/qyl-lint

+ @types/node@26.4.1
+ @typespec/compiler@1.16.0
+ @typespec/events@0.86.0
+ @typespec/http@1.16.0
+ @typespec/openapi@1.16.0
+ @typespec/openapi3@1.16.0
+ @typespec/sse@0.86.0
+ ajv@8.20.0
+ oxlint@1.83.0
+ oxlint-tsgolint@7.0.2001
+ typescript@7.0.2
+ zod@4.5.4

101 packages installed [1372.00ms]
```

`bun run lint`, `bun run lint:public`, `bun run lint:js`, all exit 0:

```text
$ bun run build:emitters && tsp compile main.tsp --no-emit --warn-as-error
$ tsc -p emitters/csharp && tsc -p emitters/ts-types && tsc -p emitters/qyl-lint
TypeSpec compiler v1.16.0

- Compiling...
✔ Compiling

Compilation completed successfully.

$ bun run build:emitters && tsp compile index.tsp --no-emit --warn-as-error
$ tsc -p emitters/csharp && tsc -p emitters/ts-types && tsc -p emitters/qyl-lint
TypeSpec compiler v1.16.0

- Compiling...
✔ Compiling

Compilation completed successfully.

$ oxlint .
```

`bun run compile`, exit 0, output excerpt:

```text
- Running @ancplua/typespec-emit-csharp...
✔ @ancplua/typespec-emit-csharp 6ms generated/contracts/
- Running @ancplua/typespec-emit-ts-types...
✔ @ancplua/typespec-emit-ts-types 14ms generated/ts-types/
- Running @typespec/openapi3...
✔ @typespec/openapi3 74ms generated/openapi/

Compilation completed successfully.

$ node scripts/emit-contract-revision.mjs
emit-contract-revision: sha256:382526f13652d18b -> generated/contracts/Qyl/Api/ContractRevision.cs, generated/ts-types/api.ts
$ node scripts/openapi-to-json-schema.mjs
$ tsc -p tsconfig.contracts.json
$ tsc -p tsconfig.runtime.json
$ tsc -p tsconfig.zod.json
```

`bun run verify:zod-contracts`, exit 0:

```text
$ bun run build:zod-runtime && node scripts/verify-zod-contracts.mjs
$ tsc -p tsconfig.zod.json
Verified 655 published definitions build as Zod schemas, 97 contract fixtures across 21 definitions agree with the published JSON Schema, and RFC 3339 date-times, 64-bit integers, and inherited object sealing hold.
```

Initial `./build.sh Check`, exit 255, actual failure excerpt:

```text
07:54:19 [ERR] npm error code ERESOLVE
07:54:19 [ERR] npm error ERESOLVE unable to resolve dependency tree
07:54:19 [ERR] npm error
07:54:19 [ERR] npm error While resolving: npm@1.0.0
07:54:19 [ERR] npm error Found: @typespec/sse@0.87.0
07:54:19 [ERR] npm error node_modules/@typespec/sse
07:54:19 [ERR] npm error   peerOptional @typespec/sse@"^0.87.0" from @typespec/openapi3@1.17.0
07:54:19 [ERR] npm error   node_modules/@typespec/openapi3
07:54:19 [ERR] npm error     peerOptional @typespec/openapi3@"^1.16.0" from @ancplua/qyl-api-schema@0.0.0-development
07:54:19 [ERR] npm error     node_modules/@ancplua/qyl-api-schema
07:54:19 [ERR] npm error       @ancplua/qyl-api-schema@"file:../../../../../../../tmp/qyl-api-schema-point8/ancplua-qyl-api-schema-0.0.0-development.tgz" from the root project
07:54:19 [ERR] npm error
07:54:19 [ERR] npm error Could not resolve dependency:
07:54:19 [ERR] npm error peerOptional @typespec/sse@"^0.86.0" from @ancplua/qyl-api-schema@0.0.0-development
07:54:19 [ERR] npm error node_modules/@ancplua/qyl-api-schema
07:54:19 [ERR] npm error   @ancplua/qyl-api-schema@"file:../../../../../../../tmp/qyl-api-schema-point8/ancplua-qyl-api-schema-0.0.0-development.tgz" from the root project
07:54:19 [ERR] npm error
```

The published optional peer ranges allowed TypeSpec 1.17's OpenAPI emitter,
whose 0.87 SSE peer conflicts with this package's 0.86 SSE range. The consumer
probe correctly failed before importing the package. The fix narrows the four
1.x TypeSpec peer ranges to `~1.16.0`, matching the installed/tested toolchain;
the 0.x ranges already stay within their minor. No forced install, legacy peer
resolution or consumer-check removal was used.

After that manifest change, `bun install` updated only the four root peer
ranges in `bun.lock`. Actual output, exit 0:

```text
bun install v1.4.2 (744846f84)
Saved lockfile

$ bun run build:emitters
$ tsc -p emitters/csharp && tsc -p emitters/ts-types && tsc -p emitters/qyl-lint

Checked 108 installs across 147 packages (no changes) [351.00ms]
```

The unchanged command `./build.sh Check` then exited 0. Actual final summary:

```text
Target                             Status      Duration
───────────────────────────────────────────────────────
CleanContractsEmit                 Succeeded     < 1sec
RestoreTypeSpecDeps                Succeeded     < 1sec
CompileDomainSpec                  Succeeded     < 1sec
VerifyGeneratedArtifactsCurrent    Succeeded     < 1sec
PackContractsNuget                 Succeeded       0:01
VerifyEmitDeterministic            Succeeded       0:01
PackApiPackage                     Succeeded       0:02
VerifyPackedConsumers              Succeeded       0:08
LintFullSurface                    Succeeded     < 1sec
VerifyLintRules                    Succeeded     < 1sec
VerifyContractFixtures             Succeeded     < 1sec
VerifyZodContracts                 Succeeded       0:01
VerifyRouteContracts               Succeeded     < 1sec
EmitTsTypes                        Succeeded     < 1sec
EmitCSharp                         Succeeded     < 1sec
───────────────────────────────────────────────────────
Total                                              0:20
═══════════════════════════════════════════════════════
​
Build succeeded on 08.10.2026 07:55:56. ＼（＾ᴗ＾）／
```

The complete gate still covers deterministic emission, generated drift, fixture
validation, Zod parity, route contracts, lint rules, npm/NuGet packing and clean
consumers. The workflow job ID changes from `check` to `verify` solely to match
the owner's required check name; it still runs the same `./build.sh Check`.
On 2026-10-08, `gh api repos/ANcpLua/qyl-api-schema/rules/branches/main` returned
`[]`; the classic required-status-checks endpoint returned `Branch not protected`
(404). This change does not treat that as permission to bypass the owner's four
required checks. No owner-review status is set by this work.

`git diff --check` returned no output, exit 0. Own review found no concrete
regression in the optional contract fields or the regenerated output.

## Release boundary

`gh release view --repo ANcpLua/qyl-api-schema --json tagName,publishedAt,targetCommitish,url`
on 2026-10-08 returned `v11.2.0`, published `2026-09-17T11:07:10Z`,
[release record](https://github.com/ANcpLua/qyl-api-schema/releases/tag/v11.2.0).
No release, tag push, registry publication or publish workflow was invoked.
The qyl.mcp dependency bump and implementation require an owner-published
release containing this change; this PR alone does not provide that package.
