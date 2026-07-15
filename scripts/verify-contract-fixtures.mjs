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

const auditRequestDefinition = defs["Operations.GenAiEtlAuditApi_evaluate.Request"];
const auditResponseDefinition = defs["Operations.GenAiEtlAuditApi_evaluate.Response.200"];
if (auditRequestDefinition?.$ref !== "#/$defs/Cost.GenAiEtlAuditEvaluationRequest" ||
    auditResponseDefinition?.$ref !== "#/$defs/Cost.GenAiEtlAuditEvaluationResponse") {
  throw new Error("GenAiEtlAuditApi_evaluate operation request/response definitions drifted.");
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

const auditCluster = defs["Cost.GenAiEtlAuditCluster"];
if (!auditCluster?.required?.includes("validation_metrics") ||
    auditCluster.required.includes("validation_metric") ||
    auditCluster.properties?.validation_metrics?.type !== "array" ||
    auditCluster.properties.validation_metrics.minItems !== 1 ||
    auditCluster.properties.validation_metrics.items?.$ref !==
      "#/$defs/Cost.GenAiEtlValidationMetric" ||
    "validation_metric" in (auditCluster.properties ?? {})) {
  throw new Error(
    "Cost.GenAiEtlAuditCluster must require a non-empty validation_metrics array and expose no scalar validation_metric.",
  );
}
const validationMetrics = defs["Cost.GenAiEtlValidationMetric"]?.enum ?? [];
for (const metric of ["calibration_error", "span_precision", "span_recall"]) {
  if (!validationMetrics.includes(metric)) {
    throw new Error(`Cost.GenAiEtlValidationMetric must include ${metric}.`);
  }
}

for (const removedDefinition of [
  "Cost.ProviderCostSourceKind",
  "Cost.ProviderCostSourceStatus",
  "Cost.ProviderCostAttribution",
  "Cost.ProviderCostSource",
  "Cost.ModelCatalogSourceKind",
  "Cost.GenAiEtlCalculationStatus",
]) {
  if (removedDefinition in defs) throw new Error(`${removedDefinition} must not survive the direct cutover.`);
}

const expectedBillingStatuses = ["unconfigured", "pending", "current", "stale", "sync_failed"];
const billingStatuses = defs["Cost.ProviderBillingSourceStatus"]?.enum ?? [];
if (JSON.stringify(billingStatuses) !== JSON.stringify(expectedBillingStatuses)) {
  throw new Error(`Cost.ProviderBillingSourceStatus drifted: ${JSON.stringify(billingStatuses)}.`);
}
const expectedBillingAttributions = ["provider_model_period", "provider_period", "unavailable"];
const billingAttributions = defs["Cost.ProviderBillingAttribution"]?.enum ?? [];
if (JSON.stringify(billingAttributions) !== JSON.stringify(expectedBillingAttributions)) {
  throw new Error(`Cost.ProviderBillingAttribution drifted: ${JSON.stringify(billingAttributions)}.`);
}
const billingSource = defs["Cost.ProviderBillingSource"];
if (!billingSource || "kind" in billingSource.properties) {
  throw new Error("Cost.ProviderBillingSource must expose aggregate billing without a provisional kind.");
}

const expectedMatchKinds = [
  "exact_model_id",
  "exact_canonical_slug",
];
const matchKinds = defs["Cost.ModelCatalogMatchKind"]?.enum ?? [];
if (JSON.stringify(matchKinds) !== JSON.stringify(expectedMatchKinds)) {
  throw new Error(`Cost.ModelCatalogMatchKind drifted: ${JSON.stringify(matchKinds)}.`);
}
const catalogProvenance = {
  source_id: "provider-model-catalog",
  source_endpoint: "https://provider.example/api/models",
  snapshot_id: "sha256:catalog-snapshot",
  price_model_id: "provider/model-version",
  observed_model_id: "provider/model-version",
  observed_model_identity_basis: "response_model",
  model_match_kind: "exact_model_id",
  retrieved_at: "2026-07-14T11:55:00Z",
  price_semantics: "minimum_available_rate",
};
const replacementEvidence = {
  source_order: 2,
  condition_usage_dimension: "input_tokens",
  exclusive_minimum_quantity: 1000,
  observed_per_call_quantity: 1500,
};
const catalogEstimate = {
  status: "calculated",
  estimated_catalog_token_cost_usd: 0.0047,
  estimated_catalog_token_cost_per_call_usd: 0.00235,
  provenance: catalogProvenance,
  components: [
    {
      component: "cache_read",
      usage_dimension: "cache_read_input_tokens",
      unit: "token",
      source_billing_mode: "per_token",
      billing_mode: "per_unit",
      rate_relation: "replaces_inclusive_base_rate",
      replaces_usage_dimension: "input_tokens",
      quantity: 1500,
      unit_price_usd: 0.000001,
      estimated_cost_usd: 0.0015,
    },
    {
      component: "cache_write_override",
      usage_dimension: "cache_write_input_tokens",
      unit: "token",
      source_billing_mode: "per_token",
      billing_mode: "per_unit",
      rate_relation: "replaces_published_rate",
      replaces_usage_dimension: "cache_write_input_tokens",
      conditional_evidence: replacementEvidence,
      quantity: 500,
      unit_price_usd: 0.000001,
      estimated_cost_usd: 0.0005,
    },
    {
      component: "completion",
      usage_dimension: "output_tokens",
      unit: "token",
      source_billing_mode: "per_token",
      billing_mode: "per_unit",
      rate_relation: "base_rate",
      quantity: 500,
      unit_price_usd: 0.000002,
      estimated_cost_usd: 0.001,
    },
    {
      component: "request",
      usage_dimension: "call_count",
      unit: "request",
      source_billing_mode: "per_request",
      billing_mode: "per_request",
      rate_relation: "base_rate",
      quantity: 2,
      unit_price_usd: 0.00085,
      estimated_cost_usd: 0.0017,
    },
  ],
  exclusions: [
    {
      component: "cache_read",
      usage_dimension: "cache_read_input_tokens",
      unit: "token",
      source_billing_mode: "per_token",
      billing_mode: "per_unit",
      rate_evidence: { rate_relation: "base_rate" },
      reason: "usage_not_observed",
      unit_price_usd: 0.0000001,
    },
    {
      component: "prompt_override",
      usage_dimension: "input_tokens",
      unit: "token",
      source_billing_mode: "per_token",
      billing_mode: "per_unit",
      rate_evidence: {
        rate_relation: "replaces_published_rate",
        replaces_usage_dimension: "input_tokens",
        conditional_evidence: { ...replacementEvidence, source_order: 1 },
      },
      reason: "superseded_by_later_override",
      unit_price_usd: 0.00000075,
    },
    {
      component: "audio",
      usage_dimension: "audio_duration",
      unit: "second",
      source_billing_mode: "per_audio_second",
      rate_evidence: { rate_relation: "base_rate" },
      reason: "outside_token_estimate_scope",
      unit_price_usd: 0.001,
    },
    {
      component: "input_audio_cache",
      usage_dimension: "input_audio_cache",
      unit: "audio",
      source_billing_mode: "per_audio_unit",
      rate_evidence: {
        rate_relation: "replaces_published_rate",
        replaces_usage_dimension: "input_audio_cache",
        conditional_evidence: {
          ...replacementEvidence,
          source_order: 3,
          condition_usage_dimension: "input_audio_cache",
        },
      },
      reason: "conditional_adjustment_not_applied",
      unit_price_usd: 0.002,
    },
    {
      component: "audio",
      usage_dimension: "audio_duration",
      unit: "second",
      source_billing_mode: "per_audio_second",
      rate_evidence: { rate_relation: "base_rate" },
      reason: "unsupported_usage_dimension",
      unit_price_usd: 0.0001,
    },
  ],
};
const validateCatalogEstimate = validatorFor("Cost.GenAiEtlCatalogTokenCostEstimate");
const unavailableCatalogEstimate = { status: "model_not_found" };
const unsupportedBillingEstimate = {
  status: "unsupported_pricing",
  exclusions: [{
    component: "audio",
    usage_dimension: "audio_duration",
    unit: "second",
    source_billing_mode: "per_audio_second",
    rate_evidence: { rate_relation: "base_rate" },
    reason: "unsupported_billing_mode",
    unit_price_usd: 0.0001,
  }],
};
assertValid(validateCatalogEstimate, catalogEstimate, "calculated catalog estimate with exact provenance");
assertValid(validateCatalogEstimate, unavailableCatalogEstimate, "catalog estimate failure status");
assertValid(validateCatalogEstimate, unsupportedBillingEstimate, "unsupported source billing-mode evidence");
assertInvalid(validateCatalogEstimate, {}, "catalog estimate without status");
assertInvalid(
  validateCatalogEstimate,
  { status: "calculated" },
  "calculated estimate without required costs, provenance, and components",
);
assertInvalid(
  validateCatalogEstimate,
  { ...unavailableCatalogEstimate, estimated_catalog_token_cost_usd: 1 },
  "failure estimate carrying a calculated cost",
);
assertInvalid(
  validateCatalogEstimate,
  { ...catalogEstimate, components: [] },
  "catalog estimate with an empty components array",
);
assertInvalid(
  validateCatalogEstimate,
  { ...catalogEstimate, components: [{ ...catalogEstimate.components[0], quantity: -1 }] },
  "catalog estimate with a negative component quantity",
);
assertValid(
  validateCatalogEstimate,
  catalogEstimate,
  "ordered conditional override with target and evidence",
);
const replacementWithoutEvidence = structuredClone(catalogEstimate);
delete replacementWithoutEvidence.components[1].conditional_evidence;
assertInvalid(
  validateCatalogEstimate,
  replacementWithoutEvidence,
  "ordered conditional override without evidence",
);
const supersededWithoutEvidence = structuredClone(catalogEstimate);
delete supersededWithoutEvidence.exclusions[1].rate_evidence.conditional_evidence;
assertInvalid(
  validateCatalogEstimate,
  supersededWithoutEvidence,
  "superseded override without ordered conditional evidence",
);
const nonConditionalOverride = structuredClone(catalogEstimate.exclusions[2]);
nonConditionalOverride.rate_evidence = {
  rate_relation: "replaces_published_rate",
  replaces_usage_dimension: "audio_duration",
  conditional_evidence: {
    ...replacementEvidence,
    condition_usage_dimension: "audio_duration",
  },
};
assertValid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [nonConditionalOverride] },
  "nonconditional unknown meter with complete source-override evidence",
);
const nonConditionalOverrideWithoutEvidence = structuredClone(nonConditionalOverride);
delete nonConditionalOverrideWithoutEvidence.rate_evidence.conditional_evidence;
assertInvalid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [nonConditionalOverrideWithoutEvidence] },
  "nonconditional source override without paired evidence",
);
const nonConditionalOverrideWithoutTarget = structuredClone(nonConditionalOverride);
delete nonConditionalOverrideWithoutTarget.rate_evidence.replaces_usage_dimension;
assertInvalid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [nonConditionalOverrideWithoutTarget] },
  "nonconditional source override without paired target",
);
const baseRateWithOverrideEvidence = structuredClone(catalogEstimate.exclusions[0]);
baseRateWithOverrideEvidence.rate_evidence = {
  rate_relation: "base_rate",
  replaces_usage_dimension: "input_tokens",
  conditional_evidence: replacementEvidence,
};
assertInvalid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [baseRateWithOverrideEvidence] },
  "base-rate exclusion carrying source-override evidence",
);
const inclusiveReplacementExclusion = structuredClone(catalogEstimate.exclusions[0]);
inclusiveReplacementExclusion.rate_evidence = {
  rate_relation: "replaces_inclusive_base_rate",
  replaces_usage_dimension: "input_tokens",
};
assertValid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [inclusiveReplacementExclusion] },
  "ordinary inclusive replacement exclusion without conditional evidence",
);
const inclusiveReplacementWithoutTarget = structuredClone(inclusiveReplacementExclusion);
delete inclusiveReplacementWithoutTarget.rate_evidence.replaces_usage_dimension;
assertInvalid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [inclusiveReplacementWithoutTarget] },
  "inclusive replacement exclusion without its target",
);
const conditionalReasonWithBaseRate = structuredClone(catalogEstimate.exclusions[1]);
conditionalReasonWithBaseRate.rate_evidence = { rate_relation: "base_rate" };
assertInvalid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [conditionalReasonWithBaseRate] },
  "conditional exclusion reason without a published override",
);
const zeroSourceOrder = structuredClone(catalogEstimate);
zeroSourceOrder.components[1].conditional_evidence.source_order = 0;
assertInvalid(validateCatalogEstimate, zeroSourceOrder, "source override with reserved source order zero");
const supportedExclusionWithoutBillingMode = structuredClone(catalogEstimate.exclusions[0]);
delete supportedExclusionWithoutBillingMode.billing_mode;
assertInvalid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [supportedExclusionWithoutBillingMode] },
  "supported exclusion without normalized billing mode",
);
assertValid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [catalogEstimate.exclusions[2]] },
  "outside-scope source meter without a supported billing-mode normalization",
);
assertValid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [catalogEstimate.exclusions[3]] },
  "conditional unknown source meter without a supported billing-mode normalization",
);
assertValid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [catalogEstimate.exclusions[4]] },
  "unsupported usage dimension without a supported billing-mode normalization",
);
assertInvalid(
  validateCatalogEstimate,
  { ...catalogEstimate, exclusions: [] },
  "catalog estimate with an empty exclusions array",
);

