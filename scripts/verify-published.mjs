import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const version = process.argv[2];
if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(version ?? "")) {
  throw new Error("usage: node scripts/verify-published.mjs <version>");
}

const npmPackage = "@ancplua/qyl-api-schema";
const nugetPackage = "Qyl.Api.Contracts";

async function waitFor(url, matches, label) {
  for (let attempt = 1; attempt <= 60; attempt += 1) {
    const response = await fetch(`${url}${url.includes("?") ? "&" : "?"}attempt=${attempt}`, {
      headers: { "cache-control": "no-cache" },
    });
    if (response.ok && matches(await response.text())) return;
    if (attempt === 60) throw new Error(`${label} was not indexed after 5 minutes`);
    await new Promise((resolve) => setTimeout(resolve, 5_000));
  }
}

function run(command, args, cwd) {
  const result = spawnSync(command, args, { cwd, encoding: "utf8", stdio: "inherit" });
  if (result.status !== 0) throw new Error(`${command} ${args.join(" ")} failed with ${result.status}`);
}

await waitFor(
  `https://registry.npmjs.org/%40ancplua%2Fqyl-api-schema/${version}`,
  (body) => JSON.parse(body).version === version,
  `${npmPackage}@${version}`,
);
await waitFor(
  "https://api.nuget.org/v3-flatcontainer/qyl.api.contracts/index.json",
  (body) => JSON.parse(body).versions.includes(version.toLowerCase()),
  `${nugetPackage}@${version}`,
);

const root = await mkdtemp(join(tmpdir(), "qyl-contract-release-"));
try {
  const npmDir = join(root, "npm");
  await mkdir(npmDir);
  run("npm", ["init", "--yes"], npmDir);
  run(
    "npm",
    ["install", `${npmPackage}@${version}`, "--@ancplua:registry=https://registry.npmjs.org", "--ignore-scripts"],
    npmDir,
  );
  await writeFile(
    join(npmDir, "smoke.mjs"),
    `import { HealthStatusValues, RunnerResourceLifecycleValues } from ${JSON.stringify(`${npmPackage}/types`)};\n` +
      `if (HealthStatusValues.healthy !== "healthy" || RunnerResourceLifecycleValues.ready !== "ready") process.exit(1);\n`,
  );
  run("node", ["smoke.mjs"], npmDir);

  const dotnetDir = join(root, "dotnet");
  run("dotnet", ["new", "console", "--framework", "net10.0", "--output", dotnetDir], root);
  await writeFile(
    join(dotnetDir, "NuGet.Config"),
    `<?xml version="1.0" encoding="utf-8"?><configuration><packageSources><clear/><add key="nuget.org" value="https://api.nuget.org/v3/index.json"/></packageSources></configuration>`,
  );
  run(
    "dotnet",
    ["add", "package", nugetPackage, "--version", version, "--source", "https://api.nuget.org/v3/index.json"],
    dotnetDir,
  );
  await writeFile(
    join(dotnetDir, "Program.cs"),
    `using System.Text.Json;\nusing Qyl.Api.Contracts.Health;\nusing Qyl.Api.Contracts.Runner;\nusing Qyl.Api.Contracts.Runner.Mcp;\n` +
      `var health = JsonSerializer.Serialize(HealthStatus.Healthy);\n` +
      `var lifecycle = JsonSerializer.Serialize(RunnerResourceLifecycle.Ready);\n` +
      `var request = new RunnerMcpToolCallRequest { Name = "smoke" };\n` +
      `if (health != "\\\"healthy\\\"" || lifecycle != "\\\"ready\\\"" || request.Name != "smoke") return 1;\nreturn 0;\n`,
  );
  run("dotnet", ["run", "--configuration", "Release"], dotnetDir);
} finally {
  await rm(root, { recursive: true, force: true });
}
