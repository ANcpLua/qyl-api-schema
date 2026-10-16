import { readFile } from "node:fs/promises";
import {
  assertInvalid,
  assertValid,
  contractSchema as schema,
  validatorFor,
} from "./lib/contract-fixtures.mjs";
import { httpMethods, readOpenApi } from "./lib/openapi.mjs";

const openapi = await readOpenApi();
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
const defs = schema.$defs ?? {};

const validateRunnerState = validatorFor("Runner.RunnerResourceState");
const runnerState = {
  name: "worker", lifecycle: "ready", timestamp: "2026-10-16T12:00:00Z",
  allocated_port: 4318, endpoint: "http://127.0.0.1:4318", last_error: "Process exited (code 1)",
};
for (const kind of ["collector", "project", "command"]) {
  assertValid(validateRunnerState, { ...runnerState, kind }, `runner process kind ${kind}`);
}
for (const kind of ["stdio", "http", "inproc"]) {
  assertInvalid(validateRunnerState, { ...runnerState, kind }, `runner rejects MCP transport ${kind}`);
}
for (const field of ["server_identity", "tool_count", "restarts"]) {
  assertInvalid(validateRunnerState, { ...runnerState, [field]: 0 }, `runner rejects unsupported field ${field}`);
}
for (const allocated_port of [0, 65536, 1.5]) {
  assertInvalid(validateRunnerState, { ...runnerState, allocated_port }, `runner rejects port ${allocated_port}`);
}

assertValid(validatorFor("Workbench.WorkbenchInitializationSnapshot"), {
  initialized_at: "2026-10-16T12:00:00Z", protocol_version: "2026-07-28",
  server_identity: { name: "fixture-server", version: "1.0.0" },
  capabilities: { tools: {} },
  result: {
    protocolVersion: "2026-07-28", serverInfo: { name: "fixture-server", version: "1.0.0" },
    capabilities: { tools: {} },
  },
}, "Workbench retains MCP initialization evidence");

const validateGetTrace = validatorFor("Mcp.Tools.GetTraceInput");
const traceInput = { trace_id: "0123456789abcdef0123456789abcdef" };
assertValid(validateGetTrace, traceInput, "get_trace existing input without projection options");
for (const max_spans of [1, 1000]) {
  assertValid(validateGetTrace, {
    ...traceInput, errors_only: true, max_spans, include_attributes: false,
  }, `get_trace bounded projection at ${max_spans} spans`);
}
for (const max_spans of [0, -1, 1001, 1.5, "10"]) {
  assertInvalid(validateGetTrace, { ...traceInput, max_spans }, `get_trace invalid max_spans ${max_spans}`);
}
for (const option of ["errors_only", "include_attributes"]) {
  assertValid(validateGetTrace, { ...traceInput, [option]: false }, `get_trace ${option} false`);
  assertValid(validateGetTrace, { ...traceInput, [option]: true }, `get_trace ${option} true`);
  assertInvalid(validateGetTrace, { ...traceInput, [option]: "false" }, `get_trace non-boolean ${option}`);
}
assertInvalid(validateGetTrace, { ...traceInput, maxSpans: 10 }, "get_trace rejects unencoded option name");

const validateCiLog = validatorFor("Mcp.Tools.CiLogInput");
assertValid(validateCiLog, {}, "ci_log existing default input");
assertValid(validateCiLog, { service_prefix: "custom-ci", limit: 5 }, "ci_log custom run-list prefix");
assertValid(validateCiLog, { service_prefix: "custom-ci", run_id: "build-42" }, "ci_log custom phase prefix");
assertValid(validateCiLog, { service_prefix: "x".repeat(256) }, "ci_log prefix length upper bound");
for (const service_prefix of ["", "x".repeat(257), 12, false]) {
  assertInvalid(validateCiLog, { service_prefix }, `ci_log invalid prefix ${JSON.stringify(service_prefix)}`);
}
assertInvalid(validateCiLog, { servicePrefix: "custom-ci" }, "ci_log rejects unencoded prefix name");

