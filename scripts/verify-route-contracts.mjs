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

function verifyExactOpaqueJsonBody(content, label) {
  const mediaTypes = Object.keys(content ?? {});
  if (mediaTypes.length !== 1 || mediaTypes[0] !== "application/json" ||
      JSON.stringify(content?.["application/json"]?.schema) !== "{}") {
    throw new Error(`${label} must remain one opaque application/json body owned by the MCP SDK.`);
  }
}

const runnerTags = new Set([
  "Runner session",
  "Runner resources",
  "Runner workspaces",
  "Runner MCP servers",
  "Runner MCP executions",
  "Runner MCP test cases",
  "Runner MCP suites",
  "Runner MCP evaluations",
]);
const expectedRunnerOperations = new Set([
  "GET /runner/session",
  "POST /runner/session",
  "GET /runner/resources",
  "GET /runner/resources/stream",
  "GET /runner/resources/{resource}/logs",
  "GET /runner/resources/{resource}/logs/stream",
  "POST /runner/resources/{resource}/restart",
  "POST /runner/resources/{resource}/stop",
  "GET /runner/workspaces",
  "POST /runner/workspaces",
  "GET /runner/workspaces/{workspaceId}",
  "PATCH /runner/workspaces/{workspaceId}",
  "DELETE /runner/workspaces/{workspaceId}",
  "GET /runner/workspaces/{workspaceId}/preferences",
  "PUT /runner/workspaces/{workspaceId}/preferences",
  "GET /runner/workspaces/{workspaceId}/servers",
  "POST /runner/workspaces/{workspaceId}/servers",
  "GET /runner/workspaces/{workspaceId}/servers/{serverId}",
  "PATCH /runner/workspaces/{workspaceId}/servers/{serverId}",
  "DELETE /runner/workspaces/{workspaceId}/servers/{serverId}",
  "POST /runner/workspaces/{workspaceId}/servers/{serverId}/connect",
  "POST /runner/workspaces/{workspaceId}/servers/{serverId}/disconnect",
  "POST /runner/workspaces/{workspaceId}/servers/{serverId}/reconnect",
  "GET /runner/workspaces/{workspaceId}/servers/{serverId}/discovery",
  "POST /runner/workspaces/{workspaceId}/servers/{serverId}/discovery/refresh",
  "GET /runner/workspaces/{workspaceId}/servers/{serverId}/protocol",
  "GET /runner/workspaces/{workspaceId}/servers/{serverId}/protocol/stream",
  "GET /runner/workspaces/{workspaceId}/servers/{serverId}/executions",
  "POST /runner/workspaces/{workspaceId}/servers/{serverId}/executions",
  "GET /runner/workspaces/{workspaceId}/servers/{serverId}/executions/stream",
  "GET /runner/workspaces/{workspaceId}/servers/{serverId}/executions/{executionId}",
  "POST /runner/workspaces/{workspaceId}/servers/{serverId}/executions/{executionId}/cancel",
  "GET /runner/workspaces/{workspaceId}/servers/{serverId}/executions/{executionId}/telemetry",
  "GET /runner/workspaces/{workspaceId}/test-cases",
  "POST /runner/workspaces/{workspaceId}/test-cases",
  "GET /runner/workspaces/{workspaceId}/test-cases/{testCaseId}",
  "PATCH /runner/workspaces/{workspaceId}/test-cases/{testCaseId}",
  "DELETE /runner/workspaces/{workspaceId}/test-cases/{testCaseId}",
  "POST /runner/workspaces/{workspaceId}/test-cases/{testCaseId}/run",
  "GET /runner/workspaces/{workspaceId}/suites",
  "POST /runner/workspaces/{workspaceId}/suites",
  "GET /runner/workspaces/{workspaceId}/suites/{suiteId}",
  "PATCH /runner/workspaces/{workspaceId}/suites/{suiteId}",
  "DELETE /runner/workspaces/{workspaceId}/suites/{suiteId}",
  "POST /runner/workspaces/{workspaceId}/suites/{suiteId}/run",
  "GET /runner/workspaces/{workspaceId}/evaluation-runs",
  "GET /runner/workspaces/{workspaceId}/evaluation-runs/{evaluationRunId}",
  "POST /runner/workspaces/{workspaceId}/evaluation-runs/compare",
  "POST /runner/workspaces/{workspaceId}/evaluation-runs/{evaluationRunId}/export",
  "GET /runner/workspaces/{workspaceId}/evaluation-runs/{evaluationRunId}/exports/{exportId}",
  "GET /runner/workspaces/{workspaceId}/evaluation-runs/{evaluationRunId}/exports/{exportId}/content",
]);
const actualRunnerOperations = new Set(
  [...operations].filter(([, operation]) =>
    operation.tags?.some((tag) => runnerTags.has(tag)),
  ).map(([id]) => id),
);
const missingRunnerOperations = [...expectedRunnerOperations].filter((id) => !actualRunnerOperations.has(id));
const unexpectedRunnerOperations = [...actualRunnerOperations].filter((id) => !expectedRunnerOperations.has(id));
if (missingRunnerOperations.length > 0 || unexpectedRunnerOperations.length > 0) {
  throw new Error(
    `Runner operation inventory drifted. Missing: ${missingRunnerOperations.join(", ") || "none"}. ` +
    `Unexpected: ${unexpectedRunnerOperations.join(", ") || "none"}. Update the TypeSpec owner and this inventory together.`,
  );
}
for (const operationId of expectedRunnerOperations) {
  verifyExactResponse(operationId, "401", "UnauthorizedError");
  verifyExactResponse(operationId, "403", "ForbiddenError");
}

