import { readFile } from "node:fs/promises";
import Ajv2020 from "ajv/dist/2020.js";

const schemaPath = "generated/json-schema/qyl-api-schema.json";
const schema = JSON.parse(await readFile(schemaPath, "utf8"));
const openapi = JSON.parse(await readFile("generated/openapi/qyl.openapi.json", "utf8"));
const tsRuntime = await readFile("generated/ts-runtime/api.d.ts", "utf8");
const csharpRuntime = await readFile(
  "generated/contracts/Qyl/Api/Contracts/Runner/Mcp.cs",
  "utf8",
);
const csharpRunnerRuntime = await readFile(
  "generated/contracts/Qyl/Api/Contracts/Runner.cs",
  "utf8",
);
const csharpLogsRuntime = await readFile(
  "generated/contracts/Qyl/Api/Contracts/OTel/Logs.cs",
  "utf8",
);
const csharpMetricsRuntime = await readFile(
  "generated/contracts/Qyl/Api/Contracts/OTel/Metrics.cs",
  "utf8",
);
const defs = schema.$defs ?? {};
const ajv = new Ajv2020({ allErrors: true, strict: true, validateFormats: false });
ajv.addKeyword({ keyword: "x-csharp-struct", schemaType: "boolean" });
ajv.addKeyword({ keyword: "x-csharp-type", schemaType: "string" });
ajv.addKeyword({ keyword: "discriminator", schemaType: "object" });

function validatorFor(definition) {
  return ajv.compile({
    $schema: schema.$schema,
    $defs: defs,
    $ref: `#/$defs/${definition}`,
  });
}

function assertValid(validate, fixture, label) {
  if (!validate(fixture)) {
    throw new Error(`${label} must validate: ${ajv.errorsText(validate.errors, { separator: "\n" })}`);
  }
}

function assertInvalid(validate, fixture, label) {
  if (validate(fixture)) throw new Error(`${label} must be rejected.`);
}

function assertReferences(definition, expected) {
  const actual = (defs[definition]?.oneOf ?? []).map((variant) => variant.$ref);
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${definition} oneOf variants drifted: ${JSON.stringify(actual)}.`);
  }
}

function assertAnyOfReferences(definition, expected) {
  const actual = (defs[definition]?.anyOf ?? []).map((variant) => variant.$ref);
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${definition} anyOf variants drifted: ${JSON.stringify(actual)}.`);
  }
}

const httpMethods = new Set(["delete", "get", "head", "options", "patch", "post", "put", "trace"]);
const expectedOperationDefinitions = new Set();
for (const [path, pathItem] of Object.entries(openapi.paths ?? {})) {
  for (const [method, operation] of Object.entries(pathItem ?? {})) {
    if (!httpMethods.has(method) || !operation || typeof operation !== "object") continue;

    const operationId = operation.operationId;
    const requestSchemas = Object.values(operation.requestBody?.content ?? {})
      .filter((media) => media?.schema).map((media) => media.schema);
    if (requestSchemas.length > 0) {
      if (requestSchemas.length !== 1 || typeof operationId !== "string") {
        throw new Error(`${method.toUpperCase()} ${path} must have one stably named request body schema.`);
      }
      expectedOperationDefinitions.add(`Operations.${operationId}.Request`);
    }

    for (const [status, response] of Object.entries(operation.responses ?? {})) {
      const responseSchemas = Object.values(response?.content ?? {})
        .filter((media) => media?.schema).map((media) => media.schema);
      if (responseSchemas.length === 0) continue;
      if (responseSchemas.length !== 1 || typeof operationId !== "string") {
        throw new Error(`${method.toUpperCase()} ${path} response ${status} must have one stably named body schema.`);
      }
      expectedOperationDefinitions.add(`Operations.${operationId}.Response.${status}`);
    }
  }
}
const actualOperationDefinitions = new Set(Object.keys(defs).filter((name) => name.startsWith("Operations.")));
const missingOperationDefinitions = [...expectedOperationDefinitions]
  .filter((name) => !actualOperationDefinitions.has(name));
const unexpectedOperationDefinitions = [...actualOperationDefinitions]
  .filter((name) => !expectedOperationDefinitions.has(name));
if (missingOperationDefinitions.length > 0 || unexpectedOperationDefinitions.length > 0) {
  throw new Error(
    `Operation body definition inventory drifted. Missing: ${missingOperationDefinitions.join(", ") || "none"}. ` +
    `Unexpected: ${unexpectedOperationDefinitions.join(", ") || "none"}.`,
  );
}

