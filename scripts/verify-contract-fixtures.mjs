import { readFile } from "node:fs/promises";
import Ajv2020 from "ajv/dist/2020.js";

const schemaPath = "generated/json-schema/qyl-api-schema.json";
const schema = JSON.parse(await readFile(schemaPath, "utf8"));
const openapi = JSON.parse(await readFile("generated/openapi/qyl.openapi.json", "utf8"));
const tsRuntime = await readFile("generated/ts-runtime/api.d.ts", "utf8");
const csharpRuntime = await readFile(
  "generated/contracts/Qyl/Api/Contracts/Workbench.cs",
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
const csharpWorkflowRuntime = await readFile(
  "generated/contracts/Qyl/Api/Contracts/Workflow.cs",
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

const cursorPageDefinitions = new Map([
  ["Operations.LogsApi_list.Response.200", "#/$defs/OTel.Logs.LogRecord"],
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

if (!/export interface WorkbenchSessionBootstrapResponse extends WorkbenchSession\s*\{\s*\}/u.test(tsRuntime)) {
  throw new Error("TypeScript session bootstrap DTO must have the exact session body shape without a nested session property.");
}
const csharpBootstrap = /public sealed class WorkbenchSessionBootstrapResponse\s*\{(?<body>[\s\S]*?)\n\}/u.exec(csharpRuntime)?.groups?.body;
if (!csharpBootstrap?.includes('[JsonPropertyName("id")]') ||
    csharpBootstrap.includes('[JsonPropertyName("session")]')) {
  throw new Error("C# session bootstrap DTO must have the exact session body shape without a nested Session property.");
}
for (const id of [
  "WorkbenchSessionId",
  "WorkbenchWorkspaceId",
  "WorkbenchServerId",
  "WorkbenchExecutionId",
  "WorkbenchTestCaseId",
  "WorkbenchSuiteId",
  "WorkbenchEvaluationRunId",
  "WorkbenchEvaluationExportId",
]) {
  if (!tsRuntime.includes(`readonly __brand: "${id}"`)) {
    throw new Error(`${id} must remain a branded TypeScript identifier.`);
  }
}
for (const id of ["WorkflowNodeId", "WorkflowEdgeId"]) {
  if (!tsRuntime.includes(`readonly __brand: "${id}"`)) {
    throw new Error(`${id} must remain a branded TypeScript workflow identifier.`);
  }
}
for (const property of [
  '"node_id": WorkflowNodeId;',
  '"edge_id": WorkflowEdgeId;',
  '"source_node_id": WorkflowNodeId;',
  '"target_node_id": WorkflowNodeId;',
  '"next_node_cursor"?: WorkflowNodeId;',
  '"next_edge_cursor"?: WorkflowEdgeId;',
  '"node_cursor"?: WorkflowNodeId;',
  '"edge_cursor"?: WorkflowEdgeId;',
]) {
  if (!tsRuntime.includes(property)) {
    throw new Error(`Generated TypeScript workflow identifier property drifted: ${property}.`);
  }
}
for (const marker of [
  '[JsonPolymorphic(TypeDiscriminatorPropertyName = "format")]',
  '[JsonDerivedType(typeof(WorkbenchEvaluationJsonExportPayload), "json")]',
  '[JsonDerivedType(typeof(WorkbenchEvaluationReportExportPayload), "report")]',
  "public interface WorkbenchEvaluationExportPayload",
  "public required Qyl.Api.Contracts.Workbench.WorkbenchEvaluationExportPayload Payload",
]) {
  if (!csharpRuntime.includes(marker)) {
    throw new Error(`C# evaluation export payload lost generated polymorphism: ${marker}.`);
  }
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
  "service_name": "checkout",
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
  "service_name": "checkout",
  entity_refs: [{ type: "service", id_keys: ["service.instance.id"], description_keys: [] }],
}, "Resource entity reference with no description keys");
assertInvalid(validateOtelResource, {
  "service_name": "checkout",
  entity_refs: [{ type: "", id_keys: ["service.instance.id"] }],
}, "Resource entity reference with an empty type");
assertInvalid(validateOtelResource, {
  "service_name": "checkout",
  entity_refs: [{ type: "service", id_keys: [] }],
}, "Resource entity reference with no identity keys");
assertInvalid(validateOtelResource, {
  "service_name": "checkout",
  entity_refs: [{ type: "service", id_keys: [""] }],
}, "Resource entity reference with an empty identity key");

const validateLogRecord = validatorFor("OTel.Logs.LogRecord");
const eventLogRecord = {
  time_unix_nano: "2",
  observed_time_unix_nano: "3",
  severity_number: 9,
  body: { string_value: "evaluation completed" },
  event_name: "gen_ai.evaluation.result",
  resource: { "service_name": "evaluator" },
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

const validateWorkspacePreferences = validatorFor("Workbench.WorkbenchWorkspacePreferences");
assertValid(
  validateWorkspacePreferences,
  {
    workspace_id: "workspace-001",
    selected_server_id: "server-001",
    selected_tool_name: "inspect_trace",
    input_mode: "form",
    active_panel: "execution",
    compact_mode: true,
    updated_at: "2026-07-15T10:00:00Z",
  },
  "workspace-scoped saved UI preferences",
);
const validateWorkspacePreferencesUpdate = validatorFor(
  "Workbench.WorkbenchWorkspacePreferencesUpdateRequest",
);
assertValid(
  validateWorkspacePreferencesUpdate,
  { input_mode: "json", compact_mode: false },
  "workspace preference update",
);
assertInvalid(
  validateWorkspacePreferencesUpdate,
  { input_mode: "json", auth_token: "plaintext" },
  "workspace preference update containing an undeclared credential",
);

const removedMcpDefinitions = [
  "Workbench.WorkbenchServerInfo",
  "Workbench.WorkbenchIcon",
  "Workbench.WorkbenchToolTaskSupport",
  "Workbench.WorkbenchToolExecution",
  "Workbench.WorkbenchTool",
  "Workbench.WorkbenchToolsResponse",
  "Workbench.WorkbenchToolCallRequest",
  "Workbench.WorkbenchTaskMetadata",
  "Workbench.WorkbenchContentMetadata",
  "Workbench.WorkbenchTextContent",
  "Workbench.WorkbenchImageContent",
  "Workbench.WorkbenchAudioContent",
  "Workbench.WorkbenchEmbeddedResourceContent",
  "Workbench.WorkbenchResourceLinkContent",
  "Workbench.WorkbenchToolUseContent",
  "Workbench.WorkbenchToolResultContent",
  "Workbench.WorkbenchContent",
  "Workbench.WorkbenchTaskStatus",
  "Workbench.WorkbenchTask",
  "Workbench.WorkbenchToolCallResponse",
  "Workbench.WorkbenchResourceReadRequest",
  "Workbench.WorkbenchResourceContentMetadata",
  "Workbench.WorkbenchTextResourceContent",
  "Workbench.WorkbenchBlobResourceContent",
  "Workbench.WorkbenchResourceContent",
  "Workbench.WorkbenchResourceReadResponse",
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
  "WorkbenchStdioServerConfiguration",
  "WorkbenchStreamableHttpServerConfiguration",
  "WorkbenchBuiltinServerConfiguration",
].map((name) => `#/$defs/Workbench.${name}`);
assertReferences("Workbench.WorkbenchServerConfiguration", serverConfigurationRefs);

const validateServerConfiguration = validatorFor("Workbench.WorkbenchServerConfiguration");
const serverConfigurationFixtures = [
  {
    transport: "stdio",
    command: "npx",
    arguments: ["-y", "@example/mcp-server"],
    environment: [{
      name: "SERVICE_TOKEN",
      secret: { source: "environment", environment_variable: "MCP_SERVICE_TOKEN" },
    }],
  },
  {
    transport: "streamable_http",
    endpoint: "https://mcp.example.test/mcp",
    headers: [{
      name: "Authorization",
      secret: { source: "environment", environment_variable: "REMOTE_MCP_AUTH" },
      scheme: "bearer",
    }],
  },
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
      secret: { source: "keychain", environment_variable: "TOKEN" },
    }],
  },
  "server configuration with an unimplemented secret store",
);

const secretReference = defs["Workbench.WorkbenchSecretReference"];
if (JSON.stringify(secretReference?.properties?.source?.enum) !== JSON.stringify(["environment"]) ||
    !secretReference?.required?.includes("environment_variable") ||
    ["value", "store", "reference"].some((name) => name in (secretReference?.properties ?? {}))) {
  throw new Error("WorkbenchSecretReference must expose only an environment variable reference, never a value or speculative store.");
}

const validateExecutionRequest = validatorFor("Workbench.WorkbenchExecutionRequest");
const executionRequest = {
  tool_name: "inspect_trace",
  arguments: { traceId: "abc", nested: [true, 7] },
  timeout_ms: 30000,
  confirmation: { acknowledged: true, acknowledgement: "This call may mutate external state." },
  idempotency_key: "execution-001",
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
    confirmation: { ...executionRequest.confirmation, confirmed_at: "2026-07-15T10:00:00Z" },
  },
  "client-controlled confirmation timestamp",
);