const catalogEstimateSchema = defs["Cost.GenAiEtlCatalogTokenCostEstimate"];
const expectedEstimateRefs = [
  "GenAiEtlCatalogTokenCalculatedEstimate",
  "GenAiEtlCatalogTokenSourceUnavailableEstimate",
  "GenAiEtlCatalogTokenStaleSourceEstimate",
  "GenAiEtlCatalogTokenMissingModelIdentityEstimate",
  "GenAiEtlCatalogTokenModelNotFoundEstimate",
  "GenAiEtlCatalogTokenAmbiguousModelEstimate",
  "GenAiEtlCatalogTokenIncompleteUsageEstimate",
  "GenAiEtlCatalogTokenConditionalPricingUnresolvableEstimate",
  "GenAiEtlCatalogTokenUnsupportedPricingEstimate",
].map((name) => `#/$defs/Cost.${name}`);
const actualEstimateRefs = (catalogEstimateSchema?.oneOf ?? []).map((variant) => variant.$ref);
const calculatedEstimateSchema = defs["Cost.GenAiEtlCatalogTokenCalculatedEstimate"];
const sourceOrderSchema = defs["Cost.ModelCatalogSourceOrder"];
const rateEvidenceSchema = defs["Cost.ModelCatalogExclusionRateEvidence"];
const expectedRateEvidenceRefs = [
  "ModelCatalogBaseRateEvidence",
  "ModelCatalogAdditiveSurchargeEvidence",
  "ModelCatalogInclusiveReplacementEvidence",
  "ModelCatalogPublishedReplacementEvidence",
].map((name) => `#/$defs/Cost.${name}`);
const actualRateEvidenceRefs = (rateEvidenceSchema?.oneOf ?? []).map((variant) => variant.$ref);
const inclusiveEvidenceSchema = defs["Cost.ModelCatalogInclusiveReplacementEvidence"];
const publishedEvidenceSchema = defs["Cost.ModelCatalogPublishedReplacementEvidence"];
const supportedExclusionSchema = defs["Cost.ModelCatalogSupportedBillingExclusionBase"];
const optionalBillingExclusionSchema = defs["Cost.ModelCatalogOptionallyNormalizedBillingExclusionBase"];
const conditionalExclusionSchema = defs["Cost.ModelCatalogConditionalExclusionBase"];
const unsupportedBillingSchema = defs["Cost.ModelCatalogUnsupportedBillingExclusion"];
const failureVariantNames = expectedEstimateRefs.slice(1).map((reference) => reference.split("Cost.")[1]);
const calculatedRequired = [
  "status",
  "estimated_catalog_token_cost_usd",
  "estimated_catalog_token_cost_per_call_usd",
  "provenance",
  "components",
];
if (JSON.stringify(actualEstimateRefs) !== JSON.stringify(expectedEstimateRefs) ||
    calculatedRequired.some((property) => !calculatedEstimateSchema?.required?.includes(property)) ||
    calculatedEstimateSchema.properties?.components?.minItems !== 1 ||
    calculatedEstimateSchema.properties?.exclusions?.minItems !== 1 ||
    JSON.stringify(actualRateEvidenceRefs) !== JSON.stringify(expectedRateEvidenceRefs) ||
    !inclusiveEvidenceSchema?.required?.includes("replaces_usage_dimension") ||
    inclusiveEvidenceSchema.required.includes("conditional_evidence") ||
    !publishedEvidenceSchema?.required?.includes("replaces_usage_dimension") ||
    !publishedEvidenceSchema.required.includes("conditional_evidence") ||
    sourceOrderSchema?.minimum !== 1 ||
    !supportedExclusionSchema?.required?.includes("billing_mode") ||
    optionalBillingExclusionSchema?.required?.includes("billing_mode") ||
    conditionalExclusionSchema?.required?.includes("billing_mode") ||
    unsupportedBillingSchema?.required?.includes("billing_mode") ||
    failureVariantNames.some((name) => !("unevaluatedProperties" in (defs[`Cost.${name}`] ?? {})))) {
  throw new Error("Catalog estimate must be a complete calculated variant or a fail-closed status variant.");
}
for (const field of [
  "estimated_catalog_token_cost_usd",
  "estimated_catalog_token_cost_per_call_usd",
  "provenance",
  "components",
]) {
  if (field in unavailableCatalogEstimate) {
    throw new Error(`Non-calculated catalog estimate fixture must omit ${field}.`);
  }
}