const opaqueMcpOperationFixtures = new Map([
  ["Operations.RunnerMcpApi_listTools.Response.200", {
    tools: [{ name: "inspect", inputSchema: { type: "object" }, futureSdkField: true }],
    nextCursor: "page-2",
    _meta: { catalog: "live" },
  }],
  ["Operations.RunnerMcpApi_callTool.Request", {
    name: "inspect",
    arguments: { count: 3 },
    task: { ttl: 30_000 },
    _meta: { progressToken: "progress-1" },
  }],
  ["Operations.RunnerMcpApi_callTool.Response.200", {
    content: [{ type: "text", text: "complete", futureSdkField: true }],
    structuredContent: { accepted: true },
    isError: false,
    task: { taskId: "task-1", status: "working" },
    _meta: { result: "live" },
  }],
  ["Operations.RunnerMcpApi_readResource.Request", {
    uri: "qyl://resource/static",
    _meta: { request: "live" },
  }],
  ["Operations.RunnerMcpApi_readResource.Response.200", {
    contents: [{ uri: "qyl://resource/static", mimeType: "text/plain", text: "body" }],
    _meta: { source: "server" },
  }],
]);
for (const [definition, fixture] of opaqueMcpOperationFixtures) {
  if (JSON.stringify(defs[definition]) !== "{}") {
    throw new Error(`${definition} must remain opaque; the MCP SDK owns its protocol body.`);
  }
  assertValid(validatorFor(definition), fixture, `${definition} representative SDK payload`);
}

const cursorPageDefinitions = new Map([
  ["Operations.LogsApi_list.Response.200", "#/$defs/OTel.Logs.LogRecord"],
  ["Operations.MetricsApi_list.Response.200", "#/$defs/OTel.Metrics.MetricPoint"],
  ["Operations.SessionsApi_list.Response.200", "#/$defs/Domains.Observe.Session.SessionEntity"],
  ["Operations.SessionsApi_getTraces.Response.200", "#/$defs/OTel.Traces.Trace"],
  ["Operations.TracesApi_list.Response.200", "#/$defs/OTel.Traces.Trace"],
  ["Operations.TracesApi_getSpans.Response.200", "#/$defs/OTel.Traces.Span"],
]);
for (const [definition, itemReference] of cursorPageDefinitions) {
  const page = defs[definition];
  if (!page ||
      !page.required?.includes("items") ||
      !page.required?.includes("has_more") ||
      page.properties?.items?.type !== "array" ||
      page.properties.items.items?.$ref !== itemReference ||
      page.properties?.next_cursor?.type !== "string" ||
      page.properties?.prev_cursor?.type !== "string" ||
      page.properties?.has_more?.type !== "boolean" ||
      JSON.stringify(page.unevaluatedProperties) !== JSON.stringify({ not: {} })) {
    throw new Error(`${definition} must remain the exact closed CursorPage envelope for ${itemReference}.`);
  }

  const validatePage = validatorFor(definition);
  assertValid(
    validatePage,
    { items: [], next_cursor: "next", prev_cursor: "previous", has_more: false },
    `${definition} valid empty page`,
  );
  assertInvalid(validatePage, { items: [] }, `${definition} without has_more`);
  assertInvalid(validatePage, { items: [], has_more: "false" }, `${definition} with non-boolean has_more`);
  assertInvalid(validatePage, { items: [{}], has_more: false }, `${definition} with an invalid item`);
  assertInvalid(validatePage, { items: [], has_more: false, total: 0 }, `${definition} with an undeclared field`);
}

if (!/export interface RunnerMcpSessionBootstrapResponse extends RunnerMcpWorkbenchSession\s*\{\s*\}/u.test(tsRuntime)) {
  throw new Error("TypeScript session bootstrap DTO must have the exact session body shape without a nested session property.");
}
const csharpBootstrap = /public sealed class RunnerMcpSessionBootstrapResponse\s*\{(?<body>[\s\S]*?)\n\}/u.exec(csharpRuntime)?.groups?.body;
if (!csharpBootstrap?.includes('[JsonPropertyName("id")]') ||
    csharpBootstrap.includes('[JsonPropertyName("session")]')) {
  throw new Error("C# session bootstrap DTO must have the exact session body shape without a nested Session property.");
}
for (const id of [
  "RunnerMcpSessionId",
  "RunnerMcpWorkspaceId",
  "RunnerMcpServerId",
  "RunnerMcpExecutionId",
  "RunnerMcpTestCaseId",
  "RunnerMcpSuiteId",
  "RunnerMcpEvaluationRunId",
  "RunnerMcpEvaluationExportId",
]) {
  if (!tsRuntime.includes(`readonly __brand: "${id}"`)) {
    throw new Error(`${id} must remain a branded TypeScript identifier.`);
  }
}
for (const marker of [
  '[JsonPolymorphic(TypeDiscriminatorPropertyName = "format")]',
  '[JsonDerivedType(typeof(RunnerMcpEvaluationJsonExportPayload), "json")]',
  '[JsonDerivedType(typeof(RunnerMcpEvaluationReportExportPayload), "report")]',
  "public interface RunnerMcpEvaluationExportPayload",
  "public required Qyl.Api.Contracts.Runner.Mcp.RunnerMcpEvaluationExportPayload Payload",
]) {
  if (!csharpRuntime.includes(marker)) {
    throw new Error(`C# evaluation export payload lost generated polymorphism: ${marker}.`);
  }
}

