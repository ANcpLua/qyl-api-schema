// =============================================================================
// @ancplua/typespec-qyl-lint — the qyl contract invariants, machine-checked
// =============================================================================
// Loaded by name from tspconfig.yaml (`linter.extends`), never imported by a
// .tsp file. That matters: the published entry point index.tsp stays free of
// build-only dependencies, while this repo's `lint` and `lint:public` gates
// still enforce every invariant on exactly the source that gets published.
//
//   wire-name-snake-case          one casing convention for JSON body keys
//   http-param-snake-case         the same convention for query/path params
//   identity-binding              one identity: one scalar, one name, one key
//   identity-edge-typed           an identity edge is a declared scalar
//   confusable-identity-documented  look-alike identities declare their relation
// =============================================================================

import { createTypeSpecLibrary, defineLinter } from "@typespec/compiler";
import { confusableIdentityDocumentedRule } from "./rules/confusable-identity-documented.js";
import { httpParamSnakeCaseRule } from "./rules/http-param-snake-case.js";
import { identityBindingRule } from "./rules/identity-binding.js";
import { identityEdgeTypedRule } from "./rules/identity-edge-typed.js";
import { wireNameSnakeCaseRule } from "./rules/wire-name-snake-case.js";

export const $lib = createTypeSpecLibrary({
  name: "@ancplua/typespec-qyl-lint",
  diagnostics: {},
} as const);

export const $linter = defineLinter({
  rules: [
    wireNameSnakeCaseRule,
    httpParamSnakeCaseRule,
    identityBindingRule,
    identityEdgeTypedRule,
    confusableIdentityDocumentedRule,
  ],
});

export * from "./policy.js";
