import { httpMethods, openApiPath, readOpenApi } from "./lib/openapi.mjs";

const openapi = await readOpenApi();
const operations = new Map(
  Object.entries(openapi.paths ?? {}).flatMap(([path, pathItem]) =>
    Object.entries(pathItem)
      .filter(([method]) => httpMethods.has(method))
      .map(([method, operation]) => [`${method.toUpperCase()} ${path}`, operation]),
  ),
);

function requireOperation(operationId) {
  const operation = operations.get(operationId);
  if (!operation) throw new Error(`${operationId} is missing from ${openApiPath}.`);
  return operation;
}

function verifyExactResponse(operationId, status, schemaName, schemaNamespace = "Common.Errors") {
  const operation = requireOperation(operationId);

  const content = operation.responses?.[status]?.content ?? {};
  const mediaType = "application/problem+json";
  const schema = `#/components/schemas/${schemaNamespace}.${schemaName}`;
  if (Object.keys(content).length !== 1 || content[mediaType]?.schema?.$ref !== schema) {
    throw new Error(`${operationId} must declare ${status} ${mediaType} ${schema}.`);
  }
}

const runnerTags = new Set(["Runner resources"]);
const workbenchTags = new Set([
  "Workbench session",
  "Workbench workspaces",
  "Workbench MCP servers",
  "Workbench MCP executions",
  "Workbench MCP test cases",
  "Workbench MCP suites",
  "Workbench MCP evaluations",
]);
const expectedRunnerOperations = new Set([
  "GET /runner/resources",
  "GET /runner/resources/stream",
  "GET /runner/resources/{resource}/logs",
  "GET /runner/resources/{resource}/logs/stream",
  "POST /runner/resources/{resource}/restart",
  "POST /runner/resources/{resource}/stop",
]);
const expectedWorkbenchOperations = new Set([
  "GET /workbench/session",
  "POST /workbench/session",
  "GET /workbench/workspaces",
  "POST /workbench/workspaces",
  "GET /workbench/workspaces/{workspace_id}",
  "PATCH /workbench/workspaces/{workspace_id}",
  "DELETE /workbench/workspaces/{workspace_id}",
  "GET /workbench/workspaces/{workspace_id}/preferences",
  "PUT /workbench/workspaces/{workspace_id}/preferences",
  "GET /workbench/workspaces/{workspace_id}/servers",
  "POST /workbench/workspaces/{workspace_id}/servers",
  "GET /workbench/workspaces/{workspace_id}/servers/{server_id}",
  "PATCH /workbench/workspaces/{workspace_id}/servers/{server_id}",
  "DELETE /workbench/workspaces/{workspace_id}/servers/{server_id}",
  "POST /workbench/workspaces/{workspace_id}/servers/{server_id}/connect",
  "POST /workbench/workspaces/{workspace_id}/servers/{server_id}/disconnect",
  "POST /workbench/workspaces/{workspace_id}/servers/{server_id}/reconnect",
  "GET /workbench/workspaces/{workspace_id}/servers/{server_id}/discovery",
  "POST /workbench/workspaces/{workspace_id}/servers/{server_id}/discovery/refresh",
  "GET /workbench/workspaces/{workspace_id}/servers/{server_id}/protocol",
  "GET /workbench/workspaces/{workspace_id}/servers/{server_id}/protocol/stream",
  "GET /workbench/workspaces/{workspace_id}/servers/{server_id}/executions",
  "POST /workbench/workspaces/{workspace_id}/servers/{server_id}/executions",
  "GET /workbench/workspaces/{workspace_id}/servers/{server_id}/executions/stream",
  "GET /workbench/workspaces/{workspace_id}/servers/{server_id}/executions/{execution_id}",
  "POST /workbench/workspaces/{workspace_id}/servers/{server_id}/executions/{execution_id}/cancel",
  "GET /workbench/workspaces/{workspace_id}/servers/{server_id}/executions/{execution_id}/telemetry",
  "GET /workbench/workspaces/{workspace_id}/test-cases",
  "POST /workbench/workspaces/{workspace_id}/test-cases",
  "GET /workbench/workspaces/{workspace_id}/test-cases/{test_case_id}",
  "PATCH /workbench/workspaces/{workspace_id}/test-cases/{test_case_id}",
  "DELETE /workbench/workspaces/{workspace_id}/test-cases/{test_case_id}",
  "POST /workbench/workspaces/{workspace_id}/test-cases/{test_case_id}/run",
  "GET /workbench/workspaces/{workspace_id}/suites",
  "POST /workbench/workspaces/{workspace_id}/suites",
  "GET /workbench/workspaces/{workspace_id}/suites/{suite_id}",
  "PATCH /workbench/workspaces/{workspace_id}/suites/{suite_id}",
  "DELETE /workbench/workspaces/{workspace_id}/suites/{suite_id}",
  "POST /workbench/workspaces/{workspace_id}/suites/{suite_id}/run",
  "GET /workbench/workspaces/{workspace_id}/evaluation-runs",
  "GET /workbench/workspaces/{workspace_id}/evaluation-runs/{evaluation_run_id}",
  "POST /workbench/workspaces/{workspace_id}/evaluation-runs/compare",
  "POST /workbench/workspaces/{workspace_id}/evaluation-runs/{evaluation_run_id}/export",
  "GET /workbench/workspaces/{workspace_id}/evaluation-runs/{evaluation_run_id}/exports/{export_id}",
  "GET /workbench/workspaces/{workspace_id}/evaluation-runs/{evaluation_run_id}/exports/{export_id}/content",
]);

