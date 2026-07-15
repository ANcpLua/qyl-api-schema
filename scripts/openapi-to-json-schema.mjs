import { mkdir, readFile, writeFile } from "node:fs/promises";

const input = "generated/openapi/qyl.openapi.json";
const output = "generated/json-schema/qyl-api-schema.json";

const openapi = JSON.parse(await readFile(input, "utf8"));
const schemas = openapi.components?.schemas;
if (!schemas || typeof schemas !== "object") {
  throw new Error(`${input} has no components.schemas`);
}

const httpMethods = new Set(["delete", "get", "head", "options", "patch", "post", "put", "trace"]);
const compareNames = (left, right) => left === right ? 0 : left < right ? -1 : 1;

function rewriteReferences(value) {
  if (Array.isArray(value)) return value.map(rewriteReferences);
  if (value === null || typeof value !== "object") return value;

  const rewritten = Object.fromEntries(Object.entries(value).map(([key, child]) => [
    key,
    key === "$ref" && typeof child === "string"
      ? child.replace("#/components/schemas/", "#/$defs/")
      : rewriteReferences(child),
  ]));

  // OpenAPI represents @encode(string) numeric scalars as strings while retaining
  // their numeric minimum/maximum keywords. Those keywords are invalid on JSON
  // Schema strings and are ignored by validators. Preserve canonical decimal wire
  // syntax instead; the format plus generated language types enforce the exact CLR
  // range at deserialization.
  if (rewritten.type === "string" && (rewritten.format === "uint64" || rewritten.format === "int64")) {
    const nonZero = rewritten.format === "uint64" && Number(rewritten.minimum ?? 0) >= 1;
    delete rewritten.minimum;
    delete rewritten.maximum;
    delete rewritten.exclusiveMinimum;
    delete rewritten.exclusiveMaximum;
    rewritten.pattern = rewritten.format === "uint64"
      ? nonZero ? "^[1-9][0-9]*$" : "^(0|[1-9][0-9]*)$"
      : "^(0|-?[1-9][0-9]*)$";
    rewritten.maxLength = 20;
  }

  return rewritten;
}

function singleContentSchema(content, context) {
  const entries = Object.entries(content ?? {}).filter(([, media]) =>
    media && typeof media === "object" && media.schema && typeof media.schema === "object"
  );
  if (entries.length > 1) {
    throw new Error(`${context} has multiple body media types; an operation definition name would be ambiguous.`);
  }
  return entries[0]?.[1].schema;
}

function operationDefinitions() {
  const definitions = [];
  const operationIds = new Set();

  // Operation IDs are the published, language-neutral identity of each route body.
  // Keep these names stable so consumers can compile exact request and response
  // validators without reconstructing inline OpenAPI schemas.
  for (const [path, pathItem] of Object.entries(openapi.paths ?? {}).sort(([left], [right]) =>
    compareNames(left, right)
  )) {
    for (const [method, operation] of Object.entries(pathItem ?? {}).sort(([left], [right]) =>
      compareNames(left, right)
    )) {
      if (!httpMethods.has(method) || !operation || typeof operation !== "object") continue;

      const operationId = operation.operationId;
      const requestSchema = singleContentSchema(
        operation.requestBody?.content,
        `${method.toUpperCase()} ${path} request`,
      );
      const responseSchemas = Object.entries(operation.responses ?? {})
        .map(([status, response]) => [
          status,
          singleContentSchema(response?.content, `${method.toUpperCase()} ${path} response ${status}`),
        ])
        .filter(([, schema]) => schema !== undefined);

      if (requestSchema === undefined && responseSchemas.length === 0) continue;
      if (typeof operationId !== "string" || operationId.length === 0) {
        throw new Error(`${method.toUpperCase()} ${path} has body schemas but no stable operationId.`);
      }
      if (operationIds.has(operationId)) {
        throw new Error(`OpenAPI operationId '${operationId}' is not unique.`);
      }
      operationIds.add(operationId);

      if (requestSchema !== undefined) {
        definitions.push([
          `Operations.${operationId}.Request`,
          rewriteReferences(requestSchema),
        ]);
      }
      for (const [status, responseSchema] of responseSchemas.sort(([left], [right]) =>
        compareNames(left, right)
      )) {
        definitions.push([
          `Operations.${operationId}.Response.${status}`,
          rewriteReferences(responseSchema),
        ]);
      }
    }
  }

  return Object.fromEntries(definitions.sort(([left], [right]) => compareNames(left, right)));
}

const operations = operationDefinitions();
for (const name of Object.keys(operations)) {
  if (name in schemas) {
    throw new Error(`Operation body definition '${name}' collides with an OpenAPI component schema.`);
  }
}

const bundle = {
  $schema: "https://json-schema.org/draft/2020-12/schema",
  $id: "https://qyl.dev/schema/qyl-api-schema.json",
  $defs: Object.fromEntries(
    [
      ...Object.entries(schemas).map(([name, schema]) => [name, rewriteReferences(schema)]),
      ...Object.entries(operations),
    ],
  ),
};

await mkdir("generated/json-schema", { recursive: true });
await writeFile(output, `${JSON.stringify(bundle, null, 2)}\n`);
