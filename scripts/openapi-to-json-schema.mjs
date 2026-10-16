import { mkdir, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import { contractSchemaPath, httpMethods, openApiPath, readOpenApi } from "./lib/openapi.mjs";

const openapi = await readOpenApi();
const schemas = openapi.components?.schemas;
if (!schemas || typeof schemas !== "object") {
  throw new Error(`${openApiPath} has no components.schemas`);
}

const compareNames = (left, right) => left === right ? 0 : left < right ? -1 : 1;

// JSON Schema numeric bounds do not apply to decimal strings. Encode the exact
// 64-bit boundary in the portable pattern so JS and CLR consumers agree.
function decimalAtMost(maximum, includeZero) {
  const digits = maximum.toString();
  const alternatives = includeZero ? ["0"] : [];
  if (digits.length > 1) alternatives.push(`[1-9][0-9]{0,${digits.length - 2}}`);
  for (let index = 0; index < digits.length; index += 1) {
    const lower = index === 0 ? 1 : 0;
    const upper = Number(digits[index]) - 1;
    if (upper < lower) continue;
    const digit = lower === upper ? String(lower) : `[${lower}-${upper}]`;
    const remaining = digits.length - index - 1;
    alternatives.push(digits.slice(0, index) + digit + (remaining === 0 ? "" : `[0-9]{${remaining}}`));
  }
  alternatives.push(digits);
  return `(?:${alternatives.join("|")})`;
}

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
  // syntax and the signed/unsigned range in every generated runtime validator.
  if (rewritten.type === "string" && (rewritten.format === "uint64" || rewritten.format === "int64")) {
    const nonZero = rewritten.format === "uint64" && Number(rewritten.minimum ?? 0) >= 1;
    delete rewritten.minimum;
    delete rewritten.maximum;
    delete rewritten.exclusiveMinimum;
    delete rewritten.exclusiveMaximum;
    rewritten.pattern = rewritten.format === "uint64"
      ? `^${decimalAtMost((1n << 64n) - 1n, !nonZero)}$`
      : `^(?:${decimalAtMost((1n << 63n) - 1n, true)}|-${decimalAtMost(1n << 63n, false)})$`;
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

await mkdir(dirname(contractSchemaPath), { recursive: true });
await writeFile(contractSchemaPath, `${JSON.stringify(bundle, null, 2)}\n`);