function verifyOperationInventory(label, tags, expected) {
  const actual = new Set(
    [...operations].filter(([, operation]) =>
      operation.tags?.some((tag) => tags.has(tag)),
    ).map(([id]) => id),
  );
  const missing = [...expected].filter((id) => !actual.has(id));
  const unexpected = [...actual].filter((id) => !expected.has(id));
  if (missing.length > 0 || unexpected.length > 0) {
    throw new Error(
      `${label} operation inventory drifted. Missing: ${missing.join(", ") || "none"}. ` +
      `Unexpected: ${unexpected.join(", ") || "none"}. Update the TypeSpec owner and this inventory together.`,
    );
  }
}

verifyOperationInventory("Runner", runnerTags, expectedRunnerOperations);
verifyOperationInventory("Workbench", workbenchTags, expectedWorkbenchOperations);

for (const operationId of expectedRunnerOperations) {
  verifyExactResponse(operationId, "403", "ForbiddenError");
  const security = operations.get(operationId)?.security;
  if (security !== undefined && security.length !== 0) {
    throw new Error(`${operationId} must remain loopback-protected without a wire credential.`);
  }
}
for (const operationId of expectedWorkbenchOperations) {
  verifyExactResponse(operationId, "401", "UnauthorizedError");
  verifyExactResponse(operationId, "403", "ForbiddenError");
}

const workbenchCookieAuthName = "WorkbenchSessionCookieAuth";
const workbenchCookieAuth = openapi.components?.securitySchemes?.[workbenchCookieAuthName];
if (workbenchCookieAuth?.type !== "apiKey" || workbenchCookieAuth.in !== "cookie" ||
    workbenchCookieAuth.name !== "qyl-workbench-session") {
  throw new Error(`${workbenchCookieAuthName} must be the qyl-workbench-session cookie security scheme.`);
}
const publicWorkbenchOperations = new Set(["POST /workbench/session"]);
for (const operationId of expectedWorkbenchOperations) {
  const security = operations.get(operationId)?.security;
  if (publicWorkbenchOperations.has(operationId)) {
    if (security !== undefined && security.length !== 0) {
      throw new Error(`${operationId} must remain an unauthenticated local bootstrap surface.`);
    }
    continue;
  }
  if (JSON.stringify(security) !== JSON.stringify([{ [workbenchCookieAuthName]: [] }])) {
    throw new Error(`${operationId} must require only ${workbenchCookieAuthName}.`);
  }
}

const bootstrapResponse = operations.get("POST /workbench/session")?.responses?.["200"];
const setCookie = bootstrapResponse?.headers?.["Set-Cookie"];
if (setCookie?.required !== true || setCookie.schema?.type !== "string" ||
    !setCookie.description?.includes("HttpOnly") || !setCookie.description?.includes("SameSite")) {
  throw new Error("POST /workbench/session must declare a required HttpOnly/SameSite Set-Cookie response header.");
}