// MCP requires every tool inputSchema and outputSchema to be `type: "object"` at the root,
// including the discriminated fetch_telemetry input.
const nonObjectToolSchemas = Object.entries(defs)
  .filter(([name]) => /^Mcp\.Tools\.\w+(Input|Output)$/u.test(name))
  .filter(([, definition]) => definition.type !== "object")
  .map(([name]) => name);
if (nonObjectToolSchemas.length > 0) {
  throw new Error(`MCP tool schemas must be type object at the root: ${nonObjectToolSchemas.join(", ")}.`);
}
const fetchTelemetryRoot = defs["Mcp.Tools.FetchTelemetryInput"];
if (fetchTelemetryRoot?.type !== "object" || fetchTelemetryRoot.oneOf?.length !== 5 ||
    fetchTelemetryRoot.discriminator?.propertyName !== "view") {
  throw new Error("Mcp.Tools.FetchTelemetryInput must be an object discriminated on view over five variants.");
}

// Contract 11.6.0 tool layer: fetch_telemetry views, structured matchers, pagination, errors.
const traceId = "0123456789abcdef0123456789abcdef";
const validateFetch = validatorFor("Mcp.Tools.FetchTelemetryInput");
assertValid(validateFetch, { view: "traces", limit: 20 }, "fetch_telemetry traces view");
assertValid(validateFetch, { view: "trace", trace_id: traceId }, "fetch_telemetry trace view");
assertValid(validateFetch, { view: "logs", severity_min: 17 }, "fetch_telemetry logs view");
assertValid(validateFetch, { view: "mcp_stats", hours: 24 }, "fetch_telemetry mcp_stats view");
assertInvalid(validateFetch, { view: "trace" }, "fetch_telemetry trace view without trace_id");
assertInvalid(validateFetch, { view: "mcp_stats", hours: 1.5 }, "fetch_telemetry fractional hours");
assertInvalid(validateFetch, { view: "traces", hours: 24 }, "fetch_telemetry member of another view");

const validateDashboard = validatorFor("Mcp.Tools.DisplayMcpDashboardInput");
assertValid(validateDashboard, { hours: 168 }, "display_mcp_dashboard integer hours");
assertInvalid(validateDashboard, { hours: 2.5 }, "display_mcp_dashboard fractional hours");

const validateListTraces = validatorFor("Mcp.Tools.ListTracesInput");
assertValid(validateListTraces, {
  limit: 10, start_time: "2026-10-11T00:00:00Z", end_time: "2026-10-11T01:00:00Z",
  service_name: "api", errors_only: true, cursor: "opaque",
}, "list_traces filters and cursor");
const validateListTracesOutput = validatorFor("Mcp.Tools.ListTracesOutput");
assertValid(validateListTracesOutput, { traces: [], mode: "live", has_more: true, next_cursor: "n", window: {start_time: "2026-10-12T00:00:00Z", end_time: "2026-10-12T01:00:00Z"}, coverage: {examined: 0, matched: 0, returned: 0, truncated: false, scan_complete: true, as_of: "2026-10-12T01:00:00Z"} }, "list_traces page");
assertInvalid(validateListTracesOutput, { traces: [], mode: "live" }, "list_traces output without has_more");

const validateToolError = validatorFor("Mcp.Tools.ToolError");
assertValid(validateToolError, { code: "collector_timeout", message: "timed out", retryable: true }, "tool error");
for (const code of ["insufficient_scope", "conflict", "precondition_failed", "precondition_required"]) {
  assertValid(validateToolError, { code, message: "write refused", retryable: false }, `tool error ${code}`);
}
assertInvalid(validateToolError, { code: "timeout", message: "timed out", retryable: true }, "tool error with an unknown code");