const validateExecutionCancel = validatorFor("Workbench.WorkbenchExecutionCancelRequest");
assertValid(
  validateExecutionCancel,
  { reason: "No longer needed", idempotency_key: "cancel-001" },
  "idempotent asynchronous execution cancellation",
);
assertInvalid(validateExecutionCancel, { reason: "No longer needed" }, "cancellation without idempotency key");

const validateExecutionRecord = validatorFor("Workbench.WorkbenchExecutionRecord");
const executionRecord = {
  id: "execution-001",
  workspace_id: "workspace-001",
  server_id: "server-001",
  request: executionRequest,
  effect: "consequential",
  confirmation: {
    acknowledged: true,
    acknowledgement: "This call may mutate external state.",
    confirmed_at: "2026-07-15T10:00:00Z",
  },
  status: "succeeded",
  created_at: "2026-07-15T09:59:59Z",
  started_at: "2026-07-15T10:00:00Z",
  completed_at: "2026-07-15T10:00:01Z",
  duration_ms: 1000,
  attempt_count: 1,
  retry_count: 0,
  result: {
    content: [{ type: "text", text: "opaque SDK result" }],
    structuredContent: { ok: true },
  },
};
assertValid(validateExecutionRecord, executionRecord, "server-derived execution record with opaque SDK result");

