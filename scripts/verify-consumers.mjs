import { access, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
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
      `import { HealthStatusValues, ProblemDetailsMediaType, RunnerMcpEvaluationExportFormatValues, RunnerMcpExecutionStatusValues, RunnerMcpTransportKindValues, RunnerResourceKindValues, RunnerResourceLifecycleValues } from ${JSON.stringify(`${npmPackage}/types`)};\n` +
        `import openapi from ${JSON.stringify(`${npmPackage}/openapi`)} with { type: "json" };\n` +
        `import schema from ${JSON.stringify(`${npmPackage}/json-schema`)} with { type: "json" };\n` +
        `const serverConfigRefs = (schema.$defs["Runner.Mcp.RunnerMcpServerConfiguration"]?.oneOf ?? []).map((variant) => variant.$ref);\n` +
        `const exactServerConfigurationUnion = JSON.stringify(serverConfigRefs) === JSON.stringify(["RunnerMcpStdioServerConfiguration", "RunnerMcpStreamableHttpServerConfiguration", "RunnerMcpSseServerConfiguration", "RunnerMcpInProcessServerConfiguration", "RunnerMcpBuiltinServerConfiguration"].map((name) => "#/$defs/Runner.Mcp." + name));\n` +
        `const assertionRefs = (schema.$defs["Runner.Mcp.RunnerMcpTestAssertion"]?.oneOf ?? []).map((variant) => variant.$ref);\n` +
        `const exactAssertionUnion = JSON.stringify(assertionRefs) === JSON.stringify(["RunnerMcpStatusAssertion", "RunnerMcpExactAssertion", "RunnerMcpPartialAssertion", "RunnerMcpSchemaAssertion", "RunnerMcpPatternAssertion", "RunnerMcpLatencyAssertion"].map((name) => "#/$defs/Runner.Mcp." + name));\n` +
        `const exportRefs = (schema.$defs["Runner.Mcp.RunnerMcpEvaluationExportPayload"]?.oneOf ?? []).map((variant) => variant.$ref);\n` +
        `const exactExportUnion = JSON.stringify(exportRefs) === JSON.stringify(["RunnerMcpEvaluationJsonExportPayload", "RunnerMcpEvaluationReportExportPayload"].map((name) => "#/$defs/Runner.Mcp." + name));\n` +
        `const executionRequest = schema.$defs["Runner.Mcp.RunnerMcpExecutionRequest"];\n` +
        `const opaqueSdkBoundaries = !schema.$defs["Runner.Mcp.RunnerMcpContent"] && !schema.$defs["Runner.Mcp.RunnerMcpTool"] && !executionRequest?.properties?.arguments?.$ref && !schema.$defs["Runner.Mcp.RunnerMcpExecutionRecord"]?.properties?.result?.$ref;\n` +
        `const attributeVariants = schema.$defs["Common.AttributeValue"]?.anyOf ?? [];\n` +
        `const attributeDouble = schema.$defs["Common.AttributeDouble"];\n` +
        `const losslessAttributeValue = attributeVariants.length === 8 && attributeVariants.some((variant) => variant.type === "null") && attributeVariants.some((variant) => variant.$ref === "#/$defs/Common.AttributeIntValue") && attributeVariants.some((variant) => variant.$ref === "#/$defs/Common.AttributeDoubleValue") && attributeVariants.some((variant) => variant.$ref === "#/$defs/Common.AttributeBytesValue") && attributeVariants.some((variant) => variant.type === "array" && variant.items?.$ref === "#/$defs/Common.AttributeValue") && attributeVariants.some((variant) => variant.$ref === "#/$defs/Common.AttributeKeyValueListValue") && schema.$defs["Common.AttributeInt64"]?.type === "string" && JSON.stringify(attributeDouble?.anyOf?.[1]?.enum) === JSON.stringify(["NaN", "Infinity", "-Infinity"]) && schema.$defs["Common.AttributeBytesValue"]?.properties?.base64?.contentEncoding === "base64" && schema.$defs["Common.AttributeKeyValueListValue"]?.properties?.values?.unevaluatedProperties?.$ref === "#/$defs/Common.AttributeValue";\n` +
        `const entityRef = schema.$defs["Common.EntityRef"];\n` +
        `const resourceContract = schema.$defs["OTel.Resource.Resource"];\n` +
        `const exactEntityRef = entityRef?.required?.includes("type") && entityRef.required.includes("id_keys") && entityRef.properties?.type?.minLength === 1 && entityRef.properties?.id_keys?.minItems === 1 && entityRef.properties.id_keys.items?.$ref === "#/$defs/Common.EntityAttributeKey" && entityRef.properties?.description_keys?.items?.$ref === "#/$defs/Common.EntityAttributeKey" && resourceContract?.properties?.entity_refs?.items?.$ref === "#/$defs/Common.EntityRef";\n` +
        `const metricPointRefs = (schema.$defs["OTel.Metrics.MetricPoint"]?.anyOf ?? []).map((variant) => variant.$ref);\n` +
        `const metricValueRefs = (schema.$defs["OTel.Metrics.MetricNumberValue"]?.anyOf ?? []).map((variant) => variant.$ref);\n` +
        `const expectedMetricPointRefs = ["GaugeMetricPoint", "SumMetricPoint", "HistogramMetricPoint", "ExponentialHistogramMetricPoint", "SummaryMetricPoint"].map((name) => "#/$defs/OTel.Metrics." + name);\n` +
        `const metricDouble = schema.$defs["OTel.Metrics.MetricDouble"];\n` +
        `const summaryQuantileVariants = schema.$defs["OTel.Metrics.SummaryQuantileDouble"]?.anyOf ?? [];\n` +
        `const summaryQuantileFinite = schema.$defs["OTel.Metrics.SummaryQuantileFiniteValue"];\n` +
        `const exactSummaryQuantileDouble = summaryQuantileVariants.length === 2 && summaryQuantileVariants.some((variant) => variant.$ref === "#/$defs/OTel.Metrics.SummaryQuantileFiniteValue") && summaryQuantileFinite?.type === "number" && summaryQuantileFinite.minimum === 0 && summaryQuantileVariants.some((variant) => JSON.stringify(variant.enum) === JSON.stringify(["Infinity"]));\n` +
        `const exactMetricContract = JSON.stringify(metricPointRefs) === JSON.stringify(expectedMetricPointRefs) && JSON.stringify(metricValueRefs) === JSON.stringify(["#/$defs/OTel.Metrics.MetricIntegerValue", "#/$defs/OTel.Metrics.MetricDoubleValue"]) && schema.$defs["OTel.Metrics.MetricInt64"]?.type === "string" && schema.$defs["OTel.Metrics.MetricUInt64"]?.type === "string" && schema.$defs["OTel.Metrics.MetricUnixNanos"]?.type === "string" && schema.$defs["OTel.Metrics.MetricStartUnixNanos"]?.type === "string" && JSON.stringify(metricDouble?.anyOf?.[1]?.enum) === JSON.stringify(["NaN", "Infinity", "-Infinity"]) && !schema.$defs["OTel.Metrics.GaugeMetricPoint"]?.required?.includes("value") && !schema.$defs["OTel.Metrics.SumMetricPoint"]?.required?.includes("value") && schema.$defs["OTel.Metrics.HistogramMetricPoint"]?.properties?.bucket_counts?.items?.$ref === "#/$defs/OTel.Metrics.MetricUInt64" && schema.$defs["OTel.Metrics.HistogramMetricPoint"]?.properties?.sum?.$ref === "#/$defs/OTel.Metrics.MetricDouble" && schema.$defs["OTel.Metrics.ExponentialHistogramMetricPoint"]?.properties?.zero_threshold?.$ref === "#/$defs/OTel.Metrics.MetricDouble" && schema.$defs["OTel.Metrics.SummaryQuantileValue"]?.properties?.value?.$ref === "#/$defs/OTel.Metrics.SummaryQuantileDouble" && exactSummaryQuantileDouble;\n` +
        `const logRecord = schema.$defs["OTel.Logs.LogRecord"];\n` +
        `const eventLogContract = logRecord?.properties?.event_name?.type === "string" && !logRecord.required?.includes("event_name");\n` +
        `const metricsResponseBody = schema.$defs["Operations.MetricsApi_list.Response.200"];\n` +
        `const matchKinds = ["exact_model_id", "exact_canonical_slug"];\n` +
        `const operations = Object.values(openapi.paths).flatMap((path) => Object.values(path));\n` +
        `const errorResponses = operations.flatMap((operation) => Object.values(operation.responses ?? {})).filter((response) => Object.values(response.content ?? {}).some((media) => media.schema?.$ref?.startsWith("#/components/schemas/Common.Errors.")));\n` +
        `const errorsOwnProblemJson = errorResponses.length > 0 && errorResponses.every((response) => Object.keys(response.content ?? {}).length === 1 && response.content[ProblemDetailsMediaType]);\n` +
        `const workbenchOperations = Object.entries(openapi.paths).filter(([path]) => path.startsWith("/runner/")).flatMap(([path, pathItem]) => Object.entries(pathItem).map(([method, operation]) => ({ path, method, operation })));\n` +
        `const mcpPassthroughPaths = new Set(["/runner/mcp/{resource}/tools", "/runner/mcp/{resource}/tools/call", "/runner/mcp/{resource}/resources/read"]);\n` +
        `const mcpPassthroughOperations = workbenchOperations.filter(({ path }) => mcpPassthroughPaths.has(path));\n` +
        `const privateWorkbenchOperations = workbenchOperations.filter(({ path, method }) => !(path === "/runner/session" && method === "post") && !mcpPassthroughPaths.has(path));\n` +
        `const opaqueJsonBody = (content) => Object.keys(content ?? {}).length === 1 && JSON.stringify(content?.["application/json"]?.schema) === "{}";\n` +
        `const opaqueMcpPassthrough = mcpPassthroughOperations.length === 3 && mcpPassthroughOperations.every(({ method, operation }) => operation.security === undefined && opaqueJsonBody(operation.responses?.["200"]?.content) && (method === "get" ? operation.requestBody === undefined : operation.requestBody?.required === true && opaqueJsonBody(operation.requestBody.content)));\n` +
        `const workbenchCookieAuth = workbenchOperations.length === 54 && privateWorkbenchOperations.length === 50 && openapi.components?.securitySchemes?.RunnerMcpSessionCookieAuth?.name === "qyl-mcp-session" && privateWorkbenchOperations.every(({ operation }) => operation.security?.some((entry) => "RunnerMcpSessionCookieAuth" in entry));\n` +
        `const typedBootstrapCookie = openapi.paths["/runner/session"]?.post?.responses?.["200"]?.headers?.["Set-Cookie"]?.required === true;\n` +
        `const logStreamCapacityResponseDeclared = (() => { const content = openapi.paths["/api/v1/stream/logs"]?.get?.responses?.["503"]?.content ?? {}; return Object.keys(content).length === 1 && content[ProblemDetailsMediaType]?.schema?.$ref === "#/components/schemas/Common.Errors.ServiceUnavailableError"; })();\n` +
        `const typedQueryPaths = ["/api/v1/traces", "/api/v1/logs", "/api/v1/metrics", "/api/v1/profiles", "/api/v1/profiles/by-trace/{traceId}", "/api/v1/profiles/by-span/{spanId}", "/api/v1/sessions", "/api/v1/sessions/stats", "/api/v1/stream/logs"];\n` +
        `const typedQueryValidationResponsesDeclared = typedQueryPaths.every((path) => { const content = openapi.paths[path]?.get?.responses?.["400"]?.content ?? {}; return Object.keys(content).length === 1 && content[ProblemDetailsMediaType]?.schema?.$ref === "#/components/schemas/Common.Errors.ValidationError"; });\n` +
        `const metricsListDeclared = openapi.paths["/api/v1/metrics"]?.get?.responses?.["200"]?.content?.["application/json"]?.schema?.properties?.items?.items?.$ref === "#/components/schemas/OTel.Metrics.MetricPoint";\n` +
        `const costSurfaceAbsent = Object.keys(schema.$defs).every((name) => !name.startsWith("Cost.")) && Object.keys(openapi.paths).every((path) => !path.startsWith("/api/v1/cost"));\n` +
        `if (ProblemDetailsMediaType !== "application/problem+json" || !errorsOwnProblemJson || !workbenchCookieAuth || !opaqueMcpPassthrough || !typedBootstrapCookie || !logStreamCapacityResponseDeclared || !typedQueryValidationResponsesDeclared || !metricsListDeclared || !exactMetricContract || !eventLogContract || !losslessAttributeValue || !exactEntityRef || !exactServerConfigurationUnion || !exactAssertionUnion || !exactExportUnion || !opaqueSdkBoundaries || !costSurfaceAbsent || HealthStatusValues.healthy !== "healthy" || RunnerResourceLifecycleValues.ready !== "ready" || RunnerResourceKindValues.stdio !== "stdio" || RunnerMcpTransportKindValues.streamableHttp !== "streamable_http" || RunnerMcpExecutionStatusValues.timedOut !== "timed_out" || RunnerMcpEvaluationExportFormatValues.report !== "report" || !schema.$defs["Mcp.Tools.FetchTelemetryInput"]) process.exit(1);\n`,
    );
    run("node", ["smoke.mjs"], npmDir);
    await writeFile(
      join(npmDir, "smoke.ts"),
      `import type { Attribute, AttributeValue, EntityRef, GaugeMetricPoint, HistogramMetricPoint, LogRecord, MetricDoubleValue, MetricIntegerValue, MetricPoint, Resource, SummaryQuantileValue, SumMetricPoint } from ${JSON.stringify(`${npmPackage}/types`)};\n` +
        `const eventLog: LogRecord = { time_unix_nano: 2, observed_time_unix_nano: 3, severity_number: 9, body: { string_value: "evaluation completed" }, event_name: "gen_ai.evaluation.result", resource: { "service.name": "evaluator" } };\n` +
        `const emptyAttribute: Attribute = { key: "empty", value: null };\n` +
        `const intAttribute: Attribute = { key: "int", value: { type: "int", value: "9223372036854775807" } };\n` +
        `const doubleAttribute: Attribute = { key: "double", value: { type: "double", value: "Infinity" } };\n` +
        `const kvlistAttribute: Attribute = { key: "kvlist", value: { type: "kvlist", values: { empty: null, nested: [intAttribute.value, doubleAttribute.value] } } };\n` +
        `const entityRef: EntityRef = { schema_url: "https://opentelemetry.io/schemas/1.43.0", type: "service", id_keys: ["service.instance.id"], description_keys: ["service.version"] };\n` +
        `const metricResource: Resource = { "service.name": "orders", attributes: [emptyAttribute, intAttribute, doubleAttribute, kvlistAttribute], entity_refs: [entityRef] };\n` +
        `const integerValue: MetricIntegerValue = { as_int: "9223372036854775807" };\n` +
        `const namedDouble: MetricDoubleValue = { as_double: "NaN" };\n` +
        `const histogram: HistogramMetricPoint = { type: "histogram", name: "gen_ai.client.token.usage", unit: "{token}", start_time_unix_nano: "1", time_unix_nano: "2", flags: 0, resource: metricResource, count: "18446744073709551615", sum: "Infinity", bucket_counts: ["0", "18446744073709551615"], explicit_bounds: [128], min: "-Infinity", max: "NaN", aggregation_temporality: 1 };\n` +
        `const finiteGauge: GaugeMetricPoint = { type: "gauge", name: "queue.depth", start_time_unix_nano: "1", time_unix_nano: "2", flags: 0, resource: metricResource, value: { as_double: 1 } };\n` +
        `const noRecordedGauge: GaugeMetricPoint = { type: "gauge", name: "queue.depth", start_time_unix_nano: "1", time_unix_nano: "2", flags: 1, resource: metricResource };\n` +
        `const noRecordedSum: SumMetricPoint = { type: "sum", name: "requests", start_time_unix_nano: "1", time_unix_nano: "2", flags: 1, resource: metricResource, aggregation_temporality: 2, is_monotonic: true };\n` +
        `const finiteSummaryQuantile: SummaryQuantileValue = { quantile: 0.5, value: 1 };\n` +
        `const infiniteSummaryQuantile: SummaryQuantileValue = { quantile: 1, value: "Infinity" };\n` +
        `// @ts-expect-error Summary quantile values cannot be NaN.\n` +
        `const invalidNaNSummaryQuantile: SummaryQuantileValue = { quantile: 0.5, value: "NaN" };\n` +
        `// @ts-expect-error Summary quantile values cannot be negative infinity.\n` +
        `const invalidNegativeInfinitySummaryQuantile: SummaryQuantileValue = { quantile: 0.5, value: "-Infinity" };\n` +
        `const point: MetricPoint = histogram;\n` +
        `// @ts-expect-error Attribute integers require the tagged lossless representation.\n` +
        `const invalidAttribute: AttributeValue = 1;\n` +
        `// @ts-expect-error Named doubles use the canonical ProtoJSON spelling.\n` +
        `const invalidNamedDouble: MetricDoubleValue = { as_double: "nan" };\n` +
        `// @ts-expect-error OTLP int64 values are decimal JSON strings, never lossy JS numbers.\n` +
        `const invalidIntegerValue: MetricIntegerValue = { as_int: 9223372036854775807 };\n` +
        `// @ts-expect-error OTLP uint64 bucket counts are decimal JSON strings.\n` +
        `const invalidHistogram: HistogramMetricPoint = { ...histogram, bucket_counts: [1] };\n` +
        `// @ts-expect-error OTLP nanosecond timestamps are decimal JSON strings.\n` +
        `const invalidTimestamp: HistogramMetricPoint = { ...histogram, time_unix_nano: 2 };\n` +
        `void [eventLog, emptyAttribute, intAttribute, doubleAttribute, kvlistAttribute, entityRef, metricResource, integerValue, namedDouble, finiteGauge, noRecordedGauge, noRecordedSum, finiteSummaryQuantile, infiniteSummaryQuantile, point, invalidAttribute, invalidNamedDouble, invalidNaNSummaryQuantile, invalidNegativeInfinitySummaryQuantile, invalidIntegerValue, invalidHistogram, invalidTimestamp];\n`,
    );
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
    await writeFile(
      join(dotnetDir, "Program.cs"),
      `using System.Text.Json;\nusing System.Text.Json.Nodes;\nusing System.Text.Json.Serialization;\nusing ModelContextProtocol;\nusing ModelContextProtocol.Protocol;\nusing Qyl.Api.Contracts.Common.Errors;\nusing Qyl.Api.Contracts.Common.Pagination;\nusing System.Linq;\nusing Qyl.Api.Contracts.Health;\nusing Qyl.Api.Contracts.Mcp.Tools;\nusing Qyl.Api.Contracts.OTel.Enums;\nusing Qyl.Api.Contracts.OTel.Logs;\nusing Qyl.Api.Contracts.OTel.Metrics;\nusing Qyl.Api.Contracts.Runner;\nusing Qyl.Api.Contracts.Runner.Mcp;\n#pragma warning disable MCPEXP001\n` +
        `using Qyl.Api.Contracts.Common;\nusing OTelAttribute = Qyl.Api.Contracts.Common.Attribute;\nusing OTelResource = Qyl.Api.Contracts.OTel.Resource.Resource;\n` +
        `var health = JsonSerializer.Serialize(HealthStatus.Healthy);\n` +
        `var lifecycle = JsonSerializer.Serialize(RunnerResourceLifecycle.Ready);\n` +
        `var kind = JsonSerializer.Serialize(RunnerResourceKind.Stdio);\n` +
        `var eventLog = new LogRecord { TimeUnixNano = 2, ObservedTimeUnixNano = 3, SeverityNumber = SeverityNumber.Info, Body = new LogBodyString { StringValue = "evaluation completed" }, EventName = "gen_ai.evaluation.result", Resource = new OTelResource { ServiceName = "evaluator" } };\n` +
        `var eventLogWire = JsonSerializer.Serialize(eventLog);\n` +
        `var emptyAttribute = new OTelAttribute { Key = "empty", Value = null };\n` +
        `var intAttribute = new OTelAttribute { Key = "int", Value = new AttributeIntValue { Type = "int", Value = long.MaxValue } };\n` +
        `var doubleAttribute = new OTelAttribute { Key = "double", Value = new AttributeDoubleValue { Type = "double", Value = double.PositiveInfinity } };\n` +
        `var kvlistAttribute = new OTelAttribute { Key = "kvlist", Value = new AttributeKeyValueListValue { Type = "kvlist", Values = new Dictionary<string, object?> { ["empty"] = null, ["nested"] = new AttributeIntValue { Type = "int", Value = 1 } } } };\n` +
        `var entityRef = new EntityRef { SchemaUrl = "https://opentelemetry.io/schemas/1.43.0", Type = "service", IdKeys = ["service.instance.id"], DescriptionKeys = ["service.version"] };\n` +
        `var metricResource = new OTelResource { ServiceName = "orders", Attributes = [emptyAttribute, intAttribute, doubleAttribute, kvlistAttribute], EntityRefs = [entityRef] };\n` +
        `var resourceWire = JsonSerializer.Serialize(metricResource);\n` +
        `var resourceRoundTrip = JsonSerializer.Deserialize<OTelResource>(resourceWire);\n` +
        `MetricPoint metricPoint = new HistogramMetricPoint { Name = "gen_ai.client.token.usage", Unit = "{token}", StartTimeUnixNano = 1, TimeUnixNano = 2, Flags = 0, Resource = metricResource, Count = ulong.MaxValue, BucketCounts = [0, ulong.MaxValue], ExplicitBounds = [128], AggregationTemporality = AggregationTemporality.Delta };\n` +
        `MetricPoint noRecordedPoint = new GaugeMetricPoint { Name = "queue.depth", StartTimeUnixNano = 1, TimeUnixNano = 2, Flags = 1, Resource = metricResource };\n` +
        `MetricPoint specialDoublePoint = new GaugeMetricPoint { Name = "temperature", StartTimeUnixNano = 1, TimeUnixNano = 2, Flags = 0, Resource = metricResource, Value = new MetricDoubleValue { AsDouble = double.NaN } };\n` +
        `var metricPage = new CursorPageMetricPoint { Items = [metricPoint, noRecordedPoint, specialDoublePoint], HasMore = false };\n` +
        `var summaryQuantile = new SummaryQuantileValue { Quantile = 1, Value = double.PositiveInfinity };\n` +
        `var summaryQuantileWire = JsonSerializer.Serialize(summaryQuantile);\n` +
        `var metricWire = JsonSerializer.Serialize(metricPage);\n` +
        `var metricRoundTrip = JsonSerializer.Deserialize<CursorPageMetricPoint>(metricWire);\n` +
        `var noRecordedValueOmitted = JsonNode.Parse(metricWire)?["items"]?[1]?.AsObject().ContainsKey("value") == false;\n` +
        `var ambiguousMetricValueRejected = false;\n` +
        `try { JsonSerializer.Deserialize<MetricNumberValue>("{\\\"as_int\\\":\\\"1\\\",\\\"as_double\\\":2}"); } catch (JsonException) { ambiguousMetricValueRejected = true; }\n` +
        `var state = new RunnerResourceState { Name = "demo", Lifecycle = RunnerResourceLifecycle.Ready, Timestamp = DateTimeOffset.UnixEpoch, Kind = RunnerResourceKind.Stdio };\n` +
        `RunnerMcpServerConfiguration serverConfiguration = new RunnerMcpStdioServerConfiguration { Command = "node", Arguments = ["server.mjs"], Environment = [new RunnerMcpEnvironmentSecretReference { Name = "API_TOKEN", Secret = new RunnerMcpSecretReference { Source = "environment", EnvironmentVariable = "QYL_MCP_API_TOKEN" } }] };\n` +
        `RunnerMcpTestAssertion assertion = new RunnerMcpStatusAssertion { Id = "status", Expected = [RunnerMcpExecutionStatus.Succeeded] };\n` +
        `RunnerMcpEvaluationExportPayload exportPayload = new RunnerMcpEvaluationReportExportPayload { Markdown = "# Evaluation", ExportedAt = DateTimeOffset.UnixEpoch };\n` +
        `var sdkRequest = new CallToolRequestParams { Name = "inspect", Arguments = new Dictionary<string, JsonElement> { ["trace_id"] = JsonSerializer.Deserialize<JsonElement>("\\\"abc\\\"") } };\n` +
        `var executionRequest = new RunnerMcpExecutionRequest { ToolName = sdkRequest.Name, Arguments = sdkRequest.Arguments, TimeoutMs = 30000, IdempotencyKey = "smoke-key" };\n` +
        `var toolInput = new FetchTelemetryInput { View = FetchTelemetryView.Traces };\n` +
        `var serverConfigurationWire = JsonSerializer.Serialize(serverConfiguration);\n` +
        `var serverConfigurationRoundTrip = JsonSerializer.Deserialize<RunnerMcpServerConfiguration>(serverConfigurationWire);\n` +
        `var assertionWire = JsonSerializer.Serialize(assertion);\n` +
        `var assertionRoundTrip = JsonSerializer.Deserialize<RunnerMcpTestAssertion>(assertionWire);\n` +
        `var exportPayloadWire = JsonSerializer.Serialize(exportPayload);\n` +
        `var exportPayloadRoundTrip = JsonSerializer.Deserialize<RunnerMcpEvaluationExportPayload>(exportPayloadWire);\n` +
        `var executionRequestWire = JsonSerializer.Serialize(executionRequest);\n` +
        `var otlpFidelityValid = resourceRoundTrip is not null && resourceRoundTrip.Attributes is { Count: 4 } && resourceRoundTrip.Attributes[0].Value is null && resourceRoundTrip.EntityRefs?[0] is { Type: "service", IdKeys.Count: 1 } && resourceWire.Contains("\\\"type\\\":\\\"int\\\",\\\"value\\\":\\\"9223372036854775807\\\"") && resourceWire.Contains("\\\"type\\\":\\\"double\\\",\\\"value\\\":\\\"Infinity\\\"") && resourceWire.Contains("\\\"type\\\":\\\"kvlist\\\"") && noRecordedValueOmitted && metricRoundTrip?.Items[1] is GaugeMetricPoint { Flags: 1, Value: null } && metricRoundTrip.Items[2] is GaugeMetricPoint { Value: MetricDoubleValue specialDouble } && double.IsNaN(specialDouble.AsDouble) && metricWire.Contains("\\\"as_double\\\":\\\"NaN\\\"");\n` +
        `if (ProblemDetailsMediaType.Value != "application/problem+json" || !eventLogWire.Contains("\\\"event_name\\\":\\\"gen_ai.evaluation.result\\\"") || !summaryQuantileWire.Contains("\\\"value\\\":\\\"Infinity\\\"") || metricRoundTrip?.Items[0] is not HistogramMetricPoint { Count: ulong.MaxValue } || !metricWire.Contains("\\\"time_unix_nano\\\":\\\"2\\\"") || !metricWire.Contains("\\\"count\\\":\\\"18446744073709551615\\\"") || !metricWire.Contains("\\\"bucket_counts\\\":[\\\"0\\\",\\\"18446744073709551615\\\"]") || !ambiguousMetricValueRejected || !otlpFidelityValid || typeof(FetchTelemetryInput).Namespace != "Qyl.Api.Contracts.Mcp.Tools" || typeof(FetchTelemetryInput).Assembly.GetTypes().Any(type => type.Namespace is not null && type.Namespace.StartsWith("Qyl.Api.Contracts.Cost")) || health != "\\\"healthy\\\"" || lifecycle != "\\\"ready\\\"" || kind != "\\\"stdio\\\"" || state.Kind != RunnerResourceKind.Stdio || toolInput.View != FetchTelemetryView.Traces || serverConfigurationRoundTrip is not RunnerMcpStdioServerConfiguration || assertionRoundTrip is not RunnerMcpStatusAssertion || exportPayloadRoundTrip is not RunnerMcpEvaluationReportExportPayload || !serverConfigurationWire.Contains("\\\"transport\\\":\\\"stdio\\\"") || !serverConfigurationWire.Contains("\\\"environmentVariable\\\":\\\"QYL_MCP_API_TOKEN\\\"") || !assertionWire.Contains("\\\"kind\\\":\\\"status\\\"") || !exportPayloadWire.Contains("\\\"format\\\":\\\"report\\\"") || executionRequest.ToolName != "inspect" || executionRequest.TimeoutMs != 30000 || !executionRequestWire.Contains("\\\"trace_id\\\":\\\"abc\\\"")) return 1;\nreturn 0;\n`,
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
