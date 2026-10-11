// The emitted OpenAPI document and the JSON Schema projected from it, as the
// scripts that write, hash and verify them address it. Reading is left to the
// caller, so importing this module touches no file and the revision emitter can
// keep its own missing-file advice.
import { readFile } from "node:fs/promises";

export const openApiPath = "generated/openapi/qyl.openapi.json";
export const contractSchemaPath = "generated/json-schema/qyl-api-schema.json";

// The Path Item keys that hold an Operation; every other key of a Path Item
// (parameters, servers, summary, ...) is not one.
export const httpMethods = new Set(["delete", "get", "head", "options", "patch", "post", "put", "trace"]);

export async function readOpenApi() {
  return JSON.parse(await readFile(openApiPath, "utf8"));
}