const validateDiscovery = validatorFor("Workbench.WorkbenchDiscoveryCollection");
assertValid(
  validateDiscovery,
  {
    items: [{ name: "inspect", inputSchema: { type: "object" }, arbitrarySdkField: [1, true] }],
    count: 1,
    complete: true,
    cursor: "page-1",
    next_cursor: "page-2",
    discovered_at: "2026-07-15T10:00:00Z",
  },
  "opaque SDK discovery collection",
);

const validateProtocolEvent = validatorFor("Workbench.WorkbenchProtocolEvent");
const protocolEvent = {
  id: "event-001",
  server_id: "server-001",
  direction: "client_to_server",
  kind: "request",
  method: "tools/call",
  request_id: 7,
  timestamp: "2026-07-15T10:00:00Z",
  payload: { jsonrpc: "2.0", params: { opaque: true } },
  redaction_applied: true,
  execution_id: "execution-001",
};
assertValid(validateProtocolEvent, protocolEvent, "redacted opaque protocol event");
assertInvalid(
  validateProtocolEvent,
  { ...protocolEvent, redaction_applied: false },
  "protocol event without completed redaction",
);

const assertionRefs = [
  "WorkbenchStatusAssertion",
  "WorkbenchExactAssertion",
  "WorkbenchPartialAssertion",
  "WorkbenchSchemaAssertion",
  "WorkbenchPatternAssertion",
  "WorkbenchLatencyAssertion",
].map((name) => `#/$defs/Workbench.${name}`);
assertReferences("Workbench.WorkbenchTestAssertion", assertionRefs);
const validateAssertion = validatorFor("Workbench.WorkbenchTestAssertion");
const assertionFixtures = [
  { id: "status", kind: "status", expected: ["succeeded"] },
  { id: "exact", kind: "exact", path: "/structuredContent/ok", expected: true },
  { id: "partial", kind: "partial", expected: { structuredContent: { ok: true } } },
  { id: "schema", kind: "schema", schema: { type: "object", required: ["content"] } },
  { id: "pattern", kind: "pattern", path: "/content/0/text", pattern: "^opaque", flags: "i" },
  { id: "latency", kind: "latency", max_duration_ms: 2500 },
];
for (const fixture of assertionFixtures) {
  assertValid(validateAssertion, fixture, `${fixture.kind} test assertion`);
}

const validateExportRequest = validatorFor("Workbench.WorkbenchEvaluationExportRequest");
assertValid(
  validateExportRequest,
  { format: "json", include_protocol_events: true, include_telemetry: true, idempotency_key: "export-001" },
  "idempotent evaluation export request",
);
assertInvalid(validateExportRequest, { format: "report" }, "evaluation export request without idempotency key");