for (const model of ["GaugeMetricPoint", "SumMetricPoint"]) {
  const body = new RegExp(
    `public sealed class ${model} : MetricPoint\\s*\\{(?<body>[\\s\\S]*?)\\n\\}`,
    "u",
  ).exec(csharpMetricsRuntime)?.groups?.body;
  if (!body?.includes("[JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]\n    [JsonPropertyName(\"value\")]")) {
    throw new Error(`${model}.Value must omit null so NO_RECORDED_VALUE has no value field.`);
  }
}

const summaryQuantileBody = /public sealed class SummaryQuantileValue\s*\{(?<body>[\s\S]*?)\n\}/u
  .exec(csharpMetricsRuntime)?.groups?.body;
if (!summaryQuantileBody?.includes(
  "[JsonNumberHandling(JsonNumberHandling.AllowNamedFloatingPointLiterals)]\n" +
  "    [JsonPropertyName(\"value\")]\n    public required double Value",
)) {
  throw new Error("SummaryQuantileValue.Value must retain its generated double/positive-infinity wire mapping.");
}

const bytes = { type: "bytes", base64: "/wCA/g==" };
const intValue = (value) => ({ type: "int", value: String(value) });
const doubleValue = (value) => ({ type: "double", value });
const kvlistValue = (values) => ({ type: "kvlist", values });
if (Buffer.from(bytes.base64, "base64").toString("base64") !== bytes.base64) {
  throw new Error("The byte fixture is not canonical base64.");
}

const validateAttribute = validatorFor("Common.AttributeValue");
const attributeFixtures = [
  ["empty AnyValue", null],
  ["tagged bytes", bytes],
  ["signed 64-bit integer", intValue("9223372036854775807")],
  ["finite double", doubleValue(1)],
  ["non-finite double", doubleValue("-Infinity")],
  ["recursive kvlist", kvlistValue({
    http: kvlistValue({ method: "GET", retry: true }),
    payload: bytes,
    count: intValue(3),
    empty: null,
  })],
  ["nested arrays", [["outer", intValue(1)], [bytes, [false, doubleValue(2.5), null]]]],
  ["heterogeneous array", [
    "text", true, intValue(42), doubleValue(2.5), bytes, null,
    kvlistValue({ nested: [false, "tail"] }),
  ]],
];
for (const [label, fixture] of attributeFixtures) assertValid(validateAttribute, fixture, label);
assertInvalid(validateAttribute, 1, "untagged integer attribute");
assertInvalid(validateAttribute, 1.5, "untagged double attribute");
assertInvalid(validateAttribute, { nested: true }, "untagged key-value-list attribute");
assertInvalid(validateAttribute, { type: "int", value: 1 }, "numeric JSON int64 attribute");
assertInvalid(validateAttribute, { type: "double", value: "nan" }, "non-canonical named double attribute");

const bytesSchema = defs["Common.AttributeBytesValue"];
if (bytesSchema?.properties?.type?.enum?.[0] !== "bytes" ||
    bytesSchema?.properties?.base64?.contentEncoding !== "base64") {
  throw new Error("Common.AttributeBytesValue must retain the tagged base64 wire shape.");
}
const validateAttributeKvList = validatorFor("Common.AttributeKeyValueListValue");
assertInvalid(validateAttributeKvList, bytes, "bytes misclassified as a key-value-list");
assertValid(validateAttributeKvList, kvlistValue({ type: "bytes", base64: "/wCA/g==" }),
  "key-value-list containing fields that resemble the bytes wrapper");

const validateOtelResource = validatorFor("OTel.Resource.Resource");
const entityResource = {
  "service.name": "checkout",
  attributes: [
    { key: "service.instance.id", value: "checkout-1" },
    { key: "service.version", value: "1.2.3" },
  ],
  entity_refs: [{
    schema_url: "https://opentelemetry.io/schemas/1.43.0",
    type: "service",
    id_keys: ["service.instance.id"],
    description_keys: ["service.version"],
  }],
};
assertValid(validateOtelResource, entityResource, "Resource with an entity reference");
assertValid(validateOtelResource, {
  "service.name": "checkout",
  entity_refs: [{ type: "service", id_keys: ["service.instance.id"], description_keys: [] }],
}, "Resource entity reference with no description keys");
assertInvalid(validateOtelResource, {
  "service.name": "checkout",
  entity_refs: [{ type: "", id_keys: ["service.instance.id"] }],
}, "Resource entity reference with an empty type");
assertInvalid(validateOtelResource, {
  "service.name": "checkout",
  entity_refs: [{ type: "service", id_keys: [] }],
}, "Resource entity reference with no identity keys");
assertInvalid(validateOtelResource, {
  "service.name": "checkout",
  entity_refs: [{ type: "service", id_keys: [""] }],
}, "Resource entity reference with an empty identity key");

