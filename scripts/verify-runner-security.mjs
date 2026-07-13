import { readFile } from "node:fs/promises";

const openapiPath = "generated/openapi/qyl.openapi.json";
const openapi = JSON.parse(await readFile(openapiPath, "utf8"));
const runnerTags = new Set(["Runner resources", "Runner MCP"]);
const httpMethods = new Set(["delete", "get", "head", "options", "patch", "post", "put", "trace"]);
const expectedOperations = new Set([
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

const operations = Object.entries(openapi.paths ?? {}).flatMap(([path, pathItem]) =>
  Object.entries(pathItem)
    .filter(([method]) => httpMethods.has(method))
    .map(([method, operation]) => ({
      id: `${method.toUpperCase()} ${path}`,
      operation,
    })),
).filter(({ operation }) => operation.tags?.some((tag) => runnerTags.has(tag)));

const actualOperations = new Set(operations.map(({ id }) => id));
const missing = [...expectedOperations].filter((operation) => !actualOperations.has(operation));
const unexpected = [...actualOperations].filter((operation) => !expectedOperations.has(operation));
if (missing.length > 0 || unexpected.length > 0) {
  throw new Error(
    `Runner operation inventory drifted. Missing: ${missing.join(", ") || "none"}. ` +
    `Unexpected: ${unexpected.join(", ") || "none"}. Update the TypeSpec owner and this inventory together.`,
  );
}

const problemMediaType = "application/problem+json";
const forbiddenSchema = "#/components/schemas/Common.Errors.ForbiddenError";
for (const { id, operation } of operations) {
  const response = operation.responses?.["403"];
  const content = response?.content ?? {};
  if (Object.keys(content).length !== 1 || content[problemMediaType]?.schema?.$ref !== forbiddenSchema) {
    throw new Error(
      `${id} can be rejected by the runner origin gate but does not declare a 403 ${problemMediaType} ${forbiddenSchema} response.`,
    );
  }
}

console.log(`Verified ${operations.length} runner operations declare the generated ForbiddenError response.`);
