import { spawnSync } from "node:child_process";
import { access, readFile } from "node:fs/promises";
import { dirname, join, posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { verifyConsumers } from "./verify-consumers.mjs";

const [version, npmTarballArgument, nugetPackageArgument] = process.argv.slice(2);
if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(version ?? "") ||
    !npmTarballArgument?.endsWith(".tgz") ||
    !nugetPackageArgument?.endsWith(".nupkg")) {
  throw new Error("usage: node scripts/verify-packed.mjs <version> <npm-tarball.tgz> <nuget-package.nupkg>");
}

const npmTarball = resolve(npmTarballArgument);
const nugetPackage = resolve(nugetPackageArgument);
await Promise.all([access(npmTarball), access(nugetPackage)]);

const repoRoot = fileURLToPath(new URL("../", import.meta.url));

// package.json#files is a hand-maintained allow-list, so a TypeSpec file that an
// export root imports can be absent from the tarball while `npm pack` succeeds
// and the consumer probe, which compiles the published TypeSpec, is the first to
// fail. 11.5.0 shipped without models/metrics.tsp that way. Walk every relative
// `import "./..."` reachable from the TypeSpec export roots and require each one
// in the tarball itself, not in a dry-run listing of the working tree.
async function verifyTypeSpecImportClosure(tarball) {
  const manifest = JSON.parse(await readFile(join(repoRoot, "package.json"), "utf8"));
  const roots = Object.values(manifest.exports ?? {})
    .map((entry) => entry?.typespec)
    .filter((entry) => typeof entry === "string")
    .map((entry) => posix.normalize(entry));
  if (roots.length === 0) throw new Error("package.json#exports declares no TypeSpec entry point.");

  const reachable = new Set();
  const queue = [...roots];
  while (queue.length > 0) {
    const file = queue.shift();
    if (reachable.has(file)) continue;
    reachable.add(file);
    const source = await readFile(join(repoRoot, file), "utf8");
    for (const match of source.matchAll(/^\s*import\s+"(\.{1,2}\/[^"]+)"\s*;/gmu)) {
      queue.push(posix.normalize(posix.join(posix.dirname(file), match[1])));
    }
  }

  const listing = spawnSync("tar", ["-tzf", tarball], { encoding: "utf8" });
  if (listing.status !== 0) {
    throw new Error(`tar -tzf ${tarball} failed with ${listing.status}: ${listing.stderr}`);
  }
  const packed = new Set(
    listing.stdout.split("\n").filter(Boolean).map((entry) => entry.replace(/^package\//u, "")),
  );
  const missing = [...reachable].filter((file) => !packed.has(file)).sort((a, b) => a.localeCompare(b));
  if (missing.length > 0) {
    throw new Error(
      `${missing.length} TypeSpec file(s) imported from ${roots.join(", ")} are not in ${tarball}; ` +
      `add them to package.json#files:\n  ${missing.join("\n  ")}`,
    );
  }
  console.log(
    `verify-packed: all ${reachable.size} TypeSpec files reachable from ${roots.join(", ")} are in the tarball.`,
  );
}

await verifyTypeSpecImportClosure(npmTarball);

await verifyConsumers({
  version,
  npmSpec: npmTarball,
  nugetSource: dirname(nugetPackage),
});