const validateLogRecord = validatorFor("OTel.Logs.LogRecord");
const eventLogRecord = {
  time_unix_nano: 2,
  observed_time_unix_nano: 3,
  severity_number: 9,
  body: { string_value: "evaluation completed" },
  event_name: "gen_ai.evaluation.result",
  resource: { "service.name": "evaluator" },
};
assertValid(validateLogRecord, eventLogRecord, "OTLP event log record");
assertValid(
  validateLogRecord,
  Object.fromEntries(Object.entries(eventLogRecord).filter(([key]) => key !== "event_name")),
  "ordinary OTLP log record without event_name",
);
assertInvalid(
  validateLogRecord,
  { ...eventLogRecord, event_name: 42 },
  "OTLP event log record with non-string event_name",
);
if (!tsRuntime.includes('"event_name"?: string;') ||
    !csharpLogsRuntime.includes('[JsonPropertyName("event_name")]') ||
    !csharpLogsRuntime.includes("public string? EventName { get; init; }")) {
  throw new Error("OTel LogRecord event_name must be generated for both TypeScript and C# consumers.");
}

assertAnyOfReferences("OTel.Metrics.MetricNumberValue", [
  "#/$defs/OTel.Metrics.MetricIntegerValue",
  "#/$defs/OTel.Metrics.MetricDoubleValue",
]);
assertAnyOfReferences("OTel.Metrics.MetricPoint", [
  "#/$defs/OTel.Metrics.GaugeMetricPoint",
  "#/$defs/OTel.Metrics.SumMetricPoint",
  "#/$defs/OTel.Metrics.HistogramMetricPoint",
  "#/$defs/OTel.Metrics.ExponentialHistogramMetricPoint",
  "#/$defs/OTel.Metrics.SummaryMetricPoint",
]);

const validateMetricNumber = validatorFor("OTel.Metrics.MetricNumberValue");
assertValid(validateMetricNumber, { as_int: "42" }, "integer metric value");
assertValid(validateMetricNumber, { as_double: 2.5 }, "double metric value");
for (const named of ["NaN", "Infinity", "-Infinity"]) {
  assertValid(validateMetricNumber, { as_double: named }, `${named} metric value`);
}
assertInvalid(validateMetricNumber, { as_int: "42", as_double: 2.5 }, "ambiguous metric value");
assertInvalid(validateMetricNumber, { as_int: 42 }, "numeric JSON encoding for a 64-bit metric integer");
assertInvalid(validateMetricNumber, { as_double: "nan" }, "non-canonical named metric double");
assertInvalid(validateMetricNumber, {}, "missing metric value");

const summaryQuantileDouble = defs["OTel.Metrics.SummaryQuantileDouble"];
const summaryQuantileVariants = summaryQuantileDouble?.anyOf ?? [];
const summaryQuantileFinite = defs["OTel.Metrics.SummaryQuantileFiniteValue"];
if (summaryQuantileVariants.length !== 2 ||
    !summaryQuantileVariants.some((variant) =>
      variant.$ref === "#/$defs/OTel.Metrics.SummaryQuantileFiniteValue") ||
    summaryQuantileFinite?.type !== "number" || summaryQuantileFinite.minimum !== 0 ||
    !summaryQuantileVariants.some((variant) =>
      JSON.stringify(variant.enum) === JSON.stringify(["Infinity"]))) {
  throw new Error("Summary quantile values must be non-negative finite doubles or positive infinity.");
}

