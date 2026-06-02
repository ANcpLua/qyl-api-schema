#!/usr/bin/env node
// apply-otel-keys.mjs
//
// Replace hand-typed `@encodedName("application/json", "<dotted.otel.key>")` with
// `@encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.<Domain>.<Ident>)` in qyl
// TypeSpec source files.
//
// The mapping comes from generated/otel-keys.gen.tsp, which is generated from
// the pinned upstream OTel registry before extraction. Hand-edit of semantic
// convention keys is forbidden; update the generated projection first.
//
// The script only rewrites keys that exist in the generated map. Non-OTel
// snake_case keys (e.g. "workflow_id", "access_token") are qyl-internal JSON
// serialization names and are left as string literals.
//
// Usage:
//   node scripts/apply-otel-keys.mjs            # rewrite all .tsp
//   node scripts/apply-otel-keys.mjs --dry-run  # report only
//   node scripts/apply-otel-keys.mjs path/to/file.tsp [...more]
//
// Idempotent — re-running produces no diff once all keys are migrated.

import { readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, relative, resolve } from "node:path";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const SPECS_ROOT = resolve(SCRIPT_DIR, "..");
const GENERATED = join(SPECS_ROOT, "generated", "otel-keys.gen.tsp");

const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const explicitFiles = args.filter((a) => !a.startsWith("--"));

// ── Build {dotted.key → "ANcpLua.OpenTelemetry.SemanticConventions.Keys.<Domain>.<Ident>"} from the generated TSP.
let generated;
try {
  generated = readFileSync(GENERATED, "utf8");
} catch (err) {
  console.error(`No consts parsed from ${GENERATED}. Regenerate generated/otel-keys.gen.tsp first.`);
  process.exit(1);
}
const keyMap = new Map();
const nsRe = /^namespace (ANcpLua\.OpenTelemetry\.SemanticConventions\.Keys\.[A-Za-z0-9]+) \{/;
const constRe = /^\s*const ([A-Z][A-Za-z0-9_]+): string = "([^"]+)"/;
let currentNs = null;
for (const line of generated.split("\n")) {
  const ns = line.match(nsRe);
  if (ns) {
    currentNs = ns[1];
    continue;
  }
  const c = line.match(constRe);
  if (c && currentNs) keyMap.set(c[2], `${currentNs}.${c[1]}`);
}
if (keyMap.size === 0) {
  console.error(`No consts parsed from ${GENERATED}. Regenerate generated/otel-keys.gen.tsp first.`);
  process.exit(1);
}
console.log(`Loaded ${keyMap.size} OTel key consts from ${relative(SPECS_ROOT, GENERATED)}`);

// ── Resolve target file list.
function walk(dir, out = []) {
  for (const e of readdirSync(dir)) {
    if (e === "node_modules" || e === "generated" || e.startsWith(".")) continue;
    const p = join(dir, e);
    const s = statSync(p);
    if (s.isDirectory()) {
      walk(p, out);
    } else if (
      e.endsWith(".tsp") &&
      !e.startsWith("main") &&
      !e.startsWith("emit-")
    ) {
      out.push(p);
    }
  }
  return out;
}

const files =
  explicitFiles.length > 0 ? explicitFiles.map((f) => resolve(f)) : walk(SPECS_ROOT);

// ── Rewrite. Permissive regex: tolerate whitespace and newlines between args.
const replaceRe = /@encodedName\(\s*"application\/json"\s*,\s*"([^"]+)"\s*\)/g;

let totalReplacements = 0;
let totalSkipped = 0;
const perFile = [];
const skippedKeys = new Map();
for (const file of files) {
  const before = readFileSync(file, "utf8");
  let count = 0;
  const after = before.replace(replaceRe, (full, key) => {
    if (keyMap.has(key)) {
      count++;
      return `@encodedName("application/json", ${keyMap.get(key)})`;
    }
    // non-OTel snake_case key — leave alone but track for reporting.
    if (key.includes(".")) {
      skippedKeys.set(key, (skippedKeys.get(key) ?? 0) + 1);
      totalSkipped++;
    }
    return full;
  });
  if (count > 0) {
    if (!dryRun) writeFileSync(file, after);
    perFile.push([relative(SPECS_ROOT, file), count]);
    totalReplacements += count;
  }
}

perFile.sort((a, b) => b[1] - a[1]);
console.log(
  `\n${dryRun ? "[dry-run] " : ""}Replaced ${totalReplacements} references across ${perFile.length} files:`,
);
for (const [f, c] of perFile) console.log(`  ${c.toString().padStart(4)}  ${f}`);

if (skippedKeys.size > 0) {
  console.log(
    `\nDotted keys not in the OTel map (left as literals — likely qyl-specific or upstream-typo):`,
  );
  for (const [k, c] of [...skippedKeys].sort((a, b) => b[1] - a[1])) {
    console.log(`  ${c.toString().padStart(4)}  ${k}`);
  }
}
