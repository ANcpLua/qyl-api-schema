import { access, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const npmPackage = "@ancplua/qyl-api-schema";
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
    await writeFile(
      join(npmDir, "smoke.mjs"),
      `import { GenAiEtlValidationMetricValues, HealthStatusValues, ProblemDetailsMediaType, RunnerMcpTaskStatusValues, RunnerMcpToolTaskSupportValues, RunnerResourceKindValues, RunnerResourceLifecycleValues } from ${JSON.stringify(`${npmPackage}/types`)};\n` +
        `import openapi from ${JSON.stringify(`${npmPackage}/openapi`)} with { type: "json" };\n` +
        `import schema from ${JSON.stringify(`${npmPackage}/json-schema`)} with { type: "json" };\n` +
        `const content = schema.$defs["Runner.Mcp.RunnerMcpContent"];\n` +
        `const contentRefs = (content?.oneOf ?? []).map((variant) => variant.$ref);\n` +
        `const expectedContentRefs = ["RunnerMcpTextContent", "RunnerMcpImageContent", "RunnerMcpAudioContent", "RunnerMcpEmbeddedResourceContent", "RunnerMcpResourceLinkContent", "RunnerMcpToolUseContent", "RunnerMcpToolResultContent"].map((name) => "#/$defs/Runner.Mcp." + name);\n` +
        `const exactContentUnion = JSON.stringify(contentRefs) === JSON.stringify(expectedContentRefs) && schema.$defs["Runner.Mcp.RunnerMcpTextContent"]?.required?.includes("text") && schema.$defs["Runner.Mcp.RunnerMcpImageContent"]?.required?.includes("data") && schema.$defs["Runner.Mcp.RunnerMcpToolResultContent"]?.required?.includes("content");\n` +
        `const resourceRefs = (schema.$defs["Runner.Mcp.RunnerMcpResourceContent"]?.oneOf ?? []).map((variant) => variant.$ref);\n` +
        `const exactResourceUnion = JSON.stringify(resourceRefs) === JSON.stringify(["#/$defs/Runner.Mcp.RunnerMcpTextResourceContent", "#/$defs/Runner.Mcp.RunnerMcpBlobResourceContent"]) && schema.$defs["Runner.Mcp.RunnerMcpTextResourceContent"]?.required?.includes("text") && schema.$defs["Runner.Mcp.RunnerMcpBlobResourceContent"]?.required?.includes("blob");\n` +
        `const attributeVariants = schema.$defs["Common.AttributeValue"]?.anyOf ?? [];\n` +
        `const recursiveAttributeValue = attributeVariants.some((variant) => variant.$ref === "#/$defs/Common.AttributeBytesValue") && attributeVariants.some((variant) => variant.type === "array" && variant.items?.$ref === "#/$defs/Common.AttributeValue") && attributeVariants.some((variant) => variant.$ref === "#/$defs/Common.AttributeKeyValueListValue") && schema.$defs["Common.AttributeBytesValue"]?.properties?.base64?.contentEncoding === "base64";\n` +
        `const auditCluster = schema.$defs["Cost.GenAiEtlAuditCluster"];\n` +
        `const compoundValidationMetrics = auditCluster?.required?.includes("validation_metrics") && !auditCluster.required.includes("validation_metric") && auditCluster.properties?.validation_metrics?.type === "array" && auditCluster.properties.validation_metrics.minItems === 1 && auditCluster.properties.validation_metrics.items?.$ref === "#/$defs/Cost.GenAiEtlValidationMetric" && !("validation_metric" in (auditCluster.properties ?? {}));\n` +
        `const tool = schema.$defs["Runner.Mcp.RunnerMcpTool"]?.properties;\n` +
        `const request = schema.$defs["Runner.Mcp.RunnerMcpToolCallRequest"]?.properties;\n` +
        `const response = schema.$defs["Runner.Mcp.RunnerMcpToolCallResponse"]?.properties;\n` +
        `const operations = Object.values(openapi.paths).flatMap((path) => Object.values(path));\n` +
        `const errorResponses = operations.flatMap((operation) => Object.values(operation.responses ?? {})).filter((response) => Object.values(response.content ?? {}).some((media) => media.schema?.$ref?.startsWith("#/components/schemas/Common.Errors.")));\n` +
        `const errorsOwnProblemJson = errorResponses.length > 0 && errorResponses.every((response) => Object.keys(response.content ?? {}).length === 1 && response.content[ProblemDetailsMediaType]);\n` +
        `const runnerOperations = Object.entries(openapi.paths).flatMap(([path, pathItem]) => Object.entries(pathItem).map(([method, operation]) => ({ path, method, operation }))).filter(({ operation }) => operation.tags?.some((tag) => tag === "Runner resources" || tag === "Runner MCP"));\n` +
        `const runnerSecurityResponsesDeclared = runnerOperations.length === 9 && runnerOperations.every(({ operation }) => { const response = operation.responses?.["403"]; const content = response?.content ?? {}; return Object.keys(content).length === 1 && content[ProblemDetailsMediaType]?.schema?.$ref === "#/components/schemas/Common.Errors.ForbiddenError"; });\n` +
        `const runnerCapacityResponsesDeclared = runnerOperations.length === 9 && runnerOperations.every(({ operation }) => { const response = operation.responses?.["503"]; const content = response?.content ?? {}; return Object.keys(content).length === 1 && content[ProblemDetailsMediaType]?.schema?.$ref === "#/components/schemas/Common.Errors.ServiceUnavailableError"; });\n` +
        `const logStreamCapacityResponseDeclared = (() => { const content = openapi.paths["/api/v1/stream/logs"]?.get?.responses?.["503"]?.content ?? {}; return Object.keys(content).length === 1 && content[ProblemDetailsMediaType]?.schema?.$ref === "#/components/schemas/Common.Errors.ServiceUnavailableError"; })();\n` +
        `const typedQueryPaths = ["/api/v1/traces", "/api/v1/logs", "/api/v1/profiles", "/api/v1/profiles/by-trace/{traceId}", "/api/v1/profiles/by-span/{spanId}", "/api/v1/sessions", "/api/v1/sessions/stats", "/api/v1/stream/logs"];\n` +
        `const typedQueryValidationResponsesDeclared = typedQueryPaths.every((path) => { const content = openapi.paths[path]?.get?.responses?.["400"]?.content ?? {}; return Object.keys(content).length === 1 && content[ProblemDetailsMediaType]?.schema?.$ref === "#/components/schemas/Common.Errors.ValidationError"; });\n` +
        `const resourceEvent = openapi.paths["/runner/resources/stream"]?.get?.responses?.["200"]?.content?.["text/event-stream"]?.itemSchema?.oneOf?.[0]?.properties?.event?.const;\n` +
        `const logEvent = openapi.paths["/runner/resources/{resource}/logs/stream"]?.get?.responses?.["200"]?.content?.["text/event-stream"]?.itemSchema?.oneOf?.[0]?.properties?.event?.const;\n` +
        `if (ProblemDetailsMediaType !== "application/problem+json" || !errorsOwnProblemJson || !runnerSecurityResponsesDeclared || !runnerCapacityResponsesDeclared || !logStreamCapacityResponseDeclared || !typedQueryValidationResponsesDeclared || !exactContentUnion || !exactResourceUnion || !recursiveAttributeValue || !compoundValidationMetrics || GenAiEtlValidationMetricValues.calibrationError !== "calibration_error" || GenAiEtlValidationMetricValues.spanPrecision !== "span_precision" || GenAiEtlValidationMetricValues.spanRecall !== "span_recall" || resourceEvent !== "message" || logEvent !== "message" || HealthStatusValues.healthy !== "healthy" || RunnerResourceLifecycleValues.ready !== "ready" || RunnerResourceKindValues.stdio !== "stdio" || RunnerMcpToolTaskSupportValues.required !== "required" || RunnerMcpTaskStatusValues.inputRequired !== "input_required" || !tool?.execution || !tool?.icons || !request?._meta || !request?.task || !response?.task || !schema.$defs["Mcp.Tools.FetchTelemetryInput"]) process.exit(1);\n`,
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
      `using System.Text.Json;\nusing System.Text.Json.Nodes;\nusing System.Text.Json.Serialization;\nusing ModelContextProtocol;\nusing ModelContextProtocol.Protocol;\nusing Qyl.Api.Contracts.Common.Errors;\nusing Qyl.Api.Contracts.Cost;\nusing Qyl.Api.Contracts.Health;\nusing Qyl.Api.Contracts.Mcp.Tools;\nusing Qyl.Api.Contracts.Runner;\nusing Qyl.Api.Contracts.Runner.Mcp;\n#pragma warning disable MCPEXP001\n` +
        `var health = JsonSerializer.Serialize(HealthStatus.Healthy);\n` +
        `var lifecycle = JsonSerializer.Serialize(RunnerResourceLifecycle.Ready);\n` +
        `var kind = JsonSerializer.Serialize(RunnerResourceKind.Stdio);\n` +
        `var binary = new byte[] { 0, 1, 2, 255 };\n` +
        `var icon = new RunnerMcpIcon { Src = "data:image/png;base64,AA==", MimeType = "image/png", Sizes = ["16x16"], Theme = "dark" };\n` +
        `var request = new RunnerMcpToolCallRequest { Name = "smoke", Arguments = new Dictionary<string, object> { ["trace_id"] = "abc" }, Task = new RunnerMcpTaskMetadata { Ttl = 1500 }, Metadata = new Dictionary<string, object> { ["progressToken"] = 7L } };\n` +
        `var resource = new RunnerMcpResourceReadRequest { Uri = new Uri("ui://app/index.html"), Metadata = new Dictionary<string, object> { ["progressToken"] = "progress-1" } };\n` +
        `var state = new RunnerResourceState { Name = "demo", Lifecycle = RunnerResourceLifecycle.Ready, Timestamp = DateTimeOffset.UnixEpoch, Kind = RunnerResourceKind.Stdio };\n` +
        `var tool = new RunnerMcpTool { Name = "inspect", InputSchema = new Dictionary<string, object> { ["type"] = "object" }, Execution = new RunnerMcpToolExecution { TaskSupport = RunnerMcpToolTaskSupport.Required }, Icons = [icon], Annotations = new Dictionary<string, object> { ["readOnlyHint"] = true }, Metadata = new Dictionary<string, object> { ["ui/resourceUri"] = "ui://app/index.html" } };\n` +
        `var text = new RunnerMcpTextContent { Text = "ok" };\n` +
        `var image = new RunnerMcpImageContent { Data = binary, MimeType = "image/png" };\n` +
        `var audio = new RunnerMcpAudioContent { Data = binary, MimeType = "audio/wav" };\n` +
        `var textResource = new RunnerMcpTextResourceContent { Uri = new Uri("ui://app/index.html"), Text = "<html></html>", Metadata = new Dictionary<string, object> { ["ui"] = true } };\n` +
        `var blobResource = new RunnerMcpBlobResourceContent { Uri = new Uri("file:///tmp/blob"), MimeType = "application/octet-stream", Blob = binary };\n` +
        `var embedded = new RunnerMcpEmbeddedResourceContent { Resource = textResource };\n` +
        `var resourceLink = new RunnerMcpResourceLinkContent { Uri = new Uri("ui://app/index.html"), Name = "dashboard", Icons = [icon] };\n` +
        `var toolUse = new RunnerMcpToolUseContent { Id = "call-1", Name = "inspect", Input = new Dictionary<string, object> { ["trace_id"] = "abc" }, Annotations = new Dictionary<string, object> { ["priority"] = 0.8 }, Metadata = new Dictionary<string, object> { ["source"] = "smoke" } };\n` +
        `var toolResult = new RunnerMcpToolResultContent { ToolUseId = "call-1", Content = [new RunnerMcpTextContent { Text = "ok" }], StructuredContent = new Dictionary<string, object> { ["ok"] = true }, IsError = false };\n` +
        `var response = new RunnerMcpToolCallResponse { Content = [text, image, audio, embedded, resourceLink, toolUse, toolResult], IsError = false, Task = new RunnerMcpTask { TaskId = "task-1", Status = RunnerMcpTaskStatus.InputRequired, StatusMessage = "waiting", CreatedAt = DateTimeOffset.UnixEpoch, LastUpdatedAt = DateTimeOffset.UnixEpoch.AddSeconds(1), Ttl = 60000, PollInterval = 250 }, Metadata = new Dictionary<string, object> { ["requestId"] = "req-1" } };\n` +
        `var readResponse = new RunnerMcpResourceReadResponse { Contents = [textResource, blobResource], Metadata = new Dictionary<string, object> { ["requestId"] = "req-2" } };\n` +
        `var toolInput = new FetchTelemetryInput { View = FetchTelemetryView.Traces };\n` +
        `var wire = string.Join("\\n", JsonSerializer.Serialize(tool), JsonSerializer.Serialize(request), JsonSerializer.Serialize(response), JsonSerializer.Serialize(resource), JsonSerializer.Serialize(readResponse));\n` +
        `var ambiguousResourceRejected = false;\n` +
        `try { JsonSerializer.Deserialize<RunnerMcpResourceContent>("{\\\"uri\\\":\\\"file:///tmp/both\\\",\\\"text\\\":\\\"x\\\",\\\"blob\\\":\\\"AAE=\\\"}"); } catch (JsonException) { ambiguousResourceRejected = true; }\n` +
        `var sdkIcon = new Icon { Source = icon.Src, MimeType = icon.MimeType, Sizes = ["16x16"], Theme = icon.Theme };\n` +
        `var sdkTool = new Tool { Name = "inspect", InputSchema = JsonSerializer.Deserialize<JsonElement>("{\\\"type\\\":\\\"object\\\"}"), Execution = new ToolExecution { TaskSupport = ToolTaskSupport.Required }, Icons = [sdkIcon], Annotations = new ToolAnnotations { ReadOnlyHint = true }, Meta = new JsonObject { ["ui/resourceUri"] = "ui://app/index.html" } };\n` +
        `var sdkRequest = new CallToolRequestParams { Name = "inspect", Arguments = new Dictionary<string, JsonElement> { ["trace_id"] = JsonSerializer.Deserialize<JsonElement>("\\\"abc\\\"") }, Task = new McpTaskMetadata { TimeToLive = TimeSpan.FromMilliseconds(1500) }, Meta = new JsonObject { ["progressToken"] = 7L } };\n` +
        `var sdkText = new TextContentBlock { Text = "ok" };\n` +
        `var sdkImage = ImageContentBlock.FromBytes(binary, "image/png");\n` +
        `var sdkAudio = AudioContentBlock.FromBytes(binary, "audio/wav");\n` +
        `var sdkToolUse = new ToolUseContentBlock { Id = "call-1", Name = "inspect", Input = JsonSerializer.Deserialize<JsonElement>("{\\\"trace_id\\\":\\\"abc\\\"}"), Annotations = new Annotations { Priority = 0.8F }, Meta = new JsonObject { ["source"] = "smoke" } };\n` +
        `var sdkToolResult = new ToolResultContentBlock { ToolUseId = "call-1", Content = [new TextContentBlock { Text = "ok" }], StructuredContent = JsonSerializer.Deserialize<JsonElement>("{\\\"ok\\\":true}"), IsError = false };\n` +
        `var sdkResourceLink = new ResourceLinkBlock { Uri = "ui://app/index.html", Name = "dashboard", Icons = [sdkIcon] };\n` +
        `var sdkEmbedded = new EmbeddedResourceBlock { Resource = new TextResourceContents { Uri = "ui://app/index.html", Text = "<html></html>", Meta = new JsonObject { ["ui"] = true } } };\n` +
        `var sdkResponse = new CallToolResult { Content = [sdkText, sdkImage, sdkAudio, sdkEmbedded, sdkResourceLink, sdkToolUse, sdkToolResult], IsError = false, Task = new McpTask { TaskId = "task-1", Status = McpTaskStatus.InputRequired, StatusMessage = "waiting", CreatedAt = DateTimeOffset.UnixEpoch, LastUpdatedAt = DateTimeOffset.UnixEpoch.AddSeconds(1), TimeToLive = TimeSpan.FromMilliseconds(60000), PollInterval = TimeSpan.FromMilliseconds(250) }, Meta = new JsonObject { ["requestId"] = "req-1" } };\n` +
        `var sdkReadRequest = new ReadResourceRequestParams { Uri = "ui://app/index.html", Meta = new JsonObject { ["progressToken"] = "progress-1" } };\n` +
        `var sdkReadResponse = new ReadResourceResult { Contents = [new TextResourceContents { Uri = "ui://app/index.html", Text = "<html></html>", Meta = new JsonObject { ["ui"] = true } }, BlobResourceContents.FromBytes(binary, "file:///tmp/blob", "application/octet-stream")], Meta = new JsonObject { ["requestId"] = "req-2" } };\n` +
        `var projectedTool = JsonSerializer.Deserialize<RunnerMcpTool>(JsonSerializer.Serialize(sdkTool, McpJsonUtilities.DefaultOptions));\n` +
        `var projectedRequest = JsonSerializer.Deserialize<RunnerMcpToolCallRequest>(JsonSerializer.Serialize(sdkRequest, McpJsonUtilities.DefaultOptions));\n` +
        `var projectedResponse = JsonSerializer.Deserialize<RunnerMcpToolCallResponse>(JsonSerializer.Serialize(sdkResponse, McpJsonUtilities.DefaultOptions));\n` +
        `var projectedReadRequest = JsonSerializer.Deserialize<RunnerMcpResourceReadRequest>(JsonSerializer.Serialize(sdkReadRequest, McpJsonUtilities.DefaultOptions));\n` +
        `var projectedReadResponse = JsonSerializer.Deserialize<RunnerMcpResourceReadResponse>(JsonSerializer.Serialize(sdkReadResponse, McpJsonUtilities.DefaultOptions));\n` +
        `var validationMetricsProperty = typeof(GenAiEtlAuditCluster).GetProperty("ValidationMetrics");\n` +
        `var validationMetricsWireName = validationMetricsProperty?.GetCustomAttributes(typeof(JsonPropertyNameAttribute), false).OfType<JsonPropertyNameAttribute>().SingleOrDefault()?.Name;\n` +
        `var validationMetricsWire = JsonSerializer.Serialize(new[] { GenAiEtlValidationMetric.CalibrationError, GenAiEtlValidationMetric.SpanPrecision, GenAiEtlValidationMetric.SpanRecall });\n` +
        `if (ProblemDetailsMediaType.Value != "application/problem+json" || typeof(FetchTelemetryInput).Namespace != "Qyl.Api.Contracts.Mcp.Tools" || typeof(GenAiEtlAuditCluster).GetProperty("ValidationMetric") is not null || validationMetricsProperty?.PropertyType != typeof(IReadOnlyList<GenAiEtlValidationMetric>) || validationMetricsWireName != "validation_metrics" || validationMetricsWire != "[\\\"calibration_error\\\",\\\"span_precision\\\",\\\"span_recall\\\"]" || health != "\\\"healthy\\\"" || lifecycle != "\\\"ready\\\"" || kind != "\\\"stdio\\\"" || request.Name != "smoke" || resource.Uri.Scheme != "ui" || state.Kind != RunnerResourceKind.Stdio || tool.Name != "inspect" || toolInput.View != FetchTelemetryView.Traces || response.Task?.PollInterval != 250 || !ambiguousResourceRejected || !wire.Contains("\\\"taskSupport\\\":\\\"required\\\"") || !wire.Contains("\\\"type\\\":\\\"tool_result\\\"") || !wire.Contains("\\\"data\\\":\\\"AAEC/w==\\\"") || !wire.Contains("\\\"progressToken\\\"") || projectedTool?.Execution?.TaskSupport != RunnerMcpToolTaskSupport.Required || projectedTool.Icons?[0].Src != sdkIcon.Source || projectedRequest?.Task?.Ttl != 1500 || !projectedRequest.Metadata!.ContainsKey("progressToken") || projectedResponse?.Content[0] is not RunnerMcpTextContent projectedText || projectedText.Text != "ok" || projectedResponse.Content[1] is not RunnerMcpImageContent projectedImage || !projectedImage.Data.Span.SequenceEqual(binary) || projectedResponse.Content[2] is not RunnerMcpAudioContent projectedAudio || !projectedAudio.Data.Span.SequenceEqual(binary) || projectedResponse.Content[3] is not RunnerMcpEmbeddedResourceContent projectedEmbedded || projectedEmbedded.Resource is not RunnerMcpTextResourceContent projectedEmbeddedText || projectedEmbeddedText.Text != "<html></html>" || projectedResponse.Content[4] is not RunnerMcpResourceLinkContent projectedLink || projectedLink.Icons?[0].Src != sdkIcon.Source || projectedResponse.Content[5] is not RunnerMcpToolUseContent projectedUse || projectedUse.Id != "call-1" || projectedResponse.Content[6] is not RunnerMcpToolResultContent projectedResult || projectedResult.Content[0] is not RunnerMcpTextContent || projectedResponse.Task?.Status != RunnerMcpTaskStatus.InputRequired || projectedResponse.Task.PollInterval != 250 || projectedReadRequest?.Metadata is null || projectedReadResponse?.Contents[0] is not RunnerMcpTextResourceContent projectedReadText || projectedReadText.Metadata is null || projectedReadResponse.Contents[1] is not RunnerMcpBlobResourceContent projectedReadBlob || !projectedReadBlob.Blob.Span.SequenceEqual(binary)) return 1;\nreturn 0;\n`,
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