const metricCommon = {
  name: "gen_ai.client.token.usage",
  unit: "{token}",
  start_time_unix_nano: "1000",
  time_unix_nano: "2000",
  flags: 0,
  resource: { "service.name": "checkout" },
  instrumentation_scope: { name: "OpenTelemetry.Instrumentation.GenAI", version: "1.0.0" },
  attributes: [
    { key: "gen_ai.provider.name", value: "openai" },
    { key: "gen_ai.request.model", value: "gpt-4.1" },
    { key: "gen_ai.token.type", value: "input" },
  ],
};
const validateMetricPoint = validatorFor("OTel.Metrics.MetricPoint");
const metricFixtures = [
  { ...metricCommon, type: "gauge", value: { as_double: 1.5 } },
  {
    ...metricCommon,
    type: "sum",
    value: { as_int: "3" },
    aggregation_temporality: 2,
    is_monotonic: true,
  },
  {
    ...metricCommon,
    type: "histogram",
    count: "2",
    sum: 180,
    bucket_counts: ["0", "1", "1"],
    explicit_bounds: [64, 256],
    min: 50,
    max: 130,
    aggregation_temporality: 1,
    exemplars: [{ time_unix_nano: "1500", value: { as_int: "130" }, trace_id: "0af7651916cd43dd8448eb211c80319c", span_id: "b7ad6b7169203331" }],
  },
  {
    ...metricCommon,
    type: "exponential_histogram",
    count: "2",
    sum: 3.5,
    scale: 3,
    zero_count: "0",
    zero_threshold: 0,
    positive: { offset: 0, bucket_counts: ["1", "1"] },
    negative: { offset: 0, bucket_counts: [] },
    aggregation_temporality: 2,
  },
  {
    ...metricCommon,
    type: "summary",
    count: "2",
    sum: 3.5,
    quantile_values: [{ quantile: 0.5, value: 1.5 }, { quantile: 1, value: 2 }],
  },
];
for (const fixture of metricFixtures) assertValid(validateMetricPoint, fixture, `OTLP ${fixture.type} metric point`);
assertValid(validateMetricPoint, {
  ...metricFixtures[2],
  sum: "NaN",
  min: "-Infinity",
  max: "Infinity",
}, "histogram with non-finite summary values");
assertValid(validateMetricPoint, {
  ...metricFixtures[3],
  sum: "Infinity",
  zero_threshold: "NaN",
  min: "-Infinity",
  max: "Infinity",
}, "exponential histogram with non-finite summary values");
assertValid(validateMetricPoint, {
  ...metricFixtures[4],
  sum: "Infinity",
  quantile_values: [{ quantile: 0.5, value: "Infinity" }],
}, "summary with non-finite sum and positive-infinite quantile value");
assertValid(validateMetricPoint, { ...metricCommon, type: "gauge", flags: 1 },
  "gauge carrying NO_RECORDED_VALUE");
assertValid(validateMetricPoint, {
  ...metricCommon,
  type: "sum",
  flags: 1,
  aggregation_temporality: 2,
  is_monotonic: true,
}, "sum carrying NO_RECORDED_VALUE");
assertInvalid(validateMetricPoint, {
  ...metricFixtures[0],
  value: { as_int: "1", as_double: 1 },
}, "gauge with an ambiguous numeric value");
assertInvalid(validateMetricPoint, { ...metricFixtures[0], type: "counter" }, "unknown metric type");
assertInvalid(validateMetricPoint, { ...metricFixtures[1], aggregation_temporality: 0 }, "unspecified aggregation temporality");
assertInvalid(validateMetricPoint, { ...metricFixtures[0], time_unix_nano: "0" }, "zero metric timestamp");
assertInvalid(validateMetricPoint, { ...metricFixtures[0], time_unix_nano: 2000 }, "numeric JSON encoding for a metric timestamp");
assertInvalid(validateMetricPoint, {
  ...metricFixtures[4],
  quantile_values: [{ quantile: -0.1, value: 1 }],
}, "summary quantile outside the unit interval");
for (const invalidValue of [-0.1, "NaN", "-Infinity"]) {
  assertInvalid(validateMetricPoint, {
    ...metricFixtures[4],
    quantile_values: [{ quantile: 0.5, value: invalidValue }],
  }, `summary carrying invalid quantile value ${invalidValue}`);
}

const validateWorkspacePreferences = validatorFor("Runner.Mcp.RunnerMcpWorkspacePreferences");
assertValid(
  validateWorkspacePreferences,
  {
    workspaceId: "workspace-001",
    selectedServerId: "server-001",
    selectedToolName: "inspect_trace",
    inputMode: "form",
    activePanel: "execution",
    compactMode: true,
    updatedAt: "2026-07-15T10:00:00Z",
  },
  "workspace-scoped saved UI preferences",
);
const validateWorkspacePreferencesUpdate = validatorFor(
  "Runner.Mcp.RunnerMcpWorkspacePreferencesUpdateRequest",
);
assertValid(
  validateWorkspacePreferencesUpdate,
  { inputMode: "json", compactMode: false },
  "workspace preference update",
);
assertInvalid(
  validateWorkspacePreferencesUpdate,
  { inputMode: "json", authToken: "plaintext" },
  "workspace preference update containing an undeclared credential",
);

