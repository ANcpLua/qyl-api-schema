import { rm } from "node:fs/promises";

const generatedOutputs = [
  "generated/contracts",
  "generated/json-schema",
  "generated/openapi",
  "generated/ts-runtime",
  "generated/ts-types",
];

await Promise.all(generatedOutputs.map((path) => rm(path, { force: true, recursive: true })));