const clusterFixture = {
  cluster_id: "cluster-1",
  workflow_key: "workflow-1",
  service_name: "orders",
  provider: "provider",
  model: "model-version",
  output_contract: "record",
  task_family: "structured_extraction",
  call_count: 2,
  input_tokens: 3000,
  output_tokens: 500,
  cache_read_input_tokens: 1500,
  cache_creation_input_tokens: 500,
  reasoning_output_tokens: 0,
  error_count: 0,
  error_rate: 0,
  average_latency_ms: 25,
  p95_latency_ms: 40,
  catalog_token_estimate: catalogEstimate,
  candidate_status: "hypothesis_only",
  candidate_path: "smaller_generative_model",
  validation_metrics: ["field_exact_match", "schema_validity"],
  residual_path: "frontier_model",
  evidence_signals: ["provider_model", "token_usage", "catalog_token_estimate"],
  missing_evidence: [],
  promotion_gates: [],
};
const evidenceSignals = defs["Cost.GenAiEtlEvidenceSignal"]?.enum ?? [];
if (!evidenceSignals.includes("catalog_token_estimate") || evidenceSignals.includes("provider_cost")) {
  throw new Error("Cluster evidence must name the current-catalog estimate and never aggregate provider billing.");
}
const validateAuditCluster = validatorFor("Cost.GenAiEtlAuditCluster");
assertValid(validateAuditCluster, clusterFixture, "ETL audit cluster with required catalog estimate");
const clusterWithoutCandidateStatus = structuredClone(clusterFixture);
delete clusterWithoutCandidateStatus.candidate_status;
assertInvalid(validateAuditCluster, clusterWithoutCandidateStatus, "ETL audit cluster without candidate evidence status");
const clusterWithoutCatalogEstimate = structuredClone(clusterFixture);
delete clusterWithoutCatalogEstimate.catalog_token_estimate;
assertInvalid(validateAuditCluster, clusterWithoutCatalogEstimate, "ETL audit cluster without catalog estimate");
const removedClusterProperties = [
  "observed_cost_usd",
  "cost_per_call_usd",
  "cost_attribution",
  "spend_share",
];
if (!auditCluster.required.includes("catalog_token_estimate") ||
    auditCluster.properties?.catalog_token_estimate?.allOf?.[0]?.$ref !==
      "#/$defs/Cost.GenAiEtlCatalogTokenCostEstimate" ||
    removedClusterProperties.some((property) => property in auditCluster.properties)) {
  throw new Error("ETL audit clusters must expose required catalog status and no request-attributed billing.");
}