const removedMcpDefinitions = [
  "Runner.RunnerMcpServerInfo",
  "Runner.Mcp.RunnerMcpIcon",
  "Runner.Mcp.RunnerMcpToolTaskSupport",
  "Runner.Mcp.RunnerMcpToolExecution",
  "Runner.Mcp.RunnerMcpTool",
  "Runner.Mcp.RunnerMcpToolsResponse",
  "Runner.Mcp.RunnerMcpToolCallRequest",
  "Runner.Mcp.RunnerMcpTaskMetadata",
  "Runner.Mcp.RunnerMcpContentMetadata",
  "Runner.Mcp.RunnerMcpTextContent",
  "Runner.Mcp.RunnerMcpImageContent",
  "Runner.Mcp.RunnerMcpAudioContent",
  "Runner.Mcp.RunnerMcpEmbeddedResourceContent",
  "Runner.Mcp.RunnerMcpResourceLinkContent",
  "Runner.Mcp.RunnerMcpToolUseContent",
  "Runner.Mcp.RunnerMcpToolResultContent",
  "Runner.Mcp.RunnerMcpContent",
  "Runner.Mcp.RunnerMcpTaskStatus",
  "Runner.Mcp.RunnerMcpTask",
  "Runner.Mcp.RunnerMcpToolCallResponse",
  "Runner.Mcp.RunnerMcpResourceReadRequest",
  "Runner.Mcp.RunnerMcpResourceContentMetadata",
  "Runner.Mcp.RunnerMcpTextResourceContent",
  "Runner.Mcp.RunnerMcpBlobResourceContent",
  "Runner.Mcp.RunnerMcpResourceContent",
  "Runner.Mcp.RunnerMcpResourceReadResponse",
];
for (const removedDefinition of removedMcpDefinitions) {
  if (removedDefinition in defs) {
    throw new Error(`${removedDefinition} must not survive the opaque SDK-payload cutover.`);
  }

  const typeName = removedDefinition.split(".").at(-1);
  const declaration = new RegExp(`\\b(?:class|enum|interface|record|struct|type)\\s+${typeName}\\b`, "u");
  if (declaration.test(tsRuntime) || declaration.test(csharpRuntime) || declaration.test(csharpRunnerRuntime)) {
    throw new Error(`${typeName} must not survive in generated TypeScript or C# contracts.`);
  }
}

const serverConfigurationRefs = [
  "RunnerMcpStdioServerConfiguration",
  "RunnerMcpStreamableHttpServerConfiguration",
  "RunnerMcpSseServerConfiguration",
  "RunnerMcpInProcessServerConfiguration",
  "RunnerMcpBuiltinServerConfiguration",
].map((name) => `#/$defs/Runner.Mcp.${name}`);
assertReferences("Runner.Mcp.RunnerMcpServerConfiguration", serverConfigurationRefs);

const validateServerConfiguration = validatorFor("Runner.Mcp.RunnerMcpServerConfiguration");
const serverConfigurationFixtures = [
  {
    transport: "stdio",
    command: "npx",
    arguments: ["-y", "@example/mcp-server"],
    environment: [{
      name: "SERVICE_TOKEN",
      secret: { source: "environment", environmentVariable: "MCP_SERVICE_TOKEN" },
    }],
  },
  {
    transport: "streamable_http",
    endpoint: "https://mcp.example.test/mcp",
    headers: [{
      name: "Authorization",
      secret: { source: "environment", environmentVariable: "REMOTE_MCP_AUTH" },
      scheme: "bearer",
    }],
  },
  { transport: "sse", endpoint: "https://mcp.example.test/sse" },
  { transport: "inproc", implementation: "qyl.observability" },
  { transport: "builtin", name: "qyl" },
];
for (const fixture of serverConfigurationFixtures) {
  assertValid(validateServerConfiguration, fixture, `${fixture.transport} server configuration`);
}
assertInvalid(
  validateServerConfiguration,
  {
    transport: "streamable_http",
    endpoint: "https://mcp.example.test/mcp",
    headers: [{ name: "Authorization", value: "Bearer plaintext" }],
  },
  "server configuration with a plaintext header",
);
assertInvalid(
  validateServerConfiguration,
  {
    transport: "stdio",
    command: "server",
    environment: [{
      name: "TOKEN",
      secret: { source: "keychain", environmentVariable: "TOKEN" },
    }],
  },
  "server configuration with an unimplemented secret store",
);

const secretReference = defs["Runner.Mcp.RunnerMcpSecretReference"];
if (JSON.stringify(secretReference?.properties?.source?.enum) !== JSON.stringify(["environment"]) ||
    !secretReference?.required?.includes("environmentVariable") ||
    ["value", "store", "reference"].some((name) => name in (secretReference?.properties ?? {}))) {
  throw new Error("RunnerMcpSecretReference must expose only an environment variable reference, never a value or speculative store.");
}

const validateExecutionRequest = validatorFor("Runner.Mcp.RunnerMcpExecutionRequest");
const executionRequest = {
  toolName: "inspect_trace",
  arguments: { traceId: "abc", nested: [true, 7] },
  timeoutMs: 30000,
  confirmation: { acknowledged: true, acknowledgement: "This call may mutate external state." },
  idempotencyKey: "execution-001",
};
assertValid(validateExecutionRequest, executionRequest, "asynchronous execution request");
assertInvalid(
  validateExecutionRequest,
  { ...executionRequest, effect: "read_only" },
  "client-controlled execution effect",
);
assertInvalid(
  validateExecutionRequest,
  {
    ...executionRequest,
    confirmation: { ...executionRequest.confirmation, confirmedAt: "2026-07-15T10:00:00Z" },
  },
  "client-controlled confirmation timestamp",
);

