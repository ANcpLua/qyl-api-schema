// =============================================================================
// Prove the contract invariants are actually enforced, not merely declared.
// =============================================================================
// A linter whose rules match nothing passes exactly like a clean tree. This gate
// removes that failure mode by asserting three things:
//
//   1. the library's `all` ruleset enables every rule it declares
//   2. the negative fixture is rejected, with at least one diagnostic per rule
//   3. no rule from @typespec/http/all fires on the fixture's own constructs,
//      so `--warn-as-error` on the product tree cannot go red for an unrelated
//      reason and be mistaken for one of ours
//
// The product tree passing `lint`/`lint:public` is the positive case; this is
// the negative one.
// =============================================================================

import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const library = "@ancplua/typespec-qyl-lint";
const fixture = "emitters/qyl-lint/test/violations.tsp";

// --- 1. the `all` ruleset covers every declared rule --------------------------

const { $linter } = await import(`${library}/`).catch(() => import(resolve(root, "emitters/qyl-lint/dist/index.js")));
const declared = $linter.rules.map((rule) => rule.name);
if (declared.length === 0) throw new Error("The linter declares no rules.");

// TypeSpec synthesises an `all` ruleset enabling every rule when a linter
// defines none explicitly. Assert that rather than trusting it: if a ruleSets
// block is ever added by hand, a rule silently dropped from it would disable
// the invariant everywhere with no other symptom.
const explicit = $linter.ruleSets?.all?.enable;
if (explicit !== undefined) {
  const missing = declared.filter((name) => explicit[`${library}/${name}`] !== true);
  if (missing.length > 0) {
    throw new Error(`Rules declared but not enabled by the 'all' ruleset: ${missing.join(", ")}.`);
  }
}

// --- 2. the negative fixture is rejected, rule by rule ------------------------

const result = spawnSync(
  process.execPath,
  [resolve(root, "node_modules/@typespec/compiler/entrypoints/cli.js"), "compile", fixture, "--no-emit", "--warn-as-error"],
  { cwd: root, encoding: "utf8" },
);
const output = `${result.stdout ?? ""}${result.stderr ?? ""}`;

if (result.status === 0) {
  throw new Error(
    `${fixture} compiled cleanly. The negative fixture must be rejected — the rules are not firing.`,
  );
}

const silent = declared.filter((name) => !output.includes(`${library}/${name}`));
if (silent.length > 0) {
  throw new Error(
    `No diagnostic from: ${silent.join(", ")}. Every rule must be exercised by ${fixture}, ` +
    `otherwise it can rot into a no-op without any gate noticing.\n\n${output}`,
  );
}

// --- 3. nothing orthogonal is masquerading as one of ours ---------------------

const foreign = [...output.matchAll(/ - (?:error|warning) (@typespec\/[a-z0-9-]+\/[a-z0-9-]+)/gu)]
  .map((match) => match[1]);
if (foreign.length > 0) {
  throw new Error(
    `@typespec rules fired on the fixture: ${[...new Set(foreign)].join(", ")}. ` +
    `Keep the fixture free of unrelated violations so a red gate always means a qyl invariant broke.`,
  );
}

const counts = declared
  .map((name) => `${name} ×${output.split(`${library}/${name}`).length - 1}`)
  .join(", ");
console.log(`Verified ${declared.length} lint rules reject ${fixture}: ${counts}.`);