const auditSummary = defs["Cost.GenAiEtlAuditSummary"];
const catalogSummaryProperties = [
  "estimated_catalog_token_cost_usd",
  "catalog_token_priced_call_coverage",
  "estimated_token_economic_concentration",
  "candidate_etl_estimated_token_spend_share",
];
const removedSummaryProperties = [
  "attributed_cost_usd",
  "priced_call_coverage",
  "economic_concentration",
  "candidate_etl_spend_share",
];
if (!auditSummary?.required?.includes("catalog_token_priced_call_coverage") ||
    catalogSummaryProperties.some((property) => !(property in (auditSummary.properties ?? {}))) ||
    removedSummaryProperties.some((property) => property in (auditSummary.properties ?? {}))) {
  throw new Error("ETL audit summary must expose only executable catalog economics.");
}
const summaryFixture = {
  total_calls: 2,
  total_input_tokens: 3000,
  total_output_tokens: 500,
  estimated_catalog_token_cost_usd: 0.0047,
  catalog_token_priced_call_coverage: 1,
  estimated_token_economic_concentration: 0.8,
  candidate_etl_estimated_token_spend_share: 0.6,
};
const validateAuditSummary = validatorFor("Cost.GenAiEtlAuditSummary");
assertValid(validateAuditSummary, summaryFixture, "audit summary with live catalog economics");
const summaryWithoutCatalogCoverage = structuredClone(summaryFixture);
delete summaryWithoutCatalogCoverage.catalog_token_priced_call_coverage;
assertInvalid(validateAuditSummary, summaryWithoutCatalogCoverage, "audit summary without catalog coverage");

