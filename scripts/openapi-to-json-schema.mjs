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

  return Object.fromEntries(Object.entries(value).map(([key, child]) => [
    key,
    key === "$ref" && typeof child === "string"
      ? child.replace("#/components/schemas/", "#/$defs/")
      : rewriteReferences(child),
  ]));
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