const validateExecutionCancel = validatorFor("Runner.Mcp.RunnerMcpExecutionCancelRequest");
assertValid(
  validateExecutionCancel,
  { reason: "No longer needed", idempotencyKey: "cancel-001" },
  "idempotent asynchronous execution cancellation",
);
assertInvalid(validateExecutionCancel, { reason: "No longer needed" }, "cancellation without idempotency key");

const validateExecutionRecord = validatorFor("Runner.Mcp.RunnerMcpExecutionRecord");
const executionRecord = {
  id: "execution-001",
  workspaceId: "workspace-001",
  serverId: "server-001",
  request: executionRequest,
  effect: "consequential",
  confirmation: {
    acknowledged: true,
    acknowledgement: "This call may mutate external state.",
    confirmedAt: "2026-07-15T10:00:00Z",
  },
  status: "succeeded",
  createdAt: "2026-07-15T09:59:59Z",
  startedAt: "2026-07-15T10:00:00Z",
  completedAt: "2026-07-15T10:00:01Z",
  durationMs: 1000,
  attemptCount: 1,
  retryCount: 0,
  result: {
    content: [{ type: "text", text: "opaque SDK result" }],
    structuredContent: { ok: true },
  },
};
assertValid(validateExecutionRecord, executionRecord, "server-derived execution record with opaque SDK result");

const validateDiscovery = validatorFor("Runner.Mcp.RunnerMcpDiscoveryCollection");
assertValid(
  validateDiscovery,
  {
    items: [{ name: "inspect", inputSchema: { type: "object" }, arbitrarySdkField: [1, true] }],
    count: 1,
    complete: true,
    cursor: "page-1",
    nextCursor: "page-2",
    discoveredAt: "2026-07-15T10:00:00Z",
  },
  "opaque SDK discovery collection",
);

const validateProtocolEvent = validatorFor("Runner.Mcp.RunnerMcpProtocolEvent");
const protocolEvent = {
  id: "event-001",
  serverId: "server-001",
  direction: "client_to_server",
  kind: "request",
  method: "tools/call",
  requestId: 7,
  timestamp: "2026-07-15T10:00:00Z",
  payload: { jsonrpc: "2.0", params: { opaque: true } },
  redactionApplied: true,
  executionId: "execution-001",
};
assertValid(validateProtocolEvent, protocolEvent, "redacted opaque protocol event");
assertInvalid(
  validateProtocolEvent,
  { ...protocolEvent, redactionApplied: false },
  "protocol event without completed redaction",
);

const assertionRefs = [
  "RunnerMcpStatusAssertion",
  "RunnerMcpExactAssertion",
  "RunnerMcpPartialAssertion",
  "RunnerMcpSchemaAssertion",
  "RunnerMcpPatternAssertion",
  "RunnerMcpLatencyAssertion",
].map((name) => `#/$defs/Runner.Mcp.${name}`);
assertReferences("Runner.Mcp.RunnerMcpTestAssertion", assertionRefs);
const validateAssertion = validatorFor("Runner.Mcp.RunnerMcpTestAssertion");
const assertionFixtures = [
  { id: "status", kind: "status", expected: ["succeeded"] },
  { id: "exact", kind: "exact", path: "/structuredContent/ok", expected: true },
  { id: "partial", kind: "partial", expected: { structuredContent: { ok: true } } },
  { id: "schema", kind: "schema", schema: { type: "object", required: ["content"] } },
  { id: "pattern", kind: "pattern", path: "/content/0/text", pattern: "^opaque", flags: "i" },
  { id: "latency", kind: "latency", maxDurationMs: 2500 },
];
for (const fixture of assertionFixtures) {
  assertValid(validateAssertion, fixture, `${fixture.kind} test assertion`);
}

const validateExportRequest = validatorFor("Runner.Mcp.RunnerMcpEvaluationExportRequest");
assertValid(
  validateExportRequest,
  { format: "json", includeProtocolEvents: true, includeTelemetry: true, idempotencyKey: "export-001" },
  "idempotent evaluation export request",
);
assertInvalid(validateExportRequest, { format: "report" }, "evaluation export request without idempotency key");

const exportPayloadRefs = [
  "RunnerMcpEvaluationJsonExportPayload",
  "RunnerMcpEvaluationReportExportPayload",
].map((name) => `#/$defs/Runner.Mcp.${name}`);
assertReferences("Runner.Mcp.RunnerMcpEvaluationExportPayload", exportPayloadRefs);
const exportMetadata = defs["Runner.Mcp.RunnerMcpEvaluationExport"];
if ("downloadUrl" in (exportMetadata?.properties ?? {})) {
  throw new Error("Evaluation exports must use the TypeSpec-owned content route, not an orphan downloadUrl.");
}