const validateRunResult = validatorFor("SavedQueries.SavedQueryRunResult");
const traceSummary = {
  trace_id: traceId, span_count: 3, duration_ns: "1000", start_time: "2026-10-11T00:00:00Z",
  end_time: "2026-10-11T00:00:01Z", services: ["api"], has_error: false,
};
assertValid(validateRunResult, { signal: "traces", items: [traceSummary], has_more: true, next_cursor: "n" }, "saved trace query run page of summaries");
assertInvalid(validateRunResult, { signal: "traces", items: [{ spans: [] }], has_more: false }, "saved trace query run with a full span tree");

const validateQueryMetric = validatorFor("Mcp.Tools.QueryMetricInput");
assertValid(validateQueryMetric, {
  metric_name: "http.server.request.duration", start_time: "2026-10-11T00:00:00Z", end_time: "2026-10-11T01:00:00Z",
  step_ms: 60000, matchers: [{ key: "http.route", op: "prefix", value: "/api" }], group_by: ["http.route"],
}, "query_metric structured matchers");
assertInvalid(validateQueryMetric, {
  metric_name: "m", start_time: "2026-10-11T00:00:00Z", end_time: "2026-10-11T01:00:00Z", attr: ["a=b"],
}, "query_metric string matcher");
assertInvalid(validateQueryMetric, {
  metric_name: "m", start_time: "2026-10-11T00:00:00Z", end_time: "2026-10-11T01:00:00Z", step_ms: 1.5,
}, "query_metric fractional step_ms");

// Write resources.
const validateAnnotationCreate = validatorFor("Annotations.AnnotationCreateRequest");
assertValid(validateAnnotationCreate, { target: { kind: "trace", trace_id: traceId }, text: "x".repeat(2000) }, "annotation at 2000 characters");
assertValid(validateAnnotationCreate, {
  target: { kind: "span", trace_id: traceId, span_id: "b7ad6b7169203331" }, text: "slow span",
}, "span annotation");
assertValid(validateAnnotationCreate, { target: { kind: "session", session_id: "s-1" }, text: "note" }, "session annotation");
assertInvalid(validateAnnotationCreate, { target: { kind: "trace", trace_id: traceId }, text: "x".repeat(2001) }, "annotation over 2000 characters");
assertInvalid(validateAnnotationCreate, { target: { kind: "span", trace_id: traceId }, text: "x" }, "span annotation without span_id");
assertInvalid(validateAnnotationCreate, { id: "a", target: { kind: "trace", trace_id: traceId }, text: "x" }, "annotation create with a server-assigned id");

const validateSavedQueryCreate = validatorFor("SavedQueries.SavedQueryCreateRequest");
assertValid(validateSavedQueryCreate, { name: "errors", filter: { signal: "traces", errors_only: true, lookback_minutes: 60 } }, "saved trace query");
assertValid(validateSavedQueryCreate, {
  name: "p95", filter: { signal: "metrics", metric_name: "m", aggregation: "p95", matchers: [{ key: "k", op: "eq", value: "v" }] },
}, "saved metric query");
assertInvalid(validateSavedQueryCreate, { name: "m", filter: { signal: "metrics" } }, "saved metric query without metric_name");
assertInvalid(validateSavedQueryCreate, { name: "x", filter: { signal: "spans" } }, "saved query with an unknown signal");
const validateSavedQueryUpdate = validatorFor("SavedQueries.SavedQueryUpdateRequest");
assertValid(validateSavedQueryUpdate, { name: "renamed" }, "saved query partial update");
assertInvalid(validateSavedQueryUpdate, { etag: "e" }, "saved query update with a server-assigned etag");

