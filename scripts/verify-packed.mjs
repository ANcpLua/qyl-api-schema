import { access } from "node:fs/promises";
import { dirname, resolve } from "node:path";
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

await verifyConsumers({
  version,
  npmSpec: npmTarball,
  nugetSource: dirname(nugetPackage),
});