const capacityLimitedOperations = new Set([
  ...expectedRunnerOperations,
  ...expectedWorkbenchOperations,
  "GET /api/v1/stream/logs",
]);
for (const operationId of capacityLimitedOperations) {
  verifyExactResponse(operationId, "503", "ServiceUnavailableError");
}

const validationQueries = new Map([
  ["GET /api/v1/traces", ["start_time", "end_time", "service_name", "errors_only", "limit", "cursor"]],
  ["GET /api/v1/traces/{trace_id}/spans", ["limit", "cursor"]],
  ["GET /api/v1/logs", ["severity_min", "start_time", "end_time", "limit", "cursor"]],
  ["GET /api/v1/metrics", ["limit", "cursor"]],
  ["GET /api/v1/metrics/{metric_name}/series", ["limit", "cursor"]],
  ["GET /api/v1/sessions/{session_id}/traces", ["limit", "cursor"]],
  ["GET /api/v1/annotations", ["limit", "cursor"]],
  ["GET /api/v1/saved-queries", ["signal", "limit", "cursor"]],
  ["GET /api/v1/sessions", ["is_active", "start_time", "end_time", "limit", "cursor"]],
  ["GET /api/v1/sessions/stats", ["start_time", "end_time"]],
  ["GET /api/v1/stream/logs", ["min_severity"]],
  ["GET /workbench/workspaces/{workspace_id}/servers/{server_id}/protocol", ["cursor", "limit"]],
  ["GET /workbench/workspaces/{workspace_id}/servers/{server_id}/executions", ["status", "cursor", "limit"]],
  ["GET /workbench/workspaces/{workspace_id}/test-cases", ["server_id", "tool_name", "cursor", "limit"]],
  ["GET /workbench/workspaces/{workspace_id}/suites", ["cursor", "limit"]],
  ["GET /workbench/workspaces/{workspace_id}/evaluation-runs", ["status", "cursor", "limit"]],
]);
for (const [operationId, runtimeValidatedQueries] of validationQueries) {
  const operation = requireOperation(operationId);

  const declaredQueries = new Set(
    (operation.parameters ?? []).filter((parameter) => parameter.in === "query").map((parameter) => parameter.name),
  );
  const missingQueries = runtimeValidatedQueries.filter((query) => !declaredQueries.has(query));
  if (missingQueries.length > 0) {
    throw new Error(`${operationId} omits runtime-validated query parameter(s): ${missingQueries.join(", ")}.`);
  }
  verifyExactResponse(operationId, "400", "ValidationError");
}

// Every list operation pages the same way: an optional opaque `cursor`, an
// optional `limit` of the one PageLimit rule (100 when omitted), and a page whose
// optional `next_cursor` is that same opaque Cursor. Pages are forward-only.
const listOperations = new Set([
  "GET /api/v1/traces",
  "GET /api/v1/traces/{trace_id}/spans",
  "GET /api/v1/logs",
  "GET /api/v1/metrics",
  "GET /api/v1/metrics/{metric_name}/series",
  "GET /api/v1/sessions",
  "GET /api/v1/sessions/{session_id}/traces",
  "GET /api/v1/annotations",
  "GET /api/v1/saved-queries",
  "GET /workbench/workspaces/{workspace_id}/servers/{server_id}/protocol",
  "GET /workbench/workspaces/{workspace_id}/servers/{server_id}/executions",
  "GET /workbench/workspaces/{workspace_id}/test-cases",
  "GET /workbench/workspaces/{workspace_id}/suites",
  "GET /workbench/workspaces/{workspace_id}/evaluation-runs",
]);
const queryParameter = (operation, name) =>
  (operation.parameters ?? []).find((parameter) => parameter.in === "query" && parameter.name === name);
const unlistedPagedOperations = [...operations]
  .filter(([, operation]) => queryParameter(operation, "limit") || queryParameter(operation, "cursor"))
  .map(([operationId]) => operationId)
  .filter((operationId) => !listOperations.has(operationId));
if (unlistedPagedOperations.length > 0) {
  throw new Error(`Paged operations outside the list inventory: ${unlistedPagedOperations.join(", ")}.`);
}