const exportPayloadRefs = [
  "WorkbenchEvaluationJsonExportPayload",
  "WorkbenchEvaluationReportExportPayload",
].map((name) => `#/$defs/Workbench.${name}`);
assertReferences("Workbench.WorkbenchEvaluationExportPayload", exportPayloadRefs);
const exportMetadata = defs["Workbench.WorkbenchEvaluationExport"];
if ("download_url" in (exportMetadata?.properties ?? {})) {
  throw new Error("Evaluation exports must use the TypeSpec-owned content route, not an orphan downloadUrl.");
}

const discoveryItems = defs["Workbench.WorkbenchDiscoveryCollection"]?.properties?.items?.items;
const opaqueProperties = [
  defs["Workbench.WorkbenchInitializationSnapshot"]?.properties?.result,
  defs["Workbench.WorkbenchExecutionRequest"]?.properties?.arguments,
  defs["Workbench.WorkbenchExecutionRecord"]?.properties?.result,
  defs["Workbench.WorkbenchProtocolEvent"]?.properties?.payload,
];
if (JSON.stringify(discoveryItems) !== "{}" || opaqueProperties.some((property) =>
  !property || ["type", "$ref", "oneOf", "allOf", "properties"].some((keyword) => keyword in property)
)) {
  throw new Error("SDK MCP entities, messages, and results must remain opaque unknown payloads.");
}

const telemetryResponse = defs["Workbench.WorkbenchExecutionTelemetryResponse"];
if (telemetryResponse?.properties?.traces?.items?.$ref !== "#/$defs/OTel.Traces.Trace" ||
    telemetryResponse?.properties?.logs?.items?.$ref !== "#/$defs/OTel.Logs.LogRecord" ||
    "metrics" in (telemetryResponse?.properties ?? {}) ||
    JSON.stringify(telemetryResponse?.properties?.self_export_suppressed?.enum) !== JSON.stringify([true]) ||
    telemetryResponse?.properties?.signals?.$ref !== "#/$defs/Workbench.WorkbenchTelemetrySignalSummary") {
  throw new Error("Execution telemetry must use Qyl Trace/LogRecord contracts, expose per-signal availability, and suppress self-export.");
}
const telemetrySignals = defs["Workbench.WorkbenchTelemetrySignalSummary"];
for (const signal of ["traces", "logs", "exceptions", "tool_call_events"]) {
  if (telemetrySignals?.properties?.[signal]?.$ref !==
      "#/$defs/Workbench.WorkbenchTelemetrySignalAvailability") {
    throw new Error(`Execution telemetry must expose ${signal} availability independently.`);
  }
}
if ("metrics" in (telemetrySignals?.properties ?? {})) {
  throw new Error("Execution telemetry must not expose discarded metrics.");
}