const auditReport = defs["Cost.GenAiEtlAuditReport"];
if (!auditReport?.required?.includes("billing_sources") ||
    !auditReport.required.includes("catalog_sources") ||
    "cost_sources" in auditReport.properties ||
    auditReport.properties?.billing_sources?.items?.$ref !== "#/$defs/Cost.ProviderBillingSource" ||
    auditReport.properties?.catalog_sources?.items?.$ref !== "#/$defs/Cost.ModelCatalogSource") {
  throw new Error("ETL audit report must separate aggregate billing_sources from live catalog_sources.");
}
const reportFixture = {
  generated_at: "2026-07-14T12:00:00Z",
  period_start: "2026-06-01T00:00:00Z",
  period_end: "2026-07-01T00:00:00Z",
  summary: summaryFixture,
  billing_sources: [{
    provider: "provider",
    status: "current",
    source_endpoint: "https://provider.example/api/billing",
    attribution: "provider_period",
    reported_cost_usd: 1.25,
  }],
  catalog_sources: [{
    source_id: "provider-model-catalog",
    priority: 0,
    status: "current",
    price_semantics: "minimum_available_rate",
    source_endpoint: "https://provider.example/api/models",
    last_verified_at: "2026-07-14T11:59:00Z",
    retrieved_at: "2026-07-14T11:55:00Z",
    active_snapshot_id: "sha256:catalog-snapshot",
    model_count: 42,
  }],
  clusters: [clusterFixture],
};
const validateAuditReport = validatorFor("Cost.GenAiEtlAuditReport");
assertValid(validateAuditReport, reportFixture, "ETL audit report with billing and catalog sources");
for (const requiredSourceProperty of ["billing_sources", "catalog_sources"]) {
  const incompleteReport = structuredClone(reportFixture);
  delete incompleteReport[requiredSourceProperty];
  assertInvalid(validateAuditReport, incompleteReport, `ETL audit report without ${requiredSourceProperty}`);
}
const catalogSource = defs["Cost.ModelCatalogSource"];
if ("kind" in catalogSource.properties ||
    !("source_id" in catalogSource.properties) ||
    !catalogSource.required.includes("priority") ||
    !("price_semantics" in catalogSource.properties) ||
    !("last_verified_at" in catalogSource.properties) ||
    !("active_snapshot_id" in catalogSource.properties) ||
    !("model_count" in catalogSource.properties)) {
  throw new Error("Catalog sources must expose the active snapshot without a provisional kind.");
}

