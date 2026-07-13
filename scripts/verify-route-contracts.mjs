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

const runnerTags = new Set(["Runner resources", "Runner MCP"]);
const expectedRunnerOperations = new Set([
  "GET /runner/resources",
  "GET /runner/resources/stream",
  "GET /runner/resources/{resource}/logs",
  "GET /runner/resources/{resource}/logs/stream",
  "POST /runner/resources/{resource}/restart",
  "POST /runner/resources/{resource}/stop",
  "GET /runner/mcp/{resource}/tools",
  "POST /runner/mcp/{resource}/tools/call",
  "POST /runner/mcp/{resource}/resources/read",
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
  verifyExactResponse(operationId, "403", "ForbiddenError");
  verifyExactResponse(operationId, "503", "ServiceUnavailableError");
}

const validationQueries = new Map([
  ["GET /api/v1/traces", ["limit"]],
  ["GET /api/v1/logs", ["severityMin", "startTime", "endTime", "limit"]],
  ["GET /api/v1/profiles", ["limit"]],
  ["GET /api/v1/profiles/by-trace/{traceId}", ["limit"]],
  ["GET /api/v1/profiles/by-span/{spanId}", ["limit"]],
  ["GET /api/v1/sessions", ["isActive", "startTime", "endTime", "limit", "cursor"]],
  ["GET /api/v1/sessions/stats", ["startTime", "endTime"]],
  ["GET /api/v1/stream/logs", ["minSeverity"]],
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

console.log(
  `Verified ${expectedRunnerOperations.size} runner security/capacity responses and ` +
  `${validationQueries.size} typed-query validation responses.`,
);
