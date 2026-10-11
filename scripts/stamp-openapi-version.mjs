/**
 * Stamps the release version into the OpenAPI document of the package being
 * packed.
 *
 * The release tag is this contract's only version source: the local publish writes it
 * into package.json (`npm version`), and `prepack` runs this script after
 * `bun run compile`, so the packed `generated/openapi/qyl.openapi.json` names the
 * version it ships as. `postpack` runs it again with `--reset`, which puts back
 * the `0.0.0` TypeSpec emits for a source that declares no version, so the
 * tracked document stays a fresh emit and a local pack leaves no diff. The
 * contract revision ignores `info.version` (scripts/emit-contract-revision.mjs),
 * so stamping never changes it.
 *
 *   node scripts/stamp-openapi-version.mjs           0.0.0 -> package.json version
 *   node scripts/stamp-openapi-version.mjs --reset   package.json version -> 0.0.0
 */
import { readFile, writeFile } from "node:fs/promises";
import { openApiPath } from "./lib/openapi.mjs";

// TypeSpec's info.version for a source without one. Any other value means the
// source declared a version, and the tag would no longer be the only source.
const emittedVersion = "0.0.0";

const flags = process.argv.slice(2);
const unknown = flags.filter((flag) => flag !== "--reset");
if (unknown.length > 0) {
  throw new Error(`stamp-openapi-version: unknown argument(s) ${unknown.join(", ")}`);
}
const reset = flags.includes("--reset");

const { version: packageVersion } = JSON.parse(await readFile("package.json", "utf8"));
if (typeof packageVersion !== "string" || packageVersion.length === 0) {
  throw new Error("stamp-openapi-version: package.json has no version.");
}

const serialize = (value) => `${JSON.stringify(value, null, 2)}\n`;
const text = await readFile(openApiPath, "utf8");
const document = JSON.parse(text);
// The rewrite must change one value and nothing else, so the document has to
// already be in the emitter's own serialization.
if (serialize(document) !== text) {
  throw new Error(`stamp-openapi-version: ${openApiPath} is not a fresh emit; run \`bun run compile\`.`);
}

const current = document.info?.version;

// `--reset` after a pack whose prepack never stamped (or a second reset) finds
// the emitted value already in place, which is the state it exists to restore.
function resetTarget() {
  if (current === emittedVersion || current === packageVersion) return emittedVersion;
  throw new Error(
    `stamp-openapi-version: info.version is '${current}', neither the stamped '${packageVersion}' nor '${emittedVersion}'.`,
  );
}

function stampTarget() {
  if (current === emittedVersion) return packageVersion;
  throw new Error(
    `stamp-openapi-version: info.version is '${current}', not TypeSpec's '${emittedVersion}'. ` +
      "The release tag is the only version source; remove the version from the TypeSpec source.",
  );
}

const target = reset ? resetTarget() : stampTarget();
if (target !== current) {
  document.info.version = target;
  await writeFile(openApiPath, serialize(document));
}
console.log(`stamp-openapi-version: ${openApiPath} info.version ${current} -> ${target}`);