const discoveryItems = defs["Runner.Mcp.RunnerMcpDiscoveryCollection"]?.properties?.items?.items;
const opaqueProperties = [
  defs["Runner.Mcp.RunnerMcpInitializationSnapshot"]?.properties?.result,
  defs["Runner.Mcp.RunnerMcpExecutionRequest"]?.properties?.arguments,
  defs["Runner.Mcp.RunnerMcpExecutionRecord"]?.properties?.result,
  defs["Runner.Mcp.RunnerMcpProtocolEvent"]?.properties?.payload,
];
if (JSON.stringify(discoveryItems) !== "{}" || opaqueProperties.some((property) =>
  !property || ["type", "$ref", "oneOf", "allOf", "properties"].some((keyword) => keyword in property)
)) {
  throw new Error("SDK MCP entities, messages, and results must remain opaque unknown payloads.");
}

const telemetryResponse = defs["Runner.Mcp.RunnerMcpExecutionTelemetryResponse"];
if (telemetryResponse?.properties?.traces?.items?.$ref !== "#/$defs/OTel.Traces.Trace" ||
    telemetryResponse?.properties?.logs?.items?.$ref !== "#/$defs/OTel.Logs.LogRecord" ||
    telemetryResponse?.properties?.metrics?.items?.$ref !== "#/$defs/OTel.Metrics.MetricPoint" ||
    JSON.stringify(telemetryResponse?.properties?.selfExportSuppressed?.enum) !== JSON.stringify([true]) ||
    telemetryResponse?.properties?.signals?.$ref !== "#/$defs/Runner.Mcp.RunnerMcpTelemetrySignalSummary") {
  throw new Error("Execution telemetry must use Qyl Trace/LogRecord/MetricPoint contracts, expose per-signal availability, and suppress self-export.");
}
const telemetrySignals = defs["Runner.Mcp.RunnerMcpTelemetrySignalSummary"];
for (const signal of ["traces", "logs", "metrics", "exceptions", "toolCallEvents"]) {
  if (telemetrySignals?.properties?.[signal]?.$ref !==
      "#/$defs/Runner.Mcp.RunnerMcpTelemetrySignalAvailability") {
    throw new Error(`Execution telemetry must expose ${signal} availability independently.`);
  }
}

const evaluationRun = defs["Runner.Mcp.RunnerMcpEvaluationRun"];
const evaluationResult = defs["Runner.Mcp.RunnerMcpEvaluationTestResult"];
if (evaluationRun?.properties?.testCases?.items?.$ref !==
      "#/$defs/Runner.Mcp.RunnerMcpEvaluationTestCaseSnapshot" ||
    evaluationResult?.properties?.testCase?.$ref !==
      "#/$defs/Runner.Mcp.RunnerMcpEvaluationTestCaseSnapshot" ||
    "testCaseIds" in (evaluationRun?.properties ?? {})) {
  throw new Error("Evaluation history must retain immutable complete test-case definition snapshots.");
}

const expectedErrorCategories = [
  "authentication",
  "transport",
  "protocol",
  "serialization",
  "schema_validation",
  "tool_error",
  "timeout",
  "cancelled",
  "internal",
];
const actualErrorCategories = defs["Runner.Mcp.RunnerMcpErrorCategory"]?.enum ?? [];
if (JSON.stringify(actualErrorCategories) !== JSON.stringify(expectedErrorCategories)) {
  throw new Error(`RunnerMcpErrorCategory drifted: ${JSON.stringify(actualErrorCategories)}.`);
}

for (const removedDefinition of [
  "Cost.ProviderCostSourceKind",
  "Cost.ProviderCostSourceStatus",
  "Cost.ProviderCostAttribution",
  "Cost.ProviderCostSource",
  "Cost.ModelCatalogSourceKind",
  "Cost.GenAiEtlCalculationStatus",
  // The GenAI cost / model-pricing / ETL-audit contract surface was removed
  // wholesale; the collector no longer serves /api/v1/cost/*. Nothing under the
  // Cost namespace may reappear without an explicit product-boundary change.
  "Cost.GenAiEtlAuditReport",
  "Cost.GenAiEtlAuditSummary",
  "Cost.GenAiEtlAuditCluster",
  "Cost.GenAiEtlAuditEvaluationRequest",
  "Cost.GenAiEtlAuditEvaluationResponse",
  "Cost.GenAiEtlClusterEvaluation",
  "Cost.GenAiEtlCatalogTokenCostEstimate",
  "Cost.GenAiEtlPromotionGate",
  "Cost.ModelCatalogMatchKind",
  "Cost.ModelCatalogSource",
  "Cost.ProviderBillingSource",
]) {
  if (removedDefinition in defs) throw new Error(`${removedDefinition} must not survive the direct cutover.`);
}