const expectedMcpPassthroughOperations = new Map([
  ["GET /runner/mcp/{resource}/tools", {
    operationId: "RunnerMcpApi_listTools",
    hasRequestBody: false,
    errors: {
      403: "ForbiddenError",
      404: "NotFoundError",
      409: "ConflictError",
      500: "InternalServerError",
      502: "BadGatewayError",
      503: "ServiceUnavailableError",
    },
  }],
  ["POST /runner/mcp/{resource}/tools/call", {
    operationId: "RunnerMcpApi_callTool",
    hasRequestBody: true,
    errors: {
      400: "ValidationError",
      403: "ForbiddenError",
      404: "NotFoundError",
      409: "ConflictError",
      500: "InternalServerError",
      502: "BadGatewayError",
      503: "ServiceUnavailableError",
    },
  }],
  ["POST /runner/mcp/{resource}/resources/read", {
    operationId: "RunnerMcpApi_readResource",
    hasRequestBody: true,
    errors: {
      400: "ValidationError",
      403: "ForbiddenError",
      404: "NotFoundError",
      409: "ConflictError",
      500: "InternalServerError",
      502: "BadGatewayError",
      503: "ServiceUnavailableError",
    },
  }],
]);
const actualMcpPassthroughOperations = new Set(
  [...operations].filter(([, operation]) => operation.tags?.includes("Runner MCP")).map(([id]) => id),
);
const missingMcpPassthroughOperations = [...expectedMcpPassthroughOperations.keys()]
  .filter((id) => !actualMcpPassthroughOperations.has(id));
const unexpectedMcpPassthroughOperations = [...actualMcpPassthroughOperations]
  .filter((id) => !expectedMcpPassthroughOperations.has(id));
if (missingMcpPassthroughOperations.length > 0 || unexpectedMcpPassthroughOperations.length > 0) {
  throw new Error(
    `Opaque MCP passthrough operation inventory drifted. Missing: ${missingMcpPassthroughOperations.join(", ") || "none"}. ` +
    `Unexpected: ${unexpectedMcpPassthroughOperations.join(", ") || "none"}.`,
  );
}
for (const [operationKey, expected] of expectedMcpPassthroughOperations) {
  const operation = operations.get(operationKey);
  if (!operation) throw new Error(`${operationKey} is missing from ${openapiPath}.`);
  if (operation.operationId !== expected.operationId || JSON.stringify(operation.tags) !== '["Runner MCP"]') {
    throw new Error(`${operationKey} must remain ${expected.operationId} under the Runner MCP tag.`);
  }

  const parameters = operation.parameters ?? [];
  const resource = parameters[0];
  if (parameters.length !== 1 || resource?.name !== "resource" || resource.in !== "path" ||
      resource.required !== true || resource.schema?.type !== "string") {
    throw new Error(`${operationKey} must declare only the required string resource path parameter.`);
  }
  if (operation.security !== undefined) {
    throw new Error(`${operationKey} must remain protected by the runner's loopback/origin boundary, not cookie auth.`);
  }

  if (expected.hasRequestBody) {
    if (operation.requestBody?.required !== true) {
      throw new Error(`${operationKey} must require its MCP SDK-owned request body.`);
    }
    verifyExactOpaqueJsonBody(operation.requestBody.content, `${operationKey} request`);
  } else if (operation.requestBody !== undefined) {
    throw new Error(`${operationKey} must not declare a request body.`);
  }

  const expectedStatuses = ["200", ...Object.keys(expected.errors)].sort();
  const actualStatuses = Object.keys(operation.responses ?? {}).sort();
  if (JSON.stringify(actualStatuses) !== JSON.stringify(expectedStatuses)) {
    throw new Error(`${operationKey} response statuses drifted: ${JSON.stringify(actualStatuses)}.`);
  }
  verifyExactOpaqueJsonBody(operation.responses["200"]?.content, `${operationKey} response 200`);
  for (const [status, schemaName] of Object.entries(expected.errors)) {
    verifyExactResponse(operationKey, status, schemaName);
  }
}

