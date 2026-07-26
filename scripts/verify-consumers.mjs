import { access, copyFile, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const nugetPackage = "Qyl.Api.Contracts";
const mcpSdkPackage = "ModelContextProtocol.Core";
const mcpSdkVersion = "1.4.1";
const nugetOrg = "https://api.nuget.org/v3/index.json";
const typeSpecToolchainPackages = [
  "compiler",
  "events",
  "http",
  "openapi",
  "openapi3",
  "sse",
];

// Probe sources live as ordinary files so they are readable, formattable, and
// diffable. They are copied verbatim into the temp consumer and only ever
// compiled there: in-repo they would resolve to this repository's own output
// instead of the published artifact, which is the thing under test.
const probesDir = fileURLToPath(new URL("probes/", import.meta.url));

async function exists(path) {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

function run(command, args, cwd, environment = {}) {
  const result = spawnSync(command, args, {
    cwd,
    encoding: "utf8",
    stdio: "inherit",
    env: { ...process.env, ...environment },
  });
  if (result.status !== 0) throw new Error(`${command} ${args.join(" ")} failed with ${result.status}`);
}

function escapeXml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("\"", "&quot;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

export async function verifyConsumers({ version, npmSpec, npmInstallArgs = [], nugetSource }) {
  const root = await mkdtemp(join(tmpdir(), "qyl-contract-consumers-"));
  let succeeded = false;
  try {
    const npmDir = join(root, "npm");
    await mkdir(npmDir);
    run("npm", ["init", "--yes"], npmDir);
    run(
      "npm",
      ["install", "--save-exact", npmSpec, ...npmInstallArgs, "--ignore-scripts"],
      npmDir,
      { NPM_CONFIG_CACHE: join(root, "npm-cache") },
    );
    const installedToolchainPackages = [];
    for (const packageName of typeSpecToolchainPackages) {
      if (await exists(join(npmDir, "node_modules", "@typespec", packageName))) {
        installedToolchainPackages.push(`@typespec/${packageName}`);
      }
    }
    if (installedToolchainPackages.length > 0) {
      throw new Error(
        `generated-only npm consumer unexpectedly installed the TypeSpec toolchain: ${installedToolchainPackages.join(", ")}`,
      );
    }

    await copyFile(join(probesDir, "npm-smoke.mjs"), join(npmDir, "smoke.mjs"));
    run("node", ["smoke.mjs"], npmDir);

    await copyFile(join(probesDir, "npm-smoke.ts"), join(npmDir, "smoke.ts"));
    run(
      process.execPath,
      [
        resolve("node_modules/typescript/bin/tsc"),
        "--noEmit",
        "--strict",
        "--target", "ES2022",
        "--module", "NodeNext",
        "--moduleResolution", "NodeNext",
        "smoke.ts",
      ],
      npmDir,
    );

    const dotnetDir = join(root, "dotnet");
    const dotnetEnvironment = {
      DOTNET_CLI_HOME: join(root, "dotnet-home"),
      NUGET_PACKAGES: join(root, "nuget-packages"),
      NUGET_HTTP_CACHE_PATH: join(root, "nuget-http-cache"),
    };
    run(
      "dotnet",
      ["new", "console", "--framework", "net10.0", "--no-restore", "--output", dotnetDir],
      root,
      dotnetEnvironment,
    );
    await writeFile(
      join(dotnetDir, "NuGet.Config"),
      `<?xml version="1.0" encoding="utf-8"?><configuration><packageSources><clear/><add key="contracts" value="${escapeXml(nugetSource)}"/>${nugetSource === nugetOrg ? "" : `<add key="nuget.org" value="${nugetOrg}"/>`}</packageSources></configuration>`,
    );
    run(
      "dotnet",
      ["add", "package", nugetPackage, "--version", version, "--no-restore"],
      dotnetDir,
      dotnetEnvironment,
    );
    run(
      "dotnet",
      ["add", "package", mcpSdkPackage, "--version", mcpSdkVersion, "--no-restore"],
      dotnetDir,
      dotnetEnvironment,
    );
    run(
      "dotnet",
      ["restore", "--configfile", "NuGet.Config", "--force", "--no-cache"],
      dotnetDir,
      dotnetEnvironment,
    );

    await copyFile(join(probesDir, "dotnet-smoke.cs"), join(dotnetDir, "Program.cs"));
    run(
      "dotnet",
      ["run", "--configuration", "Release", "--no-restore"],
      dotnetDir,
      dotnetEnvironment,
    );

    succeeded = true;
  } finally {
    if (succeeded) {
      await rm(root, { recursive: true, force: true });
    } else {
      // A release gate that deletes its own evidence cannot be diagnosed. The
      // installed package, the probe sources, and the restore output stay put.
      console.error(`consumer probe workspace retained for inspection: ${root}`);
      console.error(`  npm consumer:    ${join(root, "npm")}`);
      console.error(`  dotnet consumer: ${join(root, "dotnet")}`);
    }
  }
}
