import { mkdirSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { releaseVersionPattern, verifyConsumers } from "./verify-consumers.mjs";

// Fallout's VerifyRelease runs this in release.sh's detached verification: wait until npm and
// nuget.org serve <version>, then install both registry packages into the consumer probes.
const version = process.argv[2];
if (!releaseVersionPattern.test(version ?? "")) {
  throw new Error("usage: node scripts/verify-published.mjs <version>");
}

const npmPackage = "@ancplua/qyl-api-schema";
const nugetPackage = "Qyl.Api.Contracts";
const lowerVersion = version.toLowerCase();
// One deadline for all three waits; polls back off from 5 s to 60 s.
const deadlineMs = 45 * 60_000;
const started = Date.now();
const elapsed = () => Math.round((Date.now() - started) / 1000);

// release.sh reads this file: "indexed" lets the snapshot refresh run, "timed-out" makes a failure
// a retry (exit 3) instead of a patch release.
const statusFile = fileURLToPath(new URL(`../artifacts/release-${version}-index.status`, import.meta.url));
mkdirSync(fileURLToPath(new URL("../artifacts/", import.meta.url)), { recursive: true });
const writeStatus = (state) => writeFileSync(statusFile, `${state} elapsed=${elapsed()}s at=${new Date().toISOString()}\n`);
writeStatus("waiting");

async function waitFor(url, matches, label) {
  let lastError = "not registered";
  for (let attempt = 1, delayMs = 5_000; ; attempt += 1, delayMs = Math.min(delayMs * 2, 60_000)) {
    try {
      const requestUrl = new URL(url);
      requestUrl.searchParams.set("attempt", String(attempt));
      const response = await fetch(requestUrl, {
        headers: { "cache-control": "no-cache" },
        signal: AbortSignal.timeout(10_000),
      });
      const body = await response.text();
      if (response.ok) {
        try {
          if (matches(JSON.parse(body))) {
            console.log(`indexed: ${label} after ${elapsed()} s`);
            return;
          }
          lastError = `HTTP ${response.status}; registration did not contain ${version}`;
        } catch (error) {
          lastError = `HTTP ${response.status}; invalid JSON: ${error instanceof Error ? error.message : String(error)}`;
        }
      } else {
        lastError = `HTTP ${response.status}`;
      }
    } catch (error) {
      lastError = error instanceof Error ? error.message : String(error);
    }
    if (Date.now() - started + delayMs > deadlineMs) {
      writeStatus("timed-out");
      console.error(`${label} was not registered after ${elapsed()} s: ${lastError}`);
      process.exit(3);
    }
    await new Promise((resolve) => setTimeout(resolve, delayMs));
  }
}

await waitFor(
  `https://registry.npmjs.org/%40ancplua%2Fqyl-api-schema/${version}`,
  (metadata) => metadata.version === version,
  `${npmPackage}@${version}`,
);
await waitFor(
  `https://api.nuget.org/v3/registration5-gz-semver2/qyl.api.contracts/${lowerVersion}.json`,
  (registration) => registration.listed === true &&
    typeof registration.packageContent === "string" &&
    registration.packageContent.toLowerCase().endsWith(
      `/qyl.api.contracts/${lowerVersion}/qyl.api.contracts.${lowerVersion}.nupkg`,
    ),
  `${nugetPackage}@${version} registration`,
);
await waitFor(
  "https://api.nuget.org/v3-flatcontainer/qyl.api.contracts/index.json",
  (index) => Array.isArray(index.versions) && index.versions.includes(lowerVersion),
  `${nugetPackage}@${version} package index`,
);

writeStatus("indexed");

await verifyConsumers({
  version,
  npmSpec: `${npmPackage}@${version}`,
  npmInstallArgs: ["--@ancplua:registry=https://registry.npmjs.org"],
  nugetSource: "https://api.nuget.org/v3/index.json",
});