const runnerCookieAuthName = "RunnerMcpSessionCookieAuth";
const runnerCookieAuth = openapi.components?.securitySchemes?.[runnerCookieAuthName];
if (runnerCookieAuth?.type !== "apiKey" || runnerCookieAuth.in !== "cookie" || runnerCookieAuth.name !== "qyl-mcp-session") {
  throw new Error(`${runnerCookieAuthName} must be the qyl-mcp-session cookie security scheme.`);
}
const publicRunnerOperations = new Set(["POST /runner/session"]);
for (const operationId of expectedRunnerOperations) {
  const security = operations.get(operationId)?.security;
  if (publicRunnerOperations.has(operationId)) {
    if (security !== undefined && security.length !== 0) {
      throw new Error(`${operationId} must remain an unauthenticated local bootstrap/read surface.`);
    }
    continue;
  }
  if (JSON.stringify(security) !== JSON.stringify([{ [runnerCookieAuthName]: [] }])) {
    throw new Error(`${operationId} must require only ${runnerCookieAuthName}.`);
  }
}

const bootstrapResponse = operations.get("POST /runner/session")?.responses?.["200"];
const setCookie = bootstrapResponse?.headers?.["Set-Cookie"];
if (setCookie?.required !== true || setCookie.schema?.type !== "string" ||
    !setCookie.description?.includes("HttpOnly") || !setCookie.description?.includes("SameSite")) {
  throw new Error("POST /runner/session must declare a required HttpOnly/SameSite Set-Cookie response header.");
}

const capacityLimitedOperations = new Set([
  ...expectedRunnerOperations,
  "GET /api/v1/stream/logs",
]);
for (const operationId of capacityLimitedOperations) {
  verifyExactResponse(operationId, "503", "ServiceUnavailableError");
}

const validationQueries = new Map([
  ["GET /api/v1/traces", ["limit", "cursor"]],
  ["GET /api/v1/logs", ["severityMin", "startTime", "endTime", "limit"]],
  ["GET /api/v1/sessions", ["isActive", "startTime", "endTime", "limit", "cursor"]],
  ["GET /api/v1/sessions/stats", ["startTime", "endTime"]],
  ["GET /api/v1/stream/logs", ["minSeverity"]],
  ["GET /runner/workspaces/{workspaceId}/servers/{serverId}/protocol", ["cursor", "limit"]],
  ["GET /runner/workspaces/{workspaceId}/servers/{serverId}/executions", ["status", "cursor", "limit"]],
  ["GET /runner/workspaces/{workspaceId}/test-cases", ["serverId", "toolName", "cursor", "limit"]],
  ["GET /runner/workspaces/{workspaceId}/suites", ["cursor", "limit"]],
  ["GET /runner/workspaces/{workspaceId}/evaluation-runs", ["status", "cursor", "limit"]],
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
  "GET /runner/resources/{resource}/logs/stream",
  "GET /runner/workspaces/{workspaceId}/servers/{serverId}/protocol/stream",
  "GET /runner/workspaces/{workspaceId}/servers/{serverId}/executions/stream",
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
  `Verified ${expectedRunnerOperations.size} runner route and error inventories, ` +
  `${expectedMcpPassthroughOperations.size} opaque MCP passthrough operations, ` +
  `${expectedRunnerOperations.size - publicRunnerOperations.size} private cookie-auth operations, ` +
  `${capacityLimitedOperations.size} capacity responses, and ` +
  `${validationQueries.size} typed-query validation responses, and ` +
  `${resumableSseOperations.size} resumable SSE headers.`,
);
