import { readFile } from "node:fs/promises";

const openapiPath = "generated/openapi/qyl.openapi.json";
const openapi = JSON.parse(await readFile(openapiPath, "utf8"));
const httpMethods = new Set(["delete", "get", "head", "options", "patch", "post", "put", "trace"]);
const operations = new Map(
  Object.entries(openapi.paths ?? {}).flatMap(([path, pathItem]) =>
    Object.entries(pathItem)
      .filter(([method]) => httpMethods.has(method))
      .map(([method, operation]) => [`${method.toUpperCase()} ${path}`, operation]),
  ),
);

function verifyExactResponse(operationId, status, schemaName) {
  const operation = operations.get(operationId);
  if (!operation) throw new Error(`${operationId} is missing from ${openapiPath}.`);

  const content = operation.responses?.[status]?.content ?? {};
  const mediaType = "application/problem+json";
  const schema = `#/components/schemas/Common.Errors.${schemaName}`;
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
const workflowTags = new Set(["Workflow runs"]);
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
const expectedWorkflowOperations = new Set([
  "POST /api/v1/workflow-runs",
  "GET /api/v1/workflow-runs",
  "GET /api/v1/workflow-runs/{run_id}",
  "POST /api/v1/workflow-runs/{run_id}/events",
  "GET /api/v1/workflow-runs/{run_id}/events",
  "GET /api/v1/workflow-runs/{run_id}/graph",
  "GET /api/v1/workflow-runs/{run_id}/content/{content_ref}",
  "GET /api/v1/workflow-runs/{run_id}/stream",
  "POST /api/v1/workflow-runs/{run_id}/commands",
  "GET /api/v1/workflow-runs/{run_id}/commands",
  "POST /api/v1/workflow-runs/{run_id}/commands/{command_id}/status",
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
verifyOperationInventory("Workflow", workflowTags, expectedWorkflowOperations);

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
for (const operationId of expectedWorkflowOperations) {
  verifyExactResponse(operationId, "401", "UnauthorizedError");
  const security = operations.get(operationId)?.security;
  if (JSON.stringify(security) !== JSON.stringify([{ ApiKeyAuth: [] }])) {
    throw new Error(`${operationId} must require only the x-otlp-api-key ApiKeyAuth scheme.`);
  }
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
  ...expectedWorkflowOperations,
  "GET /api/v1/stream/logs",
]);
for (const operationId of capacityLimitedOperations) {
  verifyExactResponse(operationId, "503", "ServiceUnavailableError");
}

const validationQueries = new Map([
  ["GET /api/v1/traces", ["limit", "cursor"]],
  ["GET /api/v1/logs", ["severity_min", "start_time", "end_time", "limit"]],
  ["GET /api/v1/sessions", ["is_active", "start_time", "end_time", "limit", "cursor"]],
  ["GET /api/v1/sessions/stats", ["start_time", "end_time"]],
  ["GET /api/v1/stream/logs", ["min_severity"]],
  ["GET /api/v1/workflow-runs", ["status", "limit", "cursor"]],
  ["GET /api/v1/workflow-runs/{run_id}/events", ["after_sequence", "limit", "wait_ms"]],
  ["GET /api/v1/workflow-runs/{run_id}/commands", ["after_sequence", "limit", "wait_ms"]],
  ["GET /workbench/workspaces/{workspace_id}/servers/{server_id}/protocol", ["cursor", "limit"]],
  ["GET /workbench/workspaces/{workspace_id}/servers/{server_id}/executions", ["status", "cursor", "limit"]],
  ["GET /workbench/workspaces/{workspace_id}/test-cases", ["server_id", "tool_name", "cursor", "limit"]],
  ["GET /workbench/workspaces/{workspace_id}/suites", ["cursor", "limit"]],
  ["GET /workbench/workspaces/{workspace_id}/evaluation-runs", ["status", "cursor", "limit"]],
]);
for (const [operationId, runtimeValidatedQueries] of validationQueries) {
  const operation = operations.get(operationId);
  if (!operation) throw new Error(`${operationId} is missing from ${openapiPath}.`);

  const declaredQueries = new Set(
    (operation.parameters ?? []).filter((parameter) => parameter.in === "query").map((parameter) => parameter.name),
  );
  const missingQueries = runtimeValidatedQueries.filter((query) => !declaredQueries.has(query));
  if (missingQueries.length > 0) {
    throw new Error(`${operationId} omits runtime-validated query parameter(s): ${missingQueries.join(", ")}.`);
  }
  verifyExactResponse(operationId, "400", "ValidationError");
}

const resumableSseOperations = new Set([
  "GET /api/v1/stream/logs",
  "GET /api/v1/workflow-runs/{run_id}/stream",
  "GET /runner/resources/{resource}/logs/stream",
  "GET /workbench/workspaces/{workspace_id}/servers/{server_id}/protocol/stream",
  "GET /workbench/workspaces/{workspace_id}/servers/{server_id}/executions/stream",
]);
for (const operationId of resumableSseOperations) {
  const operation = operations.get(operationId);
  if (!operation) throw new Error(`${operationId} is missing from ${openapiPath}.`);

  const lastEventId = (operation.parameters ?? []).find((parameter) =>
    parameter.in === "header" && parameter.name.toLowerCase() === "last-event-id"
  );
  if (!lastEventId || lastEventId.required === true || lastEventId.schema?.type !== "string") {
    throw new Error(`${operationId} must declare optional string header Last-Event-ID.`);
  }
}

console.log(
  `Verified ${expectedRunnerOperations.size} runner, ${expectedWorkbenchOperations.size} workbench, and ` +
  `${expectedWorkflowOperations.size} workflow routes, ` +
  `${expectedWorkbenchOperations.size - publicWorkbenchOperations.size} private workbench operations, ` +
  `${capacityLimitedOperations.size} capacity responses, and ` +
  `${validationQueries.size} typed-query validation responses, and ` +
  `${resumableSseOperations.size} resumable SSE headers.`,
);
