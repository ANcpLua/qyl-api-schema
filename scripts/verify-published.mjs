import { verifyConsumers } from "./verify-consumers.mjs";

const version = process.argv[2];
if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(version ?? "")) {
  throw new Error("usage: node scripts/verify-published.mjs <version>");
}

const npmPackage = "@ancplua/qyl-api-schema";
const nugetPackage = "Qyl.Api.Contracts";
const lowerVersion = version.toLowerCase();
const waitAttempts = 180;
const waitDelayMs = 10_000;

async function waitFor(url, matches, label) {
  let lastError = "not registered";
  for (let attempt = 1; attempt <= waitAttempts; attempt += 1) {
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
          if (matches(JSON.parse(body))) return;
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
    if (attempt === waitAttempts) {
      throw new Error(`${label} was not registered after retries: ${lastError}`);
    }
    await new Promise((resolve) => setTimeout(resolve, waitDelayMs));
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

await verifyConsumers({
  version,
  npmSpec: `${npmPackage}@${version}`,
  npmInstallArgs: ["--@ancplua:registry=https://registry.npmjs.org"],
  nugetSource: "https://api.nuget.org/v3/index.json",
});
