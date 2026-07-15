import { readFile } from "node:fs/promises";
import Ajv2020 from "ajv/dist/2020.js";

const schemaPath = "generated/json-schema/qyl-api-schema.json";
const schema = JSON.parse(await readFile(schemaPath, "utf8"));
const defs = schema.$defs ?? {};
const ajv = new Ajv2020({ allErrors: true, strict: true, validateFormats: false });
ajv.addKeyword({ keyword: "x-csharp-struct", schemaType: "boolean" });
ajv.addKeyword({ keyword: "x-csharp-type", schemaType: "string" });

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

function assertAnyOfReferences(definition, expected) {
  const actual = (defs[definition]?.anyOf ?? []).map((variant) => variant.$ref);
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${definition} anyOf variants drifted: ${JSON.stringify(actual)}.`);
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

assertAnyOfReferences("OTel.Metrics.MetricNumberValue", [
  "#/$defs/OTel.Metrics.MetricIntegerValue",
  "#/$defs/OTel.Metrics.MetricDoubleValue",
]);
assertAnyOfReferences("OTel.Metrics.MetricPoint", [
  "#/$defs/OTel.Metrics.GaugeMetricPoint",
  "#/$defs/OTel.Metrics.SumMetricPoint",
  "#/$defs/OTel.Metrics.HistogramMetricPoint",
  "#/$defs/OTel.Metrics.ExponentialHistogramMetricPoint",
  "#/$defs/OTel.Metrics.SummaryMetricPoint",
]);

const validateMetricNumber = validatorFor("OTel.Metrics.MetricNumberValue");
assertValid(validateMetricNumber, { as_int: "42" }, "integer metric value");
assertValid(validateMetricNumber, { as_double: 2.5 }, "double metric value");
assertInvalid(validateMetricNumber, { as_int: "42", as_double: 2.5 }, "ambiguous metric value");
assertInvalid(validateMetricNumber, { as_int: 42 }, "numeric JSON encoding for a 64-bit metric integer");
assertInvalid(validateMetricNumber, {}, "missing metric value");

const metricCommon = {
  name: "gen_ai.client.token.usage",
  unit: "{token}",
  start_time_unix_nano: "1000",
  time_unix_nano: "2000",
  flags: 0,
  resource: { "service.name": "checkout" },
  instrumentation_scope: { name: "OpenTelemetry.Instrumentation.GenAI", version: "1.0.0" },
  attributes: [
    { key: "gen_ai.provider.name", value: "openai" },
    { key: "gen_ai.request.model", value: "gpt-4.1" },
    { key: "gen_ai.token.type", value: "input" },
  ],
};
const validateMetricPoint = validatorFor("OTel.Metrics.MetricPoint");
const metricFixtures = [
  { ...metricCommon, type: "gauge", value: { as_double: 1.5 } },
  {
    ...metricCommon,
    type: "sum",
    value: { as_int: "3" },
    aggregation_temporality: 2,
    is_monotonic: true,
  },
  {
    ...metricCommon,
    type: "histogram",
    count: "2",
    sum: 180,
    bucket_counts: ["0", "1", "1"],
    explicit_bounds: [64, 256],
    min: 50,
    max: 130,
    aggregation_temporality: 1,
    exemplars: [{ time_unix_nano: "1500", value: { as_int: "130" }, trace_id: "0af7651916cd43dd8448eb211c80319c", span_id: "b7ad6b7169203331" }],
  },
  {
    ...metricCommon,
    type: "exponential_histogram",
    count: "2",
    sum: 3.5,
    scale: 3,
    zero_count: "0",
    zero_threshold: 0,
    positive: { offset: 0, bucket_counts: ["1", "1"] },
    negative: { offset: 0, bucket_counts: [] },
    aggregation_temporality: 2,
  },
  {
    ...metricCommon,
    type: "summary",
    count: "2",
    sum: 3.5,
    quantile_values: [{ quantile: 0.5, value: 1.5 }, { quantile: 1, value: 2 }],
  },
];
for (const fixture of metricFixtures) assertValid(validateMetricPoint, fixture, `OTLP ${fixture.type} metric point`);
assertInvalid(validateMetricPoint, { ...metricCommon, type: "gauge" }, "gauge without a numeric value");
assertInvalid(validateMetricPoint, { ...metricFixtures[0], type: "counter" }, "unknown metric type");
assertInvalid(validateMetricPoint, { ...metricFixtures[1], aggregation_temporality: 0 }, "unspecified aggregation temporality");
assertInvalid(validateMetricPoint, { ...metricFixtures[0], time_unix_nano: "0" }, "zero metric timestamp");
assertInvalid(validateMetricPoint, { ...metricFixtures[0], time_unix_nano: 2000 }, "numeric JSON encoding for a metric timestamp");
assertInvalid(validateMetricPoint, {
  ...metricFixtures[4],
  quantile_values: [{ quantile: 0.5, value: -1 }],
}, "negative summary quantile value");

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

for (const removedDefinition of [
  "Cost.ProviderCostSourceKind",
  "Cost.ProviderCostSourceStatus",
  "Cost.ProviderCostAttribution",
  "Cost.ProviderCostSource",
  "Cost.ModelCatalogSourceKind",
  "Cost.GenAiEtlCalculationStatus",
]) {
  if (removedDefinition in defs) throw new Error(`${removedDefinition} must not survive the direct cutover.`);
}

const expectedBillingStatuses = ["unconfigured", "pending", "current", "stale", "sync_failed"];
const billingStatuses = defs["Cost.ProviderBillingSourceStatus"]?.enum ?? [];
if (JSON.stringify(billingStatuses) !== JSON.stringify(expectedBillingStatuses)) {
  throw new Error(`Cost.ProviderBillingSourceStatus drifted: ${JSON.stringify(billingStatuses)}.`);
}
const expectedBillingAttributions = ["provider_model_period", "provider_period", "unavailable"];
const billingAttributions = defs["Cost.ProviderBillingAttribution"]?.enum ?? [];
if (JSON.stringify(billingAttributions) !== JSON.stringify(expectedBillingAttributions)) {
  throw new Error(`Cost.ProviderBillingAttribution drifted: ${JSON.stringify(billingAttributions)}.`);
}
const billingSource = defs["Cost.ProviderBillingSource"];
if (!billingSource || "kind" in billingSource.properties) {
  throw new Error("Cost.ProviderBillingSource must expose aggregate billing without a provisional kind.");
}

const expectedMatchKinds = [
  "exact_model_id",
  "exact_canonical_slug",
];
const matchKinds = defs["Cost.ModelCatalogMatchKind"]?.enum ?? [];
if (JSON.stringify(matchKinds) !== JSON.stringify(expectedMatchKinds)) {
  throw new Error(`Cost.ModelCatalogMatchKind drifted: ${JSON.stringify(matchKinds)}.`);
}
const catalogProvenance = {
  source_id: "provider-model-catalog",
  source_endpoint: "https://provider.example/api/models",
  snapshot_id: "sha256:catalog-snapshot",
  price_model_id: "provider/model-version",
  observed_model_id: "provider/model-version",
  observed_model_identity_basis: "response_model",
  model_match_kind: "exact_model_id",
  retrieved_at: "2026-07-14T11:55:00Z",
  price_semantics: "minimum_available_rate",
};
const replacementEvidence = {
  source_order: 2,
  condition_usage_dimension: "input_tokens",
  exclusive_minimum_quantity: 1000,
  observed_per_call_quantity: 1500,
};
const catalogEstimate = {
  status: "calculated",
  estimated_catalog_token_cost_usd: 0.0047,
  estimated_catalog_token_cost_per_call_usd: 0.00235,
  provenance: catalogProvenance,
  components: [
    {
      component: "cache_read",
      usage_dimension: "cache_read_input_tokens",
      unit: "token",
      source_billing_mode: "per_token",
      billing_mode: "per_unit",
      rate_relation: "replaces_inclusive_base_rate",
      replaces_usage_dimension: "input_tokens",
      quantity: 1500,
      unit_price_usd: 0.000001,
      estimated_cost_usd: 0.0015,
    },
    {
      component: "cache_write_override",
      usage_dimension: "cache_write_input_tokens",
      unit: "token",
      source_billing_mode: "per_token",
      billing_mode: "per_unit",
      rate_relation: "replaces_published_rate",
      replaces_usage_dimension: "cache_write_input_tokens",
      conditional_evidence: replacementEvidence,
      quantity: 500,
      unit_price_usd: 0.000001,
      estimated_cost_usd: 0.0005,
    },
    {
      component: "completion",
      usage_dimension: "output_tokens",
      unit: "token",
      source_billing_mode: "per_token",
      billing_mode: "per_unit",
      rate_relation: "base_rate",
      quantity: 500,
      unit_price_usd: 0.000002,
      estimated_cost_usd: 0.001,
    },
    {
      component: "request",
      usage_dimension: "call_count",
      unit: "request",
      source_billing_mode: "per_request",
      billing_mode: "per_request",
      rate_relation: "base_rate",
      quantity: 2,
      unit_price_usd: 0.00085,
      estimated_cost_usd: 0.0017,
    },
  ],
  exclusions: [
    {
      component: "cache_read",
      usage_dimension: "cache_read_input_tokens",
      unit: "token",
      source_billing_mode: "per_token",
      billing_mode: "per_unit",
      rate_evidence: { rate_relation: "base_rate" },
      reason: "usage_not_observed",
      unit_price_usd: 0.0000001,
    },
    {
      component: "prompt_override",
      usage_dimension: "input_tokens",
      unit: "token",
      source_billing_mode: "per_token",
      billing_mode: "per_unit",
      rate_evidence: {
        rate_relation: "replaces_published_rate",
        replaces_usage_dimension: "input_tokens",
        conditional_evidence: { ...replacementEvidence, source_order: 1 },
      },
      reason: "superseded_by_later_override",
      unit_price_usd: 0.00000075,
    },
    {
      component: "audio",
      usage_dimension: "audio_duration",
      unit: "second",
      source_billing_mode: "per_audio_second",
      rate_evidence: { rate_relation: "base_rate" },
      reason: "outside_token_estimate_scope",
      unit_price_usd: 0.001,
    },
    {
      component: "input_audio_cache",
      usage_dimension: "input_audio_cache",
      unit: "audio",
      source_billing_mode: "per_audio_unit",
      rate_evidence: {
        rate_relation: "replaces_published_rate",
        replaces_usage_dimension: "input_audio_cache",
        conditional_evidence: {
          ...replacementEvidence,
          source_order: 3,
          condition_usage_dimension: "input_audio_cache",
        },
      },
      reason: "conditional_adjustment_not_applied",
      unit_price_usd: 0.002,
    },
    {
      component: "audio",
      usage_dimension: "audio_duration",
      unit: "second",
      source_billing_mode: "per_audio_second",
      rate_evidence: { rate_relation: "base_rate" },
      reason: "unsupported_usage_dimension",
      unit_price_usd: 0.0001,
    },
  ],
};
const validateCatalogEstimate = validatorFor("Cost.GenAiEtlCatalogTokenCostEstimate");
const unavailableCatalogEstimate = { status: "model_not_found" };
const unsupportedBillingEstimate = {
  status: "unsupported_pricing",
  exclusions: [{
    component: "audio",
    usage_dimension: "audio_duration",
    unit: "second",
    source_billing_mode: "per_audio_second",
    rate_evidence: { rate_relation: "base_rate" },
    reason: "unsupported_billing_mode",
    unit_price_usd: 0.0001,
  }],
};
assertValid(validateCatalogEstimate, catalogEstimate, "calculated catalog estimate with exact provenance");
assertValid(validateCatalogEstimate, unavailableCatalogEstimate, "catalog estimate failure status");
assertValid(validateCatalogEstimate, unsupportedBillingEstimate, "unsupported source billing-mode evidence");
assertInvalid(validateCatalogEstimate, {}, "catalog estimate without status");
assertInvalid(
  validateCatalogEstimate,
  { status: "calculated" },
  "calculated estimate without required costs, provenance, and components",
);
assertInvalid(
  validateCatalogEstimate,
  { ...unavailableCatalogEstimate, estimated_catalog_token_cost_usd: 1 },
  "failure estimate carrying a calculated cost",
);
assertInvalid(
  validateCatalogEstimate,
  { ...catalogEstimate, components: [] },
  "catalog estimate with an empty components array",
);
assertInvalid(
  validateCatalogEstimate,
  { ...catalogEstimate, components: [{ ...catalogEstimate.components[0], quantity: -1 }] },
  "catalog estimate with a negative component quantity",
);
assertValid(
  validateCatalogEstimate,
  catalogEstimate,
  "ordered conditional override with target and evidence",
);
const replacementWithoutEvidence = structuredClone(catalogEstimate);
delete replacementWithoutEvidence.components[1].conditional_evidence;
assertInvalid(
  validateCatalogEstimate,
  replacementWithoutEvidence,
  "ordered conditional override without evidence",
);
const supersededWithoutEvidence = structuredClone(catalogEstimate);
delete supersededWithoutEvidence.exclusions[1].rate_evidence.conditional_evidence;
assertInvalid(
  validateCatalogEstimate,
  supersededWithoutEvidence,
  "superseded override without ordered conditional evidence",
);
const nonConditionalOverride = structuredClone(catalogEstimate.exclusions[2]);
nonConditionalOverride.rate_evidence = {
  rate_relation: "replaces_published_rate",
  replaces_usage_dimension: "audio_duration",
  conditional_evidence: {
    ...replacementEvidence,
    condition_usage_dimension: "audio_duration",
  },
};
assertValid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [nonConditionalOverride] },
  "nonconditional unknown meter with complete source-override evidence",
);
const nonConditionalOverrideWithoutEvidence = structuredClone(nonConditionalOverride);
delete nonConditionalOverrideWithoutEvidence.rate_evidence.conditional_evidence;
assertInvalid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [nonConditionalOverrideWithoutEvidence] },
  "nonconditional source override without paired evidence",
);
const nonConditionalOverrideWithoutTarget = structuredClone(nonConditionalOverride);
delete nonConditionalOverrideWithoutTarget.rate_evidence.replaces_usage_dimension;
assertInvalid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [nonConditionalOverrideWithoutTarget] },
  "nonconditional source override without paired target",
);
const baseRateWithOverrideEvidence = structuredClone(catalogEstimate.exclusions[0]);
baseRateWithOverrideEvidence.rate_evidence = {
  rate_relation: "base_rate",
  replaces_usage_dimension: "input_tokens",
  conditional_evidence: replacementEvidence,
};
assertInvalid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [baseRateWithOverrideEvidence] },
  "base-rate exclusion carrying source-override evidence",
);
const inclusiveReplacementExclusion = structuredClone(catalogEstimate.exclusions[0]);
inclusiveReplacementExclusion.rate_evidence = {
  rate_relation: "replaces_inclusive_base_rate",
  replaces_usage_dimension: "input_tokens",
};
assertValid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [inclusiveReplacementExclusion] },
  "ordinary inclusive replacement exclusion without conditional evidence",
);
const inclusiveReplacementWithoutTarget = structuredClone(inclusiveReplacementExclusion);
delete inclusiveReplacementWithoutTarget.rate_evidence.replaces_usage_dimension;
assertInvalid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [inclusiveReplacementWithoutTarget] },
  "inclusive replacement exclusion without its target",
);
const conditionalReasonWithBaseRate = structuredClone(catalogEstimate.exclusions[1]);
conditionalReasonWithBaseRate.rate_evidence = { rate_relation: "base_rate" };
assertInvalid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [conditionalReasonWithBaseRate] },
  "conditional exclusion reason without a published override",
);
const zeroSourceOrder = structuredClone(catalogEstimate);
zeroSourceOrder.components[1].conditional_evidence.source_order = 0;
assertInvalid(validateCatalogEstimate, zeroSourceOrder, "source override with reserved source order zero");
const supportedExclusionWithoutBillingMode = structuredClone(catalogEstimate.exclusions[0]);
delete supportedExclusionWithoutBillingMode.billing_mode;
assertInvalid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [supportedExclusionWithoutBillingMode] },
  "supported exclusion without normalized billing mode",
);
assertValid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [catalogEstimate.exclusions[2]] },
  "outside-scope source meter without a supported billing-mode normalization",
);
assertValid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [catalogEstimate.exclusions[3]] },
  "conditional unknown source meter without a supported billing-mode normalization",
);
assertValid(
  validateCatalogEstimate,
  { status: "unsupported_pricing", exclusions: [catalogEstimate.exclusions[4]] },
  "unsupported usage dimension without a supported billing-mode normalization",
);
assertInvalid(
  validateCatalogEstimate,
  { ...catalogEstimate, exclusions: [] },
  "catalog estimate with an empty exclusions array",
);

const catalogEstimateSchema = defs["Cost.GenAiEtlCatalogTokenCostEstimate"];
const expectedEstimateRefs = [
  "GenAiEtlCatalogTokenCalculatedEstimate",
  "GenAiEtlCatalogTokenSourceUnavailableEstimate",
  "GenAiEtlCatalogTokenStaleSourceEstimate",
  "GenAiEtlCatalogTokenMissingModelIdentityEstimate",
  "GenAiEtlCatalogTokenModelNotFoundEstimate",
  "GenAiEtlCatalogTokenAmbiguousModelEstimate",
  "GenAiEtlCatalogTokenIncompleteUsageEstimate",
  "GenAiEtlCatalogTokenConditionalPricingUnresolvableEstimate",
  "GenAiEtlCatalogTokenUnsupportedPricingEstimate",
].map((name) => `#/$defs/Cost.${name}`);
const actualEstimateRefs = (catalogEstimateSchema?.oneOf ?? []).map((variant) => variant.$ref);
const calculatedEstimateSchema = defs["Cost.GenAiEtlCatalogTokenCalculatedEstimate"];
const sourceOrderSchema = defs["Cost.ModelCatalogSourceOrder"];
const rateEvidenceSchema = defs["Cost.ModelCatalogExclusionRateEvidence"];
const expectedRateEvidenceRefs = [
  "ModelCatalogBaseRateEvidence",
  "ModelCatalogAdditiveSurchargeEvidence",
  "ModelCatalogInclusiveReplacementEvidence",
  "ModelCatalogPublishedReplacementEvidence",
].map((name) => `#/$defs/Cost.${name}`);
const actualRateEvidenceRefs = (rateEvidenceSchema?.oneOf ?? []).map((variant) => variant.$ref);
const inclusiveEvidenceSchema = defs["Cost.ModelCatalogInclusiveReplacementEvidence"];
const publishedEvidenceSchema = defs["Cost.ModelCatalogPublishedReplacementEvidence"];
const supportedExclusionSchema = defs["Cost.ModelCatalogSupportedBillingExclusionBase"];
const optionalBillingExclusionSchema = defs["Cost.ModelCatalogOptionallyNormalizedBillingExclusionBase"];
const conditionalExclusionSchema = defs["Cost.ModelCatalogConditionalExclusionBase"];
const unsupportedBillingSchema = defs["Cost.ModelCatalogUnsupportedBillingExclusion"];
const failureVariantNames = expectedEstimateRefs.slice(1).map((reference) => reference.split("Cost.")[1]);
const calculatedRequired = [
  "status",
  "estimated_catalog_token_cost_usd",
  "estimated_catalog_token_cost_per_call_usd",
  "provenance",
  "components",
];
if (JSON.stringify(actualEstimateRefs) !== JSON.stringify(expectedEstimateRefs) ||
    calculatedRequired.some((property) => !calculatedEstimateSchema?.required?.includes(property)) ||
    calculatedEstimateSchema.properties?.components?.minItems !== 1 ||
    calculatedEstimateSchema.properties?.exclusions?.minItems !== 1 ||
    JSON.stringify(actualRateEvidenceRefs) !== JSON.stringify(expectedRateEvidenceRefs) ||
    !inclusiveEvidenceSchema?.required?.includes("replaces_usage_dimension") ||
    inclusiveEvidenceSchema.required.includes("conditional_evidence") ||
    !publishedEvidenceSchema?.required?.includes("replaces_usage_dimension") ||
    !publishedEvidenceSchema.required.includes("conditional_evidence") ||
    sourceOrderSchema?.minimum !== 1 ||
    !supportedExclusionSchema?.required?.includes("billing_mode") ||
    optionalBillingExclusionSchema?.required?.includes("billing_mode") ||
    conditionalExclusionSchema?.required?.includes("billing_mode") ||
    unsupportedBillingSchema?.required?.includes("billing_mode") ||
    failureVariantNames.some((name) => !("unevaluatedProperties" in (defs[`Cost.${name}`] ?? {})))) {
  throw new Error("Catalog estimate must be a complete calculated variant or a fail-closed status variant.");
}
for (const field of [
  "estimated_catalog_token_cost_usd",
  "estimated_catalog_token_cost_per_call_usd",
  "provenance",
  "components",
]) {
  if (field in unavailableCatalogEstimate) {
    throw new Error(`Non-calculated catalog estimate fixture must omit ${field}.`);
  }
}

const clusterFixture = {
  cluster_id: "cluster-1",
  workflow_key: "workflow-1",
  service_name: "orders",
  provider: "provider",
  model: "model-version",
  output_contract: "record",
  task_family: "structured_extraction",
  call_count: 2,
  input_tokens: 3000,
  output_tokens: 500,
  cache_read_input_tokens: 1500,
  cache_creation_input_tokens: 500,
  reasoning_output_tokens: 0,
  error_count: 0,
  error_rate: 0,
  average_latency_ms: 25,
  p95_latency_ms: 40,
  catalog_token_estimate: catalogEstimate,
  candidate_status: "hypothesis_only",
  candidate_path: "smaller_generative_model",
  validation_metrics: ["field_exact_match", "schema_validity"],
  residual_path: "frontier_model",
  evidence_signals: ["provider_model", "token_usage", "catalog_token_estimate"],
  missing_evidence: [],
  promotion_gates: [],
};
const evidenceSignals = defs["Cost.GenAiEtlEvidenceSignal"]?.enum ?? [];
if (!evidenceSignals.includes("catalog_token_estimate") || evidenceSignals.includes("provider_cost")) {
  throw new Error("Cluster evidence must name the current-catalog estimate and never aggregate provider billing.");
}
const validateAuditCluster = validatorFor("Cost.GenAiEtlAuditCluster");
assertValid(validateAuditCluster, clusterFixture, "ETL audit cluster with required catalog estimate");
const clusterWithoutCandidateStatus = structuredClone(clusterFixture);
delete clusterWithoutCandidateStatus.candidate_status;
assertInvalid(validateAuditCluster, clusterWithoutCandidateStatus, "ETL audit cluster without candidate evidence status");
const clusterWithoutCatalogEstimate = structuredClone(clusterFixture);
delete clusterWithoutCatalogEstimate.catalog_token_estimate;
assertInvalid(validateAuditCluster, clusterWithoutCatalogEstimate, "ETL audit cluster without catalog estimate");
const removedClusterProperties = [
  "observed_cost_usd",
  "cost_per_call_usd",
  "cost_attribution",
  "spend_share",
];
if (!auditCluster.required.includes("catalog_token_estimate") ||
    auditCluster.properties?.catalog_token_estimate?.allOf?.[0]?.$ref !==
      "#/$defs/Cost.GenAiEtlCatalogTokenCostEstimate" ||
    removedClusterProperties.some((property) => property in auditCluster.properties)) {
  throw new Error("ETL audit clusters must expose required catalog status and no request-attributed billing.");
}

const auditSummary = defs["Cost.GenAiEtlAuditSummary"];
const catalogSummaryProperties = [
  "estimated_catalog_token_cost_usd",
  "catalog_token_priced_call_coverage",
  "estimated_token_economic_concentration",
  "candidate_etl_estimated_token_spend_share",
];
const removedSummaryProperties = [
  "attributed_cost_usd",
  "priced_call_coverage",
  "economic_concentration",
  "candidate_etl_spend_share",
];
if (!auditSummary?.required?.includes("catalog_token_priced_call_coverage") ||
    catalogSummaryProperties.some((property) => !(property in (auditSummary.properties ?? {}))) ||
    removedSummaryProperties.some((property) => property in (auditSummary.properties ?? {}))) {
  throw new Error("ETL audit summary must expose only executable catalog economics.");
}
const summaryFixture = {
  total_calls: 2,
  total_input_tokens: 3000,
  total_output_tokens: 500,
  estimated_catalog_token_cost_usd: 0.0047,
  catalog_token_priced_call_coverage: 1,
  estimated_token_economic_concentration: 0.8,
  candidate_etl_estimated_token_spend_share: 0.6,
};
const validateAuditSummary = validatorFor("Cost.GenAiEtlAuditSummary");
assertValid(validateAuditSummary, summaryFixture, "audit summary with live catalog economics");
const summaryWithoutCatalogCoverage = structuredClone(summaryFixture);
delete summaryWithoutCatalogCoverage.catalog_token_priced_call_coverage;
assertInvalid(validateAuditSummary, summaryWithoutCatalogCoverage, "audit summary without catalog coverage");

const auditReport = defs["Cost.GenAiEtlAuditReport"];
if (!auditReport?.required?.includes("billing_sources") ||
    !auditReport.required.includes("catalog_sources") ||
    "cost_sources" in auditReport.properties ||
    auditReport.properties?.billing_sources?.items?.$ref !== "#/$defs/Cost.ProviderBillingSource" ||
    auditReport.properties?.catalog_sources?.items?.$ref !== "#/$defs/Cost.ModelCatalogSource") {
  throw new Error("ETL audit report must separate aggregate billing_sources from live catalog_sources.");
}
const reportFixture = {
  generated_at: "2026-07-14T12:00:00Z",
  period_start: "2026-06-01T00:00:00Z",
  period_end: "2026-07-01T00:00:00Z",
  summary: summaryFixture,
  billing_sources: [{
    provider: "provider",
    status: "current",
    source_endpoint: "https://provider.example/api/billing",
    attribution: "provider_period",
    reported_cost_usd: 1.25,
  }],
  catalog_sources: [{
    source_id: "provider-model-catalog",
    priority: 0,
    status: "current",
    price_semantics: "minimum_available_rate",
    source_endpoint: "https://provider.example/api/models",
    last_verified_at: "2026-07-14T11:59:00Z",
    retrieved_at: "2026-07-14T11:55:00Z",
    active_snapshot_id: "sha256:catalog-snapshot",
    model_count: 42,
  }],
  clusters: [clusterFixture],
};
const validateAuditReport = validatorFor("Cost.GenAiEtlAuditReport");
assertValid(validateAuditReport, reportFixture, "ETL audit report with billing and catalog sources");
for (const requiredSourceProperty of ["billing_sources", "catalog_sources"]) {
  const incompleteReport = structuredClone(reportFixture);
  delete incompleteReport[requiredSourceProperty];
  assertInvalid(validateAuditReport, incompleteReport, `ETL audit report without ${requiredSourceProperty}`);
}
const catalogSource = defs["Cost.ModelCatalogSource"];
if ("kind" in catalogSource.properties ||
    !("source_id" in catalogSource.properties) ||
    !catalogSource.required.includes("priority") ||
    !("price_semantics" in catalogSource.properties) ||
    !("last_verified_at" in catalogSource.properties) ||
    !("active_snapshot_id" in catalogSource.properties) ||
    !("model_count" in catalogSource.properties)) {
  throw new Error("Catalog sources must expose the active snapshot without a provisional kind.");
}

const expectedFrontierCostBases = ["scenario", "catalog_token_estimate", "unavailable"];
const frontierCostBases = defs["Cost.GenAiEtlFrontierCostBasis"]?.enum ?? [];
const evaluation = defs["Cost.GenAiEtlClusterEvaluation"];
const expectedEvaluationRefs = [
  "GenAiEtlScenarioClusterEvaluation",
  "GenAiEtlCatalogTokenClusterEvaluation",
  "GenAiEtlUnavailableClusterEvaluation",
].map((name) => `#/$defs/Cost.${name}`);
const actualEvaluationRefs = (evaluation?.oneOf ?? []).map((variant) => variant.$ref);
const catalogEvaluationSchema = defs["Cost.GenAiEtlCatalogTokenClusterEvaluation"];
const calculatedEvaluationSchema = defs["Cost.GenAiEtlCalculatedClusterEvaluationBase"];
if (JSON.stringify(frontierCostBases) !== JSON.stringify(expectedFrontierCostBases) ||
    JSON.stringify(actualEvaluationRefs) !== JSON.stringify(expectedEvaluationRefs) ||
    !catalogEvaluationSchema?.required?.includes("catalog_provenance") ||
    !["frontier_cost_per_call_usd", "current_period_cost_usd", "gross_replaceable_value_usd", "net_replaceable_value_usd"]
      .every((property) => calculatedEvaluationSchema?.required?.includes(property))) {
  throw new Error(`Cost.GenAiEtlFrontierCostBasis drifted: ${JSON.stringify(frontierCostBases)}.`);
}
const validateFrontierCostBasis = validatorFor("Cost.GenAiEtlFrontierCostBasis");
for (const basis of expectedFrontierCostBases) {
  assertValid(validateFrontierCostBasis, basis, `frontier cost basis ${basis}`);
}
for (const forbiddenBasis of ["provider_attributed_actual", "provider_model_period", "live_catalog_estimate"]) {
  assertInvalid(validateFrontierCostBasis, forbiddenBasis, `non-executable frontier basis ${forbiddenBasis}`);
}
const scenarioEvaluation = {
  cluster_id: "cluster-1",
  status: "calculated",
  call_count: 2,
  coverage: 1,
  served_call_count: 2,
  residual_call_count: 0,
  frontier_cost_basis: "scenario",
  frontier_cost_per_call_usd: 0.003,
  alternative_cost_per_call_usd: 0.001,
  current_period_cost_usd: 0.006,
  gross_replaceable_value_usd: 0.004,
  period_maintenance_cost_usd: 0,
  period_error_cost_usd: 0,
  net_replaceable_value_usd: 0.004,
};
const catalogEvaluation = {
  ...scenarioEvaluation,
  frontier_cost_basis: "catalog_token_estimate",
  frontier_cost_per_call_usd: catalogEstimate.estimated_catalog_token_cost_per_call_usd,
  current_period_cost_usd: catalogEstimate.estimated_catalog_token_cost_usd,
  gross_replaceable_value_usd: 0.0027,
  net_replaceable_value_usd: 0.0027,
  catalog_provenance: catalogProvenance,
};
const unavailableEvaluation = {
  cluster_id: "cluster-1",
  status: "missing_frontier_cost",
  call_count: 2,
  coverage: 1,
  served_call_count: 2,
  residual_call_count: 0,
  frontier_cost_basis: "unavailable",
  alternative_cost_per_call_usd: 0.001,
  period_maintenance_cost_usd: 0,
  period_error_cost_usd: 0,
};
const validateEvaluation = validatorFor("Cost.GenAiEtlClusterEvaluation");
assertValid(validateEvaluation, scenarioEvaluation, "scenario-based calculated evaluation");
assertValid(validateEvaluation, catalogEvaluation, "catalog-based calculated evaluation with provenance");
assertValid(validateEvaluation, unavailableEvaluation, "fail-closed unavailable evaluation");
const incompleteCalculatedEvaluation = structuredClone(scenarioEvaluation);
delete incompleteCalculatedEvaluation.net_replaceable_value_usd;
assertInvalid(validateEvaluation, incompleteCalculatedEvaluation, "calculated evaluation without net value");
assertInvalid(
  validateEvaluation,
  { ...scenarioEvaluation, catalog_provenance: catalogProvenance },
  "scenario evaluation carrying catalog provenance",
);
const catalogEvaluationWithoutProvenance = structuredClone(catalogEvaluation);
delete catalogEvaluationWithoutProvenance.catalog_provenance;
assertInvalid(validateEvaluation, catalogEvaluationWithoutProvenance, "catalog evaluation without provenance");
assertInvalid(
  validateEvaluation,
  { ...unavailableEvaluation, frontier_cost_per_call_usd: 0.003 },
  "unavailable evaluation carrying calculated economics",
);

console.log(
  `Verified ${attributeFixtures.length} recursive AttributeValue fixtures, ` +
  `${contentFixtures.length} MCP content variants, exclusive MCP resource variants, ` +
  "compound ETL validation metrics, and the aggregate-billing/live-catalog cutover.",
);
