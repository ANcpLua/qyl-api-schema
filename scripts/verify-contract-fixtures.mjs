import { readFile } from "node:fs/promises";
import Ajv2020 from "ajv/dist/2020.js";

const schemaPath = "generated/json-schema/qyl-api-schema.json";
const schema = JSON.parse(await readFile(schemaPath, "utf8"));
const defs = schema.$defs ?? {};
const ajv = new Ajv2020({ allErrors: true, strict: true, validateFormats: false });

function validatorFor(definition) {
  return ajv.compile({
    $schema: schema.$schema,
    $defs: defs,
    $ref: `#/$defs/${definition}`,
  });
}

function assertValid(validate, fixture, label) {
  if (!validate(fixture)) {
    throw new Error(`${label} must validate: ${ajv.errorsText(validate.errors, { separator: "\n" })}`);
  }
}

function assertInvalid(validate, fixture, label) {
  if (validate(fixture)) throw new Error(`${label} must be rejected.`);
}

function assertReferences(definition, expected) {
  const actual = (defs[definition]?.oneOf ?? []).map((variant) => variant.$ref);
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${definition} oneOf variants drifted: ${JSON.stringify(actual)}.`);
  }
}

const bytes = { type: "bytes", base64: "/wCA/g==" };
if (Buffer.from(bytes.base64, "base64").toString("base64") !== bytes.base64) {
  throw new Error("The byte fixture is not canonical base64.");
}

const validateAttribute = validatorFor("Common.AttributeValue");
const attributeFixtures = [
  ["tagged bytes", bytes],
  ["recursive kvlist", { http: { method: "GET", retry: true }, payload: bytes, count: 3 }],
  ["nested arrays", [["outer", 1], [bytes, [false, 2.5]]]],
  ["heterogeneous array", ["text", true, 42, 2.5, bytes, { nested: [false, "tail"] }]],
];
for (const [label, fixture] of attributeFixtures) assertValid(validateAttribute, fixture, label);

const bytesSchema = defs["Common.AttributeBytesValue"];
if (bytesSchema?.properties?.type?.enum?.[0] !== "bytes" ||
    bytesSchema?.properties?.base64?.contentEncoding !== "base64") {
  throw new Error("Common.AttributeBytesValue must retain the tagged base64 wire shape.");
}

const contentRefs = [
  "RunnerMcpTextContent",
  "RunnerMcpImageContent",
  "RunnerMcpAudioContent",
  "RunnerMcpEmbeddedResourceContent",
  "RunnerMcpResourceLinkContent",
  "RunnerMcpToolUseContent",
  "RunnerMcpToolResultContent",
].map((name) => `#/$defs/Runner.Mcp.${name}`);
assertReferences("Runner.Mcp.RunnerMcpContent", contentRefs);
assertReferences("Runner.Mcp.RunnerMcpResourceContent", [
  "#/$defs/Runner.Mcp.RunnerMcpTextResourceContent",
  "#/$defs/Runner.Mcp.RunnerMcpBlobResourceContent",
]);

const validateContent = validatorFor("Runner.Mcp.RunnerMcpContent");
const textResource = { uri: "ui://app/index.html", text: "<html></html>" };
const contentFixtures = [
  { type: "text", text: "ok" },
  { type: "image", data: "AAE=", mimeType: "image/png" },
  { type: "audio", data: "AgM=", mimeType: "audio/wav" },
  { type: "resource", resource: textResource },
  { type: "resource_link", uri: "ui://app/index.html", name: "dashboard", size: 17 },
  { type: "tool_use", id: "call-1", name: "inspect", input: { trace_id: "abc" } },
  { type: "tool_result", toolUseId: "call-1", content: [{ type: "text", text: "ok" }], isError: false },
];
for (const fixture of contentFixtures) assertValid(validateContent, fixture, `MCP ${fixture.type} content`);
assertInvalid(validateContent, { type: "text" }, "MCP optional-field bag without required variant data");

const validateResource = validatorFor("Runner.Mcp.RunnerMcpResourceContent");
assertValid(validateResource, textResource, "MCP text resource");
assertValid(validateResource, { uri: "file:///tmp/blob", blob: "AAE=" }, "MCP blob resource");
assertInvalid(validateResource, { uri: "file:///tmp/empty" }, "MCP resource without text or blob");
assertInvalid(
  validateResource,
  { uri: "file:///tmp/ambiguous", text: "not exclusive", blob: "AAE=" },
  "MCP resource with both text and blob",
);

const auditCluster = defs["Cost.GenAiEtlAuditCluster"];
if (!auditCluster?.required?.includes("validation_metrics") ||
    auditCluster.required.includes("validation_metric") ||
    auditCluster.properties?.validation_metrics?.type !== "array" ||
    auditCluster.properties.validation_metrics.minItems !== 1 ||
    auditCluster.properties.validation_metrics.items?.$ref !==
      "#/$defs/Cost.GenAiEtlValidationMetric" ||
    "validation_metric" in (auditCluster.properties ?? {})) {
  throw new Error(
    "Cost.GenAiEtlAuditCluster must require a non-empty validation_metrics array and expose no scalar validation_metric.",
  );
}
const validationMetrics = defs["Cost.GenAiEtlValidationMetric"]?.enum ?? [];
for (const metric of ["calibration_error", "span_precision", "span_recall"]) {
  if (!validationMetrics.includes(metric)) {
    throw new Error(`Cost.GenAiEtlValidationMetric must include ${metric}.`);
  }
}

console.log(
  `Verified ${attributeFixtures.length} recursive AttributeValue fixtures, ` +
  `${contentFixtures.length} MCP content variants, exclusive MCP resource variants, ` +
  "and the compound ETL validation-metrics contract.",
);
