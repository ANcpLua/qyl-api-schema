import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const npmPackage = "@ancplua/qyl-api-schema";
const nugetPackage = "Qyl.Api.Contracts";
const mcpSdkPackage = "ModelContextProtocol.Core";
const mcpSdkVersion = "1.4.1";
const nugetOrg = "https://api.nuget.org/v3/index.json";

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
    await writeFile(
      join(npmDir, "smoke.mjs"),
      `import { HealthStatusValues, ProblemDetailsMediaType, RunnerMcpTaskStatusValues, RunnerMcpToolTaskSupportValues, RunnerResourceKindValues, RunnerResourceLifecycleValues } from ${JSON.stringify(`${npmPackage}/types`)};\n` +
        `import openapi from ${JSON.stringify(`${npmPackage}/openapi`)} with { type: "json" };\n` +
        `import schema from ${JSON.stringify(`${npmPackage}/json-schema`)} with { type: "json" };\n` +
        `const content = schema.$defs["Runner.Mcp.RunnerMcpContent"]?.properties;\n` +
        `const tool = schema.$defs["Runner.Mcp.RunnerMcpTool"]?.properties;\n` +
        `const request = schema.$defs["Runner.Mcp.RunnerMcpToolCallRequest"]?.properties;\n` +
        `const response = schema.$defs["Runner.Mcp.RunnerMcpToolCallResponse"]?.properties;\n` +
        `const operations = Object.values(openapi.paths).flatMap((path) => Object.values(path));\n` +
        `const errorResponses = operations.flatMap((operation) => Object.values(operation.responses ?? {})).filter((response) => Object.values(response.content ?? {}).some((media) => media.schema?.$ref?.startsWith("#/components/schemas/Common.Errors.")));\n` +
        `const errorsOwnProblemJson = errorResponses.length > 0 && errorResponses.every((response) => Object.keys(response.content ?? {}).length === 1 && response.content[ProblemDetailsMediaType]);\n` +
        `const resourceEvent = openapi.paths["/runner/resources/stream"]?.get?.responses?.["200"]?.content?.["text/event-stream"]?.itemSchema?.oneOf?.[0]?.properties?.event?.const;\n` +
        `const logEvent = openapi.paths["/runner/resources/{resource}/logs/stream"]?.get?.responses?.["200"]?.content?.["text/event-stream"]?.itemSchema?.oneOf?.[0]?.properties?.event?.const;\n` +
        `if (ProblemDetailsMediaType !== "application/problem+json" || !errorsOwnProblemJson || resourceEvent !== "message" || logEvent !== "message" || HealthStatusValues.healthy !== "healthy" || RunnerResourceLifecycleValues.ready !== "ready" || RunnerResourceKindValues.stdio !== "stdio" || RunnerMcpToolTaskSupportValues.required !== "required" || RunnerMcpTaskStatusValues.inputRequired !== "input_required" || !content?.toolUseId || !content?.content || !content?.icons || !tool?.execution || !tool?.icons || !request?._meta || !request?.task || !response?.task || !schema.$defs["Mcp.Tools.FetchTelemetryInput"]) process.exit(1);\n`,
    );
    run("node", ["smoke.mjs"], npmDir);

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
    await writeFile(
      join(dotnetDir, "Program.cs"),
      `using System.Text.Json;\nusing System.Text.Json.Nodes;\nusing ModelContextProtocol;\nusing ModelContextProtocol.Protocol;\nusing Qyl.Api.Contracts.Common.Errors;\nusing Qyl.Api.Contracts.Health;\nusing Qyl.Api.Contracts.Mcp.Tools;\nusing Qyl.Api.Contracts.Runner;\nusing Qyl.Api.Contracts.Runner.Mcp;\n#pragma warning disable MCPEXP001\n` +
        `var health = JsonSerializer.Serialize(HealthStatus.Healthy);\n` +
        `var lifecycle = JsonSerializer.Serialize(RunnerResourceLifecycle.Ready);\n` +
        `var kind = JsonSerializer.Serialize(RunnerResourceKind.Stdio);\n` +
        `var icon = new RunnerMcpIcon { Src = "data:image/png;base64,AA==", MimeType = "image/png", Sizes = ["16x16"], Theme = "dark" };\n` +
        `var request = new RunnerMcpToolCallRequest { Name = "smoke", Arguments = new Dictionary<string, object> { ["trace_id"] = "abc" }, Task = new RunnerMcpTaskMetadata { Ttl = 1500 }, Metadata = new Dictionary<string, object> { ["progressToken"] = 7L } };\n` +
        `var resource = new RunnerMcpResourceReadRequest { Uri = new Uri("ui://app/index.html"), Metadata = new Dictionary<string, object> { ["progressToken"] = "progress-1" } };\n` +
        `var state = new RunnerResourceState { Name = "demo", Lifecycle = RunnerResourceLifecycle.Ready, Timestamp = DateTimeOffset.UnixEpoch, Kind = RunnerResourceKind.Stdio };\n` +
        `var tool = new RunnerMcpTool { Name = "inspect", InputSchema = new Dictionary<string, object> { ["type"] = "object" }, Execution = new RunnerMcpToolExecution { TaskSupport = RunnerMcpToolTaskSupport.Required }, Icons = [icon], Annotations = new Dictionary<string, object> { ["readOnlyHint"] = true }, Metadata = new Dictionary<string, object> { ["ui/resourceUri"] = "ui://app/index.html" } };\n` +
        `var toolUse = new RunnerMcpContent { Type = "tool_use", Id = "call-1", Name = "inspect", Input = new Dictionary<string, object> { ["trace_id"] = "abc" }, Annotations = new Dictionary<string, object> { ["priority"] = 0.8 }, Metadata = new Dictionary<string, object> { ["source"] = "smoke" } };\n` +
        `var toolResult = new RunnerMcpContent { Type = "tool_result", ToolUseId = "call-1", Content = [new RunnerMcpContent { Type = "text", Text = "ok" }], StructuredContent = new Dictionary<string, object> { ["ok"] = true }, IsError = false };\n` +
        `var resourceLink = new RunnerMcpContent { Type = "resource_link", Uri = new Uri("ui://app/index.html"), Name = "dashboard", Icons = [icon] };\n` +
        `var embedded = new RunnerMcpContent { Type = "resource", Resource = new RunnerMcpResourceContent { Uri = new Uri("ui://app/index.html"), Text = "<html></html>", Metadata = new Dictionary<string, object> { ["ui"] = true } } };\n` +
        `var response = new RunnerMcpToolCallResponse { Content = [toolUse, toolResult, resourceLink, embedded], IsError = false, Task = new RunnerMcpTask { TaskId = "task-1", Status = RunnerMcpTaskStatus.InputRequired, StatusMessage = "waiting", CreatedAt = DateTimeOffset.UnixEpoch, LastUpdatedAt = DateTimeOffset.UnixEpoch.AddSeconds(1), Ttl = 60000, PollInterval = 250 }, Metadata = new Dictionary<string, object> { ["requestId"] = "req-1" } };\n` +
        `var toolInput = new FetchTelemetryInput { View = FetchTelemetryView.Traces };\n` +
        `var wire = string.Join("\\n", JsonSerializer.Serialize(tool), JsonSerializer.Serialize(request), JsonSerializer.Serialize(response), JsonSerializer.Serialize(resource));\n` +
        `var sdkIcon = new Icon { Source = icon.Src, MimeType = icon.MimeType, Sizes = ["16x16"], Theme = icon.Theme };\n` +
        `var sdkTool = new Tool { Name = "inspect", InputSchema = JsonSerializer.Deserialize<JsonElement>("{\\\"type\\\":\\\"object\\\"}"), Execution = new ToolExecution { TaskSupport = ToolTaskSupport.Required }, Icons = [sdkIcon], Annotations = new ToolAnnotations { ReadOnlyHint = true }, Meta = new JsonObject { ["ui/resourceUri"] = "ui://app/index.html" } };\n` +
        `var sdkRequest = new CallToolRequestParams { Name = "inspect", Arguments = new Dictionary<string, JsonElement> { ["trace_id"] = JsonSerializer.Deserialize<JsonElement>("\\\"abc\\\"") }, Task = new McpTaskMetadata { TimeToLive = TimeSpan.FromMilliseconds(1500) }, Meta = new JsonObject { ["progressToken"] = 7L } };\n` +
        `var sdkToolUse = new ToolUseContentBlock { Id = "call-1", Name = "inspect", Input = JsonSerializer.Deserialize<JsonElement>("{\\\"trace_id\\\":\\\"abc\\\"}"), Annotations = new Annotations { Priority = 0.8F }, Meta = new JsonObject { ["source"] = "smoke" } };\n` +
        `var sdkToolResult = new ToolResultContentBlock { ToolUseId = "call-1", Content = [new TextContentBlock { Text = "ok" }], StructuredContent = JsonSerializer.Deserialize<JsonElement>("{\\\"ok\\\":true}"), IsError = false };\n` +
        `var sdkResourceLink = new ResourceLinkBlock { Uri = "ui://app/index.html", Name = "dashboard", Icons = [sdkIcon] };\n` +
        `var sdkEmbedded = new EmbeddedResourceBlock { Resource = new TextResourceContents { Uri = "ui://app/index.html", Text = "<html></html>", Meta = new JsonObject { ["ui"] = true } } };\n` +
        `var sdkResponse = new CallToolResult { Content = [sdkToolUse, sdkToolResult, sdkResourceLink, sdkEmbedded], IsError = false, Task = new McpTask { TaskId = "task-1", Status = McpTaskStatus.InputRequired, StatusMessage = "waiting", CreatedAt = DateTimeOffset.UnixEpoch, LastUpdatedAt = DateTimeOffset.UnixEpoch.AddSeconds(1), TimeToLive = TimeSpan.FromMilliseconds(60000), PollInterval = TimeSpan.FromMilliseconds(250) }, Meta = new JsonObject { ["requestId"] = "req-1" } };\n` +
        `var sdkReadRequest = new ReadResourceRequestParams { Uri = "ui://app/index.html", Meta = new JsonObject { ["progressToken"] = "progress-1" } };\n` +
        `var sdkReadResponse = new ReadResourceResult { Contents = [new TextResourceContents { Uri = "ui://app/index.html", Text = "<html></html>", Meta = new JsonObject { ["ui"] = true } }], Meta = new JsonObject { ["requestId"] = "req-2" } };\n` +
        `var projectedTool = JsonSerializer.Deserialize<RunnerMcpTool>(JsonSerializer.Serialize(sdkTool, McpJsonUtilities.DefaultOptions));\n` +
        `var projectedRequest = JsonSerializer.Deserialize<RunnerMcpToolCallRequest>(JsonSerializer.Serialize(sdkRequest, McpJsonUtilities.DefaultOptions));\n` +
        `var projectedResponse = JsonSerializer.Deserialize<RunnerMcpToolCallResponse>(JsonSerializer.Serialize(sdkResponse, McpJsonUtilities.DefaultOptions));\n` +
        `var projectedReadRequest = JsonSerializer.Deserialize<RunnerMcpResourceReadRequest>(JsonSerializer.Serialize(sdkReadRequest, McpJsonUtilities.DefaultOptions));\n` +
        `var projectedReadResponse = JsonSerializer.Deserialize<RunnerMcpResourceReadResponse>(JsonSerializer.Serialize(sdkReadResponse, McpJsonUtilities.DefaultOptions));\n` +
        `if (ProblemDetailsMediaType.Value != "application/problem+json" || typeof(FetchTelemetryInput).Namespace != "Qyl.Api.Contracts.Mcp.Tools" || health != "\\\"healthy\\\"" || lifecycle != "\\\"ready\\\"" || kind != "\\\"stdio\\\"" || request.Name != "smoke" || resource.Uri.Scheme != "ui" || state.Kind != RunnerResourceKind.Stdio || tool.Name != "inspect" || toolInput.View != FetchTelemetryView.Traces || response.Task?.PollInterval != 250 || !wire.Contains("\\\"taskSupport\\\":\\\"required\\\"") || !wire.Contains("\\\"toolUseId\\\":\\\"call-1\\\"") || !wire.Contains("\\\"progressToken\\\"") || projectedTool?.Execution?.TaskSupport != RunnerMcpToolTaskSupport.Required || projectedTool.Icons?[0].Src != sdkIcon.Source || projectedRequest?.Task?.Ttl != 1500 || !projectedRequest.Metadata!.ContainsKey("progressToken") || projectedResponse?.Content[0].Type != "tool_use" || projectedResponse.Content[1].ToolUseId != "call-1" || projectedResponse.Content[2].Icons?[0].Src != sdkIcon.Source || projectedResponse.Content[3].Resource?.Text != "<html></html>" || projectedResponse.Task?.Status != RunnerMcpTaskStatus.InputRequired || projectedResponse.Task.PollInterval != 250 || projectedReadRequest?.Metadata is null || projectedReadResponse?.Contents[0].Metadata is null) return 1;\nreturn 0;\n`,
    );
    run(
      "dotnet",
      ["run", "--configuration", "Release", "--no-restore"],
      dotnetDir,
      dotnetEnvironment,
    );
  } finally {
    await rm(root, { recursive: true, force: true });
  }
}