const evaluationRun = defs["Workbench.WorkbenchEvaluationRun"];
const evaluationResult = defs["Workbench.WorkbenchEvaluationTestResult"];
if (evaluationRun?.properties?.test_cases?.items?.$ref !==
      "#/$defs/Workbench.WorkbenchEvaluationTestCaseSnapshot" ||
    evaluationResult?.properties?.test_case?.$ref !==
      "#/$defs/Workbench.WorkbenchEvaluationTestCaseSnapshot" ||
    "test_case_ids" in (evaluationRun?.properties ?? {})) {
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
const actualErrorCategories = defs["Workbench.WorkbenchErrorCategory"]?.enum ?? [];
if (JSON.stringify(actualErrorCategories) !== JSON.stringify(expectedErrorCategories)) {
  throw new Error(`WorkbenchErrorCategory drifted: ${JSON.stringify(actualErrorCategories)}.`);
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

const removedSignalDefinitions = Object.keys(defs).filter((definition) =>
  definition.startsWith("OTel.Metrics.") || definition.startsWith("OTel.Profiles.")
);
for (const definition of [
  "OTel.Enums.MetricType",
  "OTel.Enums.AggregationTemporality",
  "OTel.Enums.DataPointFlags",
  "OTel.Enums.InstrumentKind",
  "OTel.Enums.OriginalPayloadFormat",
  "OTel.Enums.ProfileFrameType",
]) {
  if (definition in defs) removedSignalDefinitions.push(definition);
}
const removedSignalPaths = Object.keys(openapi.paths ?? {}).filter((path) =>
  path === "/api/v1/metrics" || path.startsWith("/api/v1/profiles")
);
if (removedSignalDefinitions.length > 0 || removedSignalPaths.length > 0) {
  throw new Error(
    `Removed signal contract survived. Definitions: ${removedSignalDefinitions.join(", ") || "none"}. ` +
    `Paths: ${removedSignalPaths.join(", ") || "none"}.`,
  );
}

const workflowEventFixture = {
  event_id: "evt-0001",
  source_sequence: "7",
  timestamp: "2026-07-28T12:34:56Z",
  kind: "agent_spawned",
  thread_id: "thr-1",
  attempt_id: "attempt-1",
  agent_id: "agent-child",
  parent_agent_id: "agent-root",
  content_refs: [`sha256:${"a".repeat(64)}`],
  run_id: "run-1",
  client_id: "qyl-codex",
  journal_sequence: "11",
};
const validateWorkflowEvent = validatorFor("Workflow.WorkflowJournalEvent");
assertValid(validateWorkflowEvent, workflowEventFixture, "workflow journal event");
assertInvalid(
  validateWorkflowEvent,
  { ...workflowEventFixture, source_sequence: 7 },
  "workflow journal event with a numeric source sequence",
);
assertInvalid(
  validateWorkflowEvent,
  { ...workflowEventFixture, content_refs: ["sha256:not-a-digest"] },
  "workflow journal event with an invalid content reference",
);
for (const [definition, maximum] of [
  ["Workflow.WorkflowRunId", 128],
  ["Workflow.WorkflowAttemptId", 128],
  ["Workflow.WorkflowAgentId", 128],
  ["Workflow.WorkflowToolCallId", 128],
  ["Workflow.WorkflowEventId", 160],
  ["Workflow.WorkflowNodeId", 192],
  ["Workflow.WorkflowEdgeId", 192],
]) {
  const validateIdentifier = validatorFor(definition);
  assertValid(
    validateIdentifier,
    "😀".repeat(maximum),
    `${definition} with its maximum Unicode-scalar length`,
  );
  assertInvalid(
    validateIdentifier,
    "x".repeat(maximum + 1),
    `${definition} beyond its maximum length`,
  );
}

const validateWorkflowEdge = validatorFor("Workflow.WorkflowGraphEdge");
const edge = {
  edge_id: "parent:agent-root:agent-child",
  source_node_id: "agent:agent-root",
  target_node_id: "agent:agent-child",
  kind: "control",
  provenance: { type: "recorded", event_ids: ["evt-0001"] },
};
assertValid(validateWorkflowEdge, edge, "recorded workflow graph edge");
assertValid(
  validateWorkflowEdge,
  { ...edge, edge_id: "e".repeat(192) },
  "workflow graph edge with a 192-character identifier",
);
assertInvalid(
  validateWorkflowEdge,
  { ...edge, edge_id: "e".repeat(193) },
  "workflow graph edge with a 193-character identifier",
);
assertValid(
  validateWorkflowEdge,
  { ...edge, source_node_id: "n".repeat(192), target_node_id: "t".repeat(192) },
  "workflow graph edge with 192-character node identifiers",
);
assertInvalid(
  validateWorkflowEdge,
  { ...edge, source_node_id: "n".repeat(193) },
  "workflow graph edge with a 193-character source node identifier",
);
assertValid(validateWorkflowEdge, {
  ...edge,
  kind: "conflict",
  provenance: {
    type: "derived",
    event_ids: ["evt-0001"],
    evidence: "Both agents wrote src/index.ts",
    confidence: 1,
  },
}, "derived workflow graph edge");
assertInvalid(validateWorkflowEdge, {
  ...edge,
  provenance: { type: "derived", event_ids: ["evt-0001"], evidence: "overlap" },
}, "derived workflow graph edge without confidence");

const validateGetWorkflowGraphInput = validatorFor("Mcp.Tools.GetWorkflowGraphInput");
assertValid(
  validateGetWorkflowGraphInput,
  { run_id: "run-1", node_cursor: "n".repeat(192), edge_cursor: "e".repeat(192) },
  "workflow graph input with maximum-length cursors",
);
assertInvalid(
  validateGetWorkflowGraphInput,
  { run_id: "run-1", node_cursor: "n".repeat(193) },
  "workflow graph input with an oversized node cursor",
);
assertInvalid(
  validateGetWorkflowGraphInput,
  { run_id: "run-1", edge_cursor: "e".repeat(193) },
  "workflow graph input with an oversized edge cursor",
);

const nodeCursorInputDescription =
  "Opaque node continuation. Reuse it unchanged from the preceding snapshot's next_node_cursor; " +
  "do not parse, construct, or modify it.";
const edgeCursorInputDescription =
  "Opaque edge continuation. Reuse it unchanged from the preceding snapshot's next_edge_cursor; " +
  "do not parse, construct, or modify it.";
const snapshot = defs["Workflow.WorkflowGraphSnapshot"];
if (snapshot?.properties?.next_node_cursor?.description !==
    "Opaque node continuation for the next page. Reuse it unchanged as node_cursor on the next graph request; " +
    "do not parse, construct, or modify it." ||
    snapshot?.properties?.next_edge_cursor?.description !==
    "Opaque edge continuation for the next page. Reuse it unchanged as edge_cursor on the next graph request; " +
    "do not parse, construct, or modify it.") {
  throw new Error("Workflow graph snapshot cursor output pairing or opacity documentation drifted.");
}
for (const definition of [
  "Mcp.Tools.GetWorkflowGraphInput",
  "Mcp.Tools.DisplayWorkflowGraphInput",
  "Mcp.Tools.FetchWorkflowGraphUpdatesInput",
]) {
  if (defs[definition]?.properties?.node_cursor?.description !== nodeCursorInputDescription ||
      defs[definition]?.properties?.edge_cursor?.description !== edgeCursorInputDescription) {
    throw new Error(`${definition} cursor input pairing or opacity documentation drifted.`);
  }
}
const graphParameters = openapi.paths?.["/api/v1/workflow-runs/{run_id}/graph"]?.get?.parameters ?? [];
const graphParameter = (name) => graphParameters.find((parameter) => parameter.name === name);
if (graphParameter("node_cursor")?.description !== nodeCursorInputDescription ||
    graphParameter("edge_cursor")?.description !== edgeCursorInputDescription) {
  throw new Error("HTTP workflow graph cursor input pairing or opacity documentation drifted.");
}

const workflowContractText = JSON.stringify({
  edge: defs["Workflow.WorkflowGraphEdge"],
  edgeId: defs["Workflow.WorkflowEdgeId"],
  nodeId: defs["Workflow.WorkflowNodeId"],
  statistics: defs["Workflow.WorkflowGraphStatistics"],
});
for (const [definition, scopeSemantics] of [
  ["Workflow.WorkflowNodeId", "structurally distinguish run scope from attempt scope"],
  ["Workflow.WorkflowEdgeId", "structural run-versus-attempt scope"],
]) {
  const description = defs[definition]?.description ?? "";
  for (const semantic of [
    scopeSemantics,
    "escape colon as \\c and backslash as \\\\",
    "over 192 Unicode scalar values",
    "full lowercase 64-hex SHA-256",
    "length-prefixed canonical tuple",
  ]) {
    if (!description.includes(semantic)) {
      throw new Error(`${definition} lost required identifier semantics: ${semantic}.`);
    }
  }
}
for (const semantic of [
  "Data, Control, and Gate edges are causal dependencies",
  "Temporal, Resource, and Conflict edges are excluded from critical-path causality",
  "Every ToolCall, Wait, Gate, and duration-bearing Message or Item contributes an independently weighted interval",
  "minus the union of precisely owned child intervals clipped to the Agent interval",
  "Peak concurrency sweeps every positive independently weighted or Agent own-work fragment",
  "condenses each causal strongly connected component",
  "expands selected component members in ordinal node-id order",
]) {
  if (!workflowContractText.includes(semantic)) {
    throw new Error(`Workflow graph contract lost required semantics: ${semantic}.`);
  }
}

for (const toolShape of [
  "ListWorkflowRunsInput",
  "ListWorkflowRunsOutput",
  "GetWorkflowGraphInput",
  "GetWorkflowGraphOutput",
  "DisplayWorkflowGraphInput",
  "DisplayWorkflowGraphOutput",
  "FetchWorkflowGraphUpdatesInput",
  "FetchWorkflowGraphUpdatesOutput",
  "ControlWorkflowRunInput",
  "ControlWorkflowRunOutput",
]) {
  if (!defs[`Mcp.Tools.${toolShape}`]) {
    throw new Error(`Generated MCP workflow tool shape Mcp.Tools.${toolShape} is missing.`);
  }
}

for (const marker of [
  '[JsonPolymorphic(TypeDiscriminatorPropertyName = "type")]',
  '[JsonDerivedType(typeof(RecordedWorkflowEdgeProvenance), "recorded")]',
  '[JsonDerivedType(typeof(DerivedWorkflowEdgeProvenance), "derived")]',
]) {
  if (!csharpWorkflowRuntime.includes(marker)) {
    throw new Error(`C# workflow edge provenance lost generated polymorphism: ${marker}.`);
  }
}
