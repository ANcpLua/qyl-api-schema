import { mkdir, readFile, writeFile } from "node:fs/promises";

const input = "generated/openapi/qyl.openapi.json";
const output = "generated/json-schema/qyl-api-schema.json";

const openapi = JSON.parse(await readFile(input, "utf8"));
const schemas = openapi.components?.schemas;
if (!schemas || typeof schemas !== "object") {
  throw new Error(`${input} has no components.schemas`);
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

const bundle = {
  $schema: "https://json-schema.org/draft/2020-12/schema",
  $id: "https://qyl.dev/schema/qyl-api-schema.json",
  $defs: Object.fromEntries(
    Object.entries(schemas).map(([name, schema]) => [name, rewriteReferences(schema)]),
  ),
};

await mkdir("generated/json-schema", { recursive: true });
await writeFile(output, `${JSON.stringify(bundle, null, 2)}\n`);