const expectedFrontierCostBases = ["scenario", "catalog_token_estimate", "unavailable"];
const frontierCostBases = defs["Cost.GenAiEtlFrontierCostBasis"]?.enum ?? [];
const evaluation = defs["Cost.GenAiEtlClusterEvaluation"];
const expectedEvaluationRefs = [
  "GenAiEtlScenarioClusterEvaluation",
  "GenAiEtlCatalogTokenClusterEvaluation",
  "GenAiEtlUnavailableClusterEvaluation",
].map((name) => `#/$defs/Cost.${name}`);
const actualEvaluationRefs = (evaluation?.oneOf ?? []).map((variant) => variant.$ref);
const catalogEvaluationSchema = defs["Cost.GenAiEtlCatalogTokenClusterEvaluation"];
const calculatedEvaluationSchema = defs["Cost.GenAiEtlCalculatedClusterEvaluationBase"];
if (JSON.stringify(frontierCostBases) !== JSON.stringify(expectedFrontierCostBases) ||
    JSON.stringify(actualEvaluationRefs) !== JSON.stringify(expectedEvaluationRefs) ||
    !catalogEvaluationSchema?.required?.includes("catalog_provenance") ||
    !["frontier_cost_per_call_usd", "current_period_cost_usd", "gross_replaceable_value_usd", "net_replaceable_value_usd"]
      .every((property) => calculatedEvaluationSchema?.required?.includes(property))) {
  throw new Error(`Cost.GenAiEtlFrontierCostBasis drifted: ${JSON.stringify(frontierCostBases)}.`);
}
const validateFrontierCostBasis = validatorFor("Cost.GenAiEtlFrontierCostBasis");
for (const basis of expectedFrontierCostBases) {
  assertValid(validateFrontierCostBasis, basis, `frontier cost basis ${basis}`);
}
for (const forbiddenBasis of ["provider_attributed_actual", "provider_model_period", "live_catalog_estimate"]) {
  assertInvalid(validateFrontierCostBasis, forbiddenBasis, `non-executable frontier basis ${forbiddenBasis}`);
}
const scenarioEvaluation = {
  cluster_id: "cluster-1",
  status: "calculated",
  call_count: 2,
  coverage: 1,
  served_call_count: 2,
  residual_call_count: 0,
  frontier_cost_basis: "scenario",
  frontier_cost_per_call_usd: 0.003,
  alternative_cost_per_call_usd: 0.001,
  current_period_cost_usd: 0.006,
  gross_replaceable_value_usd: 0.004,
  period_maintenance_cost_usd: 0,
  period_error_cost_usd: 0,
  net_replaceable_value_usd: 0.004,
};
const catalogEvaluation = {
  ...scenarioEvaluation,
  frontier_cost_basis: "catalog_token_estimate",
  frontier_cost_per_call_usd: catalogEstimate.estimated_catalog_token_cost_per_call_usd,
  current_period_cost_usd: catalogEstimate.estimated_catalog_token_cost_usd,
  gross_replaceable_value_usd: 0.0027,
  net_replaceable_value_usd: 0.0027,
  catalog_provenance: catalogProvenance,
};
const unavailableEvaluation = {
  cluster_id: "cluster-1",
  status: "missing_frontier_cost",
  call_count: 2,
  coverage: 1,
  served_call_count: 2,
  residual_call_count: 0,
  frontier_cost_basis: "unavailable",
  alternative_cost_per_call_usd: 0.001,
  period_maintenance_cost_usd: 0,
  period_error_cost_usd: 0,
};
const validateEvaluation = validatorFor("Cost.GenAiEtlClusterEvaluation");
assertValid(validateEvaluation, scenarioEvaluation, "scenario-based calculated evaluation");
assertValid(validateEvaluation, catalogEvaluation, "catalog-based calculated evaluation with provenance");
assertValid(validateEvaluation, unavailableEvaluation, "fail-closed unavailable evaluation");
const incompleteCalculatedEvaluation = structuredClone(scenarioEvaluation);
delete incompleteCalculatedEvaluation.net_replaceable_value_usd;
assertInvalid(validateEvaluation, incompleteCalculatedEvaluation, "calculated evaluation without net value");
assertInvalid(
  validateEvaluation,
  { ...scenarioEvaluation, catalog_provenance: catalogProvenance },
  "scenario evaluation carrying catalog provenance",
);
const catalogEvaluationWithoutProvenance = structuredClone(catalogEvaluation);
delete catalogEvaluationWithoutProvenance.catalog_provenance;
assertInvalid(validateEvaluation, catalogEvaluationWithoutProvenance, "catalog evaluation without provenance");
assertInvalid(
  validateEvaluation,
  { ...unavailableEvaluation, frontier_cost_per_call_usd: 0.003 },
  "unavailable evaluation carrying calculated economics",
);

console.log(
  `Verified ${attributeFixtures.length} lossless recursive AttributeValue fixtures, ` +
  "Resource EntityRef constraints, OTLP metric special/no-recorded values, non-negative summary quantiles, " +
  `${expectedOperationDefinitions.size} operation body definitions, ` +
  `${cursorPageDefinitions.size} exact CursorPage responses, ` +
  `${serverConfigurationFixtures.length} sanitized MCP transport configurations, ` +
  `${assertionFixtures.length} evaluation assertion variants, opaque SDK payload ownership, ` +
  "compound ETL validation metrics, and the aggregate-billing/live-catalog cutover.",
);