const schemaRef = (name) => `#/components/schemas/${name}`;
const componentSchema = (ref) => openapi.components?.schemas?.[ref?.replace("#/components/schemas/", "")];
const pageLimitRef = schemaRef("Common.Pagination.PageLimit");
const cursorRef = schemaRef("Common.Cursor");
const pageLimit = componentSchema(pageLimitRef);
if (pageLimit?.type !== "integer" || pageLimit.minimum !== 1 || pageLimit.maximum !== 1000) {
  throw new Error("Common.Pagination.PageLimit must be the one page-size rule: an integer from 1 to 1000.");
}
for (const operationId of listOperations) {
  const operation = requireOperation(operationId);
  const limit = queryParameter(operation, "limit");
  if (!limit || limit.required === true || limit.schema?.$ref !== pageLimitRef || limit.schema.default !== 100) {
    throw new Error(`${operationId} must take an optional PageLimit limit that defaults to 100.`);
  }
  const cursor = queryParameter(operation, "cursor");
  if (!cursor || cursor.required === true || cursor.schema?.$ref !== cursorRef) {
    throw new Error(`${operationId} must take an optional opaque Cursor as cursor.`);
  }
  const body = operation.responses?.["200"]?.content?.["application/json"]?.schema;
  const page = body?.$ref ? componentSchema(body.$ref) : body;
  if (page?.properties?.next_cursor?.$ref !== cursorRef || page.required?.includes("next_cursor")) {
    throw new Error(`${operationId} must answer a page with an optional opaque next_cursor.`);
  }
}
const backwardCursors = [];
JSON.stringify(openapi, (key, value) => {
  if (key === "prev_cursor") backwardCursors.push(key);
  return value;
});
if (backwardCursors.length > 0) {
  throw new Error(`${backwardCursors.length} schema(s) still declare prev_cursor; pages are forward-only.`);
}

// The write surface: user-created resources on the shared write base.
const writeTags = new Set(["Annotations", "Saved queries"]);
const expectedWriteOperations = new Map([
  ["POST /api/v1/annotations", "create"],
  ["GET /api/v1/annotations", "read"],
  ["GET /api/v1/annotations/{annotation_id}", "read"],
  ["PATCH /api/v1/annotations/{annotation_id}", "update"],
  ["DELETE /api/v1/annotations/{annotation_id}", "delete"],
  ["POST /api/v1/saved-queries", "create"],
  ["GET /api/v1/saved-queries", "read"],
  ["GET /api/v1/saved-queries/{saved_query_id}", "read"],
  ["PATCH /api/v1/saved-queries/{saved_query_id}", "update"],
  ["DELETE /api/v1/saved-queries/{saved_query_id}", "delete"],
  ["POST /api/v1/saved-queries/{saved_query_id}:run", "read"],
]);
verifyOperationInventory("Write", writeTags, new Set(expectedWriteOperations.keys()));

const parameterRefs = (operation) => new Set((operation.parameters ?? []).map((parameter) => parameter.$ref).filter(Boolean));
const componentParameter = (name) => openapi.components?.parameters?.[name];
const idempotencyKey = componentParameter("Common.IdempotencyKeyHeader");
if (idempotencyKey?.in !== "header" || idempotencyKey.name !== "Idempotency-Key" || idempotencyKey.required === true) {
  throw new Error("Common.IdempotencyKeyHeader must be the optional Idempotency-Key header.");
}
const ifMatch = componentParameter("Common.IfMatchHeader");
if (ifMatch?.in !== "header" || ifMatch.name !== "If-Match" || ifMatch.required !== true) {
  throw new Error("Common.IfMatchHeader must be the required If-Match header.");
}
const writeSecurity = {
  read: "ApiKeyAuth",
  create: "QylWriteKeyAuth",
  update: "QylWriteKeyAuth",
  delete: "QylDeleteKeyAuth",
};
for (const [operationId, role] of expectedWriteOperations) {
  const operation = operations.get(operationId);
  if (JSON.stringify(operation.security) !== JSON.stringify([{ [writeSecurity[role]]: [] }])) {
    throw new Error(`${operationId} must require only ${writeSecurity[role]}.`);
  }
  const refs = parameterRefs(operation);
  if (role === "create") {
    if (!refs.has("#/components/parameters/Common.IdempotencyKeyHeader")) {
      throw new Error(`${operationId} must accept Idempotency-Key.`);
    }
    const created = operation.responses?.["201"];
    if (created?.headers?.Location?.required !== true || created.headers.ETag?.required !== true) {
      throw new Error(`${operationId} must answer 201 with required Location and ETag headers.`);
    }
    verifyExactResponse(operationId, "409", "ConflictError");
  }
  if (role === "update" || role === "delete") {
    if (!refs.has("#/components/parameters/Common.IfMatchHeader")) {
      throw new Error(`${operationId} must require If-Match.`);
    }
    verifyExactResponse(operationId, "412", "PreconditionFailedError");
    verifyExactResponse(operationId, "428", "PreconditionRequiredError");
  }
  if (role === "delete" && !operation.responses?.["204"]) {
    throw new Error(`${operationId} must answer 204.`);
  }
}
verifyExactResponse("PATCH /api/v1/saved-queries/{saved_query_id}", "409", "ConflictError");