function assertReferences(definition, expected) {
  const actual = (defs[definition]?.oneOf ?? []).map((variant) => variant.$ref);
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${definition} oneOf variants drifted: ${JSON.stringify(actual)}.`);
  }
}

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
  ["Operations.MetricsApi_list.Response.200", "#/$defs/OTel.Metrics.MetricDescriptor"],
  ["Operations.MetricsApi_listSeries.Response.200", "#/$defs/OTel.Metrics.MetricSeries"],
  ["Operations.AnnotationsApi_list.Response.200", "#/$defs/Annotations.Annotation"],
  ["Operations.SavedQueriesApi_list.Response.200", "#/$defs/SavedQueries.SavedQuery"],
]);
// Contract 12.0.0: a page hands out an opaque `Cursor` token, has no backward
// cursor, and omits the token on the last page instead of sending null.
const cursorRef = "#/$defs/Common.Cursor";
for (const [definition, itemReference] of cursorPageDefinitions) {
  const page = defs[definition];
  if (!page ||
      !page.required?.includes("items") ||
      !page.required?.includes("has_more") ||
      page.properties?.items?.type !== "array" ||
      page.properties.items.items?.$ref !== itemReference ||
      page.properties?.next_cursor?.$ref !== cursorRef ||
      page.required.includes("next_cursor") ||
      "prev_cursor" in (page.properties ?? {}) ||
      page.properties?.has_more?.type !== "boolean" ||
      JSON.stringify(page.unevaluatedProperties) !== JSON.stringify({ not: {} })) {
    throw new Error(`${definition} must remain the exact closed CursorPage envelope for ${itemReference}.`);
  }

  const validatePage = validatorFor(definition);
  assertValid(validatePage, { items: [], next_cursor: "next", has_more: true }, `${definition} page with a next cursor`);
  assertValid(validatePage, { items: [], has_more: false }, `${definition} last page without a cursor`);
  assertInvalid(validatePage, { items: [], next_cursor: null, has_more: false }, `${definition} with a null cursor`);
  assertInvalid(
    validatePage,
    { items: [], next_cursor: "next", prev_cursor: "previous", has_more: true },
    `${definition} with the removed prev_cursor`,
  );
  assertInvalid(validatePage, { items: [] }, `${definition} without has_more`);
  assertInvalid(validatePage, { items: [], has_more: "false" }, `${definition} with non-boolean has_more`);
  assertInvalid(validatePage, { items: [{}], has_more: false }, `${definition} with an invalid item`);
  assertInvalid(validatePage, { items: [], has_more: false, total: 0 }, `${definition} with an undeclared field`);
}

const workbenchPageItems = new Map([
  ["Workbench.WorkbenchProtocolEventPage", "events"],
  ["Workbench.WorkbenchExecutionPage", "executions"],
  ["Workbench.WorkbenchTestCasePage", "test_cases"],
  ["Workbench.WorkbenchTestSuitePage", "suites"],
  ["Workbench.WorkbenchEvaluationRunPage", "runs"],
]);
for (const [definition, itemsKey] of workbenchPageItems) {
  const page = defs[definition];
  if (page?.properties?.[itemsKey]?.type !== "array" ||
      page.properties?.next_cursor?.$ref !== cursorRef ||
      page.required?.includes("next_cursor") ||
      "prev_cursor" in (page.properties ?? {})) {
    throw new Error(`${definition} must page its ${itemsKey} with an optional opaque next_cursor.`);
  }
  const validatePage = validatorFor(definition);
  assertValid(validatePage, { [itemsKey]: [] }, `${definition} last page without a cursor`);
  assertInvalid(validatePage, { [itemsKey]: [], next_cursor: null }, `${definition} with a null cursor`);
}

const pageLimit = defs["Common.Pagination.PageLimit"];
if (pageLimit?.type !== "integer" || pageLimit.minimum !== 1 || pageLimit.maximum !== 1000) {
  throw new Error("Common.Pagination.PageLimit must be the one page-size rule: an integer from 1 to 1000.");
}
const runRequestLimit = defs["SavedQueries.SavedQueryRunRequest"]?.properties?.limit;
if (runRequestLimit?.$ref !== "#/$defs/Common.Pagination.PageLimit" || runRequestLimit.default !== 100) {
  throw new Error("SavedQueryRunRequest.limit must be a PageLimit that defaults to 100.");
}

// Contract 12.0.0 problem details: RFC 9457 members plus `code`, no header-borne
// members in the body, and one `type` URI and `code` per problem type.
const problemTypes = new Map([
  ["ValidationError", ["validation-failed", "validation_failed", "Validation Failed", 400]],
  ["UnauthorizedError", ["unauthorized", "unauthorized", "Unauthorized", 401]],
  ["ForbiddenError", ["forbidden", "forbidden", "Forbidden", 403]],
  ["NotFoundError", ["not-found", "not_found", "Not Found", 404]],
  ["ConflictError", ["conflict", "conflict", "Conflict", 409]],
  ["PreconditionFailedError", ["precondition-failed", "precondition_failed", "Precondition Failed", 412]],
  ["PreconditionRequiredError", ["precondition-required", "precondition_required", "Precondition Required", 428]],
  ["InternalServerError", ["internal-error", "internal_error", "Internal Server Error", 500]],
  ["BadGatewayError", ["bad-gateway", "bad_gateway", "Bad Gateway", 502]],
  ["ServiceUnavailableError", ["service-unavailable", "service_unavailable", "Service Unavailable", 503]],
]);
const problemDetails = defs["Common.Errors.ProblemDetails"];
const problemMembers = Object.keys(problemDetails?.properties ?? {}).sort((left, right) => left.localeCompare(right));
if (JSON.stringify(problemMembers) !== JSON.stringify(["code", "detail", "instance", "status", "title", "type"]) ||
    JSON.stringify([...(problemDetails?.required ?? [])].sort((left, right) => left.localeCompare(right))) !== JSON.stringify(["code", "status", "title", "type"])) {
  throw new Error(`ProblemDetails must carry exactly the RFC 9457 members plus code; it has ${problemMembers.join(", ")}.`);
}
const publishedTypes = defs["Common.Errors.ProblemType"]?.enum ?? [];
const publishedCodes = defs["Common.Errors.ProblemCode"]?.enum ?? [];
const expectedTypes = [...problemTypes.values()].map(([slug]) => `https://qyl.at/problems/${slug}`);
const expectedCodes = [...problemTypes.values()].map(([, code]) => code);
if (JSON.stringify(publishedTypes) !== JSON.stringify(expectedTypes) ||
    JSON.stringify(publishedCodes) !== JSON.stringify(expectedCodes)) {
  throw new Error(`ProblemType/ProblemCode drifted: ${JSON.stringify(publishedTypes)} / ${JSON.stringify(publishedCodes)}.`);
}
const derivedProblems = Object.entries(defs)
  .filter(([, definition]) => definition.allOf?.some((entry) => entry.$ref === "#/$defs/Common.Errors.ProblemDetails"))
  .map(([name]) => name.replace("Common.Errors.", ""))
  .sort((left, right) => left.localeCompare(right));
if (JSON.stringify(derivedProblems) !== JSON.stringify([...problemTypes.keys()].sort((left, right) => left.localeCompare(right)))) {
  throw new Error(`Every problem type needs a fixture row; published: ${derivedProblems.join(", ")}.`);
}
for (const [model, [slug, code, title, status]] of problemTypes) {
  const definition = `Common.Errors.${model}`;
  const validateProblem = validatorFor(definition);
  const body = {
    type: `https://qyl.at/problems/${slug}`,
    title,
    status,
    code,
    detail: "what went wrong in this occurrence",
    ...(model === "ValidationError" ? { errors: [{ field: "limit", message: "must be at most 1000", code: "max_value" }] } : {}),
  };
  assertValid(validateProblem, body, `${model} problem`);
  assertInvalid(validateProblem, { ...body, type: "about:blank" }, `${model} without its problem type URI`);
  assertInvalid(
    validateProblem,
    { ...body, code: code === "conflict" ? "not_found" : "conflict" },
    `${model} with another problem type's code`,
  );
  const withoutCode = { ...body };
  delete withoutCode.code;
  assertInvalid(validateProblem, withoutCode, `${model} without code`);
  for (const removed of ["trace_id", "request_id", "timestamp", "error_code", "www_authenticate", "retry_after"]) {
    assertInvalid(validateProblem, { ...body, [removed]: "x" }, `${model} with the removed body member ${removed}`);
  }
}

const csharpErrorsRuntime = await readFile("generated/contracts/Qyl/Api/Contracts/Common/Errors.cs", "utf8");
const csharpPaginationRuntime = await readFile("generated/contracts/Qyl/Api/Contracts/Common/Pagination.cs", "utf8");
const csharpTracesRuntime = await readFile("generated/contracts/Qyl/Api/Contracts/OTel/Traces.cs", "utf8");
// Templates, unions and filter models no operation used. None may come back as
// a definition, a TypeScript type or a C# type.
for (const removedDefinition of [
  "Common.Errors.ApiError",
  "Common.Errors.RateLimitError",
  "Common.Pagination.CursorPaginationParams",
  "Common.Pagination.SortOrder",
  "Common.Pagination.OffsetPaginationParams",
  "Common.Pagination.OffsetPage",
  "Common.Pagination.TimeRangeParams",
  "Common.Pagination.TimeRangePage",
  "Common.Pagination.StreamParams",
  "Common.Pagination.StreamEvent",
  "Common.Pagination.AggregationParams",
  "Common.Pagination.TimeBucket",
  "OTel.Traces.SpanQueryFilters",
]) {
  if (removedDefinition in defs) throw new Error(`${removedDefinition} must not survive the Contract 12.0.0 cleanup.`);
  const typeName = removedDefinition.split(".").at(-1);
  const declaration = new RegExp(`\\b(?:class|const|enum|interface|record|struct|type)\\s+${typeName}\\w*\\b`, "u");
  if ([tsRuntime, csharpErrorsRuntime, csharpPaginationRuntime, csharpTracesRuntime].some((source) => declaration.test(source))) {
    throw new Error(`${typeName} must not survive in generated TypeScript or C# contracts.`);
  }
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
    schema_url: "https://opentelemetry.io/schemas/1.44.0",
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
  body: "evaluation completed",
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

// Profiles are still out of scope, and these enums mirrored raw OTLP wire
// vocabulary no route ever exposed. OTel.Metrics is no longer on this list:
// the collector stores metrics, and the query surface below is asserted
// present rather than absent.
const removedSignalDefinitions = Object.keys(defs).filter((definition) =>
  definition.startsWith("OTel.Profiles.")
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
  path.startsWith("/api/v1/profiles")
);
if (removedSignalDefinitions.length > 0 || removedSignalPaths.length > 0) {
  throw new Error(
    `Removed signal contract survived. Definitions: ${removedSignalDefinitions.join(", ") || "none"}. ` +
    `Paths: ${removedSignalPaths.join(", ") || "none"}.`,
  );
}

const missingMetricSurface = [
  "OTel.Metrics.MetricDescriptor",
  "OTel.Metrics.MetricSeries",
  "OTel.Metrics.MetricQueryResult",
  "OTel.Metrics.MetricAggregation",
].filter((definition) => !(definition in defs)).concat(
  ["/api/v1/metrics", "/api/v1/metrics/{metric_name}/series", "/api/v1/metrics/{metric_name}/query"]
    .filter((path) => openapi.paths?.[path]?.get === undefined),
);
if (missingMetricSurface.length > 0) {
  throw new Error(`Metric query contract is incomplete: ${missingMetricSurface.join(", ")}.`);
}

await import("./verify-analysis-contracts.mjs");