// Problem bodies carry no headers. An error response declares a header only on
// the operations whose server sends it: the collector's 500 names the trace of
// the failed request, and the workbench's 401 names its cookie challenge.
const problemMediaType = "application/problem+json";
const servedProblemHeaders = (operationId, status) => {
  const path = operationId.slice(operationId.indexOf(" ") + 1);
  if (status === "500" && path.startsWith("/api/v1/")) return ["X-Trace-Id"];
  if (status === "401" && path.startsWith("/workbench/")) return ["WWW-Authenticate"];
  return [];
};
let problemResponses = 0;
for (const [operationId, operation] of operations) {
  for (const [status, response] of Object.entries(operation.responses ?? {})) {
    if (!response.content?.[problemMediaType]) continue;
    problemResponses += 1;
    const declared = Object.keys(response.headers ?? {}).sort((left, right) => left.localeCompare(right));
    const served = servedProblemHeaders(operationId, status);
    if (JSON.stringify(declared) !== JSON.stringify(served)) {
      throw new Error(
        `${operationId} ${status} declares header(s) [${declared.join(", ")}]; its server sends [${served.join(", ")}].`,
      );
    }
    const traceId = response.headers?.["X-Trace-Id"];
    if (traceId && (traceId.required === true || traceId.schema?.$ref !== schemaRef("Common.TraceId"))) {
      throw new Error(`${operationId} ${status} X-Trace-Id must be an optional Common.TraceId.`);
    }
    const challenge = response.headers?.["WWW-Authenticate"];
    if (challenge && (challenge.required !== true || challenge.schema?.type !== "string")) {
      throw new Error(`${operationId} ${status} WWW-Authenticate must be a required string.`);
    }
  }
}

const resumableSseOperations = new Set([
  "GET /api/v1/stream/logs",
  "GET /runner/resources/{resource}/logs/stream",
  "GET /workbench/workspaces/{workspace_id}/servers/{server_id}/protocol/stream",
  "GET /workbench/workspaces/{workspace_id}/servers/{server_id}/executions/stream",
]);
for (const operationId of resumableSseOperations) {
  const operation = requireOperation(operationId);

  const lastEventId = (operation.parameters ?? []).find((parameter) =>
    parameter.in === "header" && parameter.name.toLowerCase() === "last-event-id"
  );
  if (!lastEventId || lastEventId.required === true || lastEventId.schema?.type !== "string") {
    throw new Error(`${operationId} must declare optional string header Last-Event-ID.`);
  }
}

console.log(
  `Verified ${expectedRunnerOperations.size} runner and ${expectedWorkbenchOperations.size} workbench routes, ` +
  `${expectedWorkbenchOperations.size - publicWorkbenchOperations.size} private workbench operations, ` +
  `${capacityLimitedOperations.size} capacity responses, ` +
  `${validationQueries.size} typed-query validation responses, ` +
  `${resumableSseOperations.size} resumable SSE headers, ` +
  `${listOperations.size} cursor-paged lists, ${expectedWriteOperations.size} write-surface operations, and ` +
  `${problemResponses} problem responses with only their served headers.`,
);
