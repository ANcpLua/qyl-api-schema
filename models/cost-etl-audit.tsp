// =============================================================================
// GenAI cost provenance and ETL-audit contracts
// =============================================================================

import "@typespec/openapi";
import "../common/types.tsp";

using TypeSpec.OpenAPI;
using Qyl.Api.Contracts.Common;

namespace Qyl.Api.Contracts.Cost;

@doc("Current synchronization state for a provider-owned billing source.")
enum ProviderBillingSourceStatus {
  @doc("The source has no configured provider credential or cloud identity.")
  unconfigured: "unconfigured",

  @doc("A provider credential or cloud identity is configured, but no fetch has completed yet.")
  pending: "pending",

  @doc("The most recent provider fetch completed inside its freshness window.")
  current: "current",

  @doc("The last successful provider response is older than its freshness window.")
  stale: "stale",

  @doc("The latest provider billing fetch failed; no raw credential or upstream response is exposed.")
  syncFailed: "sync_failed",
}

@doc("Granularity at which official provider-billed cost can be attributed to telemetry.")
enum ProviderBillingAttribution {
  @doc("The provider API identified the model and period represented by the value.")
  providerModelPeriod: "provider_model_period",

  @doc("The provider API identified only a provider/account period, not a model or request.")
  providerPeriod: "provider_period",

  @doc("No defensible attribution is available.")
  unavailable: "unavailable",
}

@doc("Provenance for billed cost data fetched directly from a provider-owned API.")
model ProviderBillingSource {
  @doc("Canonical GenAI provider or cloud billing system name.")
  provider: string;

  @doc("Current billing synchronization state.")
  status: ProviderBillingSourceStatus;

  @doc("Official provider-owned API endpoint used for the fetch.")
  @encodedName("application/json", "source_endpoint")
  sourceEndpoint: UrlString;

  @doc("Attribution granularity supported by this source response.")
  attribution: ProviderBillingAttribution;

  @doc("UTC time of the latest fetch attempt.")
  @encodedName("application/json", "last_attempt_at")
  lastAttemptAt?: utcDateTime;

  @doc("UTC time of the latest successful fetch.")
  @encodedName("application/json", "last_success_at")
  lastSuccessAt?: utcDateTime;

  @doc("Start of the provider billing period.")
  @encodedName("application/json", "period_start")
  periodStart?: utcDateTime;

  @doc("End of the provider billing period.")
  @encodedName("application/json", "period_end")
  periodEnd?: utcDateTime;

  @doc("ISO 4217 currency code returned by the provider.")
  @encodedName("application/json", "currency_code")
  currencyCode?: string;

  @doc("Cost returned by the provider for this period, converted from provider-declared USD units without rate inference.")
  @encodedName("application/json", "reported_cost_usd")
  reportedCostUsd?: CostUsd;

  @doc("Model identifier returned by the provider when the source supports it.")
  @encodedName("application/json", "model")
  modelName?: string;

  @doc("Stable, non-sensitive failure category for the last attempt.")
  @encodedName("application/json", "failure_category")
  failureCategory?: string;
}

@doc("Current synchronization state for a configured live model catalog.")
enum ModelCatalogSourceStatus {
  @doc("The source is registered, but its required credential or activation is not configured.")
  unconfigured: "unconfigured",

  @doc("The source is configured, but no fetch has completed yet.")
  pending: "pending",

  @doc("The most recent successful catalog fetch is inside its freshness window.")
  current: "current",

  @doc("The last successful catalog response is older than its freshness window.")
  stale: "stale",

  @doc("The latest catalog fetch failed; no raw credential or upstream response is exposed.")
  syncFailed: "sync_failed",
}

@doc("Synchronization metadata for one configurable live model catalog source.")
model ModelCatalogSource {
  @doc("Unique stable identifier of the configured catalog source.")
  @encodedName("application/json", "source_id")
  sourceId: string;

  @doc("Configured source priority used for deterministic selection when multiple current catalogs match. Zero is highest priority; lower values win.")
  priority: Count;

  status: ModelCatalogSourceStatus;

  @doc("Rate-selection semantics published by this source's active snapshot.")
  @encodedName("application/json", "price_semantics")
  priceSemantics?: ModelCatalogPriceSemantics;

  @doc("Configured API endpoint used to fetch the live model catalog.")
  @encodedName("application/json", "source_endpoint")
  sourceEndpoint: UrlString;

  @doc("UTC time of the latest fetch attempt.")
  @encodedName("application/json", "last_attempt_at")
  lastAttemptAt?: utcDateTime;

  @doc("UTC time when the source was last verified successfully, including a verification that retained unchanged content.")
  @encodedName("application/json", "last_verified_at")
  lastVerifiedAt?: utcDateTime;

  @doc("UTC time when the content of the currently retained catalog snapshot was retrieved.")
  @encodedName("application/json", "retrieved_at")
  retrievedAt?: utcDateTime;

  @doc("Content-addressed identifier of the catalog snapshot currently used for estimates.")
  @encodedName("application/json", "active_snapshot_id")
  activeSnapshotId?: string;

  @doc("Number of model records in the active catalog snapshot.")
  @encodedName("application/json", "model_count")
  modelCount?: Count;

  @doc("Stable, non-sensitive failure category for the last attempt.")
  @encodedName("application/json", "failure_category")
  failureCategory?: string;
}

@doc("How a live catalog rate was selected when estimating cluster cost.")
enum ModelCatalogPriceSemantics {
  @doc("The catalog source publishes its lowest available model rate rather than an official bill or a uniquely routed endpoint price. A conditional rate applies only when its conditions are proven.")
  minimumAvailableRate: "minimum_available_rate",

  @doc("The source's published rate was applied without selecting a lower conditional rate.")
  publishedRate: "published_rate",
}

@doc("Deterministic exact match used to resolve an observed model identity to a catalog record. Fuzzy, prefix, suffix, date, and alias matching are not permitted.")
enum ModelCatalogMatchKind {
  @doc("The observed model value exactly matched the catalog model identifier.")
  exactModelId: "exact_model_id",

  @doc("The observed model value exactly matched the catalog canonical slug.")
  exactCanonicalSlug: "exact_canonical_slug",
}

@doc("Telemetry attribute used as the observed model identity for an exact catalog match.")
enum ModelCatalogObservedIdentityBasis {
  @doc("The observed identity came from the provider response model.")
  responseModel: "response_model",

  @doc("No response model was available, so the observed identity came from the request model.")
  requestModelFallback: "request_model_fallback",
}

@doc("Provenance for the live catalog rates used to estimate one cluster.")
model ModelCatalogPriceProvenance {
  @doc("Unique stable identifier of the configured catalog source.")
  @encodedName("application/json", "source_id")
  sourceId: string;

  @doc("Configured API endpoint from which the catalog was retrieved.")
  @encodedName("application/json", "source_endpoint")
  sourceEndpoint: UrlString;

  @doc("Content-addressed identifier of the exact catalog snapshot used for this estimate.")
  @encodedName("application/json", "snapshot_id")
  snapshotId: string;

  @doc("Exact model identifier selected from the source catalog.")
  @encodedName("application/json", "price_model_id")
  priceModelId: string;

  @doc("Exact observed telemetry value compared with the selected catalog record.")
  @encodedName("application/json", "observed_model_id")
  observedModelId: string;

  @encodedName("application/json", "observed_model_identity_basis")
  observedModelIdentityBasis: ModelCatalogObservedIdentityBasis;

  @encodedName("application/json", "model_match_kind")
  modelMatchKind: ModelCatalogMatchKind;

  @doc("UTC time when the current catalog snapshot used for this counterfactual estimate was retrieved. For historical audit periods, this is not evidence of the price that applied historically.")
  @encodedName("application/json", "retrieved_at")
  retrievedAt: utcDateTime;

  @encodedName("application/json", "price_semantics")
  priceSemantics: ModelCatalogPriceSemantics;
}

@doc("How a catalog rate charges its measured quantity.")
enum ModelCatalogBillingMode {
  @doc("The rate is multiplied by a measured unit quantity.")
  perUnit: "per_unit",

  @doc("The rate is charged once for each observed request.")
  perRequest: "per_request",
}

@doc("How a selected catalog rate relates to the source's published base rate for the same component.")
enum ModelCatalogRateRelation {
  @doc("The selected rate is the published base rate for this component.")
  baseRate: "base_rate",

  @doc("The selected rate is an additive surcharge alongside the published base rate.")
  additiveSurcharge: "additive_surcharge",

  @doc("A source subtype rate replaces the inclusive published base rate for its target usage dimension. Conditional evidence is present only when an ordered source override altered that subtype rate.")
  replacesInclusiveBaseRate: "replaces_inclusive_base_rate",

  @doc("A proven ordered source override replaces the previously published rate for its target usage dimension.")
  replacesPublishedRate: "replaces_published_rate",
}

@doc("One-based position of a conditional override in its source response.")
@minValue(1)
scalar ModelCatalogSourceOrder extends int64;

@doc("Ordered evidence proving whether a conditional catalog override applied to an observed request quantity.")
model ModelCatalogConditionalRateEvidence {
  @doc("One-based position of this override in the source response; later matching overrides win. Tier zero is reserved for the published base rate and is not a source override.")
  @encodedName("application/json", "source_order")
  sourceOrder: ModelCatalogSourceOrder;

  @doc("Observed per-call usage dimension evaluated by the source condition.")
  @encodedName("application/json", "condition_usage_dimension")
  conditionUsageDimension: string;

  @doc("Exclusive minimum quantity declared by the source condition.")
  @encodedName("application/json", "exclusive_minimum_quantity")
  @minValue(0)
  exclusiveMinimumQuantity: float64;

  @doc("Observed per-call quantity compared with the exclusive minimum.")
  @encodedName("application/json", "observed_per_call_quantity")
  @minValue(0)
  observedPerCallQuantity: float64;
}

@doc("Fields shared by every included token or request pricing component.")
model ModelCatalogTokenEstimateComponentBase {
  @doc("Source-defined pricing component, such as prompt, completion, request, cache read, cache write, or internal reasoning.")
  component: string;

  @doc("Qyl-observed usage dimension to which this rate was applied, such as input_tokens or output_tokens.")
  @encodedName("application/json", "usage_dimension")
  usageDimension: string;

  @doc("Source-declared unit represented by the rate.")
  unit: string;

  @doc("Source-specific billing mode retained from the catalog or deterministically derived from the provider-defined meter.")
  @encodedName("application/json", "source_billing_mode")
  sourceBillingMode: string;

  @encodedName("application/json", "billing_mode")
  billingMode: ModelCatalogBillingMode;

  @doc("Measured quantity to which the catalog unit price was applied.")
  @minValue(0)
  quantity: float64;

  @doc("Catalog price in USD per source-defined unit.")
  @encodedName("application/json", "unit_price_usd")
  unitPriceUsd: CostUsd;

  @doc("Estimated USD contribution of this component for the reported cluster period.")
  @encodedName("application/json", "estimated_cost_usd")
  estimatedCostUsd: CostUsd;
}

model ModelCatalogTokenBaseRateComponent extends ModelCatalogTokenEstimateComponentBase {
  @encodedName("application/json", "rate_relation")
  rateRelation: "base_rate";
}

model ModelCatalogTokenAdditiveSurchargeComponent extends ModelCatalogTokenEstimateComponentBase {
  @encodedName("application/json", "rate_relation")
  rateRelation: "additive_surcharge";
}

model ModelCatalogTokenInclusiveReplacementRateComponent extends ModelCatalogTokenEstimateComponentBase {
  @encodedName("application/json", "rate_relation")
  rateRelation: "replaces_inclusive_base_rate";

  @doc("Inclusive base usage dimension replaced by this subtype rate.")
  @encodedName("application/json", "replaces_usage_dimension")
  replacesUsageDimension: string;

  @doc("Ordered override evidence when the source conditionally altered this subtype rate.")
  @encodedName("application/json", "conditional_evidence")
  conditionalEvidence?: ModelCatalogConditionalRateEvidence;
}

model ModelCatalogTokenConditionalOverrideRateComponent extends ModelCatalogTokenEstimateComponentBase {
  @encodedName("application/json", "rate_relation")
  rateRelation: "replaces_published_rate";

  @doc("Published usage dimension whose prior base, surcharge, or subtype rate was replaced.")
  @encodedName("application/json", "replaces_usage_dimension")
  replacesUsageDimension: string;

  @encodedName("application/json", "conditional_evidence")
  conditionalEvidence: ModelCatalogConditionalRateEvidence;
}

@doc("One evidenced token or request component contributing to a current-catalog estimate. The rate_relation literal selects the required evidence shape.")
@oneOf
union ModelCatalogTokenEstimateComponent {
  baseRate: ModelCatalogTokenBaseRateComponent,
  additiveSurcharge: ModelCatalogTokenAdditiveSurchargeComponent,
  inclusiveReplacementRate: ModelCatalogTokenInclusiveReplacementRateComponent,
  conditionalOverrideRate: ModelCatalogTokenConditionalOverrideRateComponent,
}

@doc("Why a catalog meter or conditional adjustment was not included in a token-and-request estimate.")
enum ModelCatalogTokenExclusionReason {
  @doc("The optional usage subtype was not observed; inclusive base input or output tokens remain priced.")
  usageNotObserved: "usage_not_observed",

  @doc("A conditional adjustment was not applied because its activation condition was not proven.")
  conditionalAdjustmentNotApplied: "conditional_adjustment_not_applied",

  @doc("The adjustment matched, but a later matching source override replaced it for the same meter.")
  supersededByLaterOverride: "superseded_by_later_override",

  @doc("The meter is outside the token-and-request estimate boundary and telemetry did not prove that it applied.")
  outsideTokenEstimateScope: "outside_token_estimate_scope",

  @doc("Telemetry proved the meter applied, but qyl does not support its usage dimension.")
  unsupportedUsageDimension: "unsupported_usage_dimension",

  @doc("Telemetry proved the meter applied, but qyl does not support its billing mode.")
  unsupportedBillingMode: "unsupported_billing_mode",
}

model ModelCatalogBaseRateEvidence {
  @encodedName("application/json", "rate_relation")
  rateRelation: "base_rate";
}

model ModelCatalogAdditiveSurchargeEvidence {
  @encodedName("application/json", "rate_relation")
  rateRelation: "additive_surcharge";
}

model ModelCatalogInclusiveReplacementEvidence {
  @encodedName("application/json", "rate_relation")
  rateRelation: "replaces_inclusive_base_rate";

  @doc("Inclusive base usage dimension replaced by this subtype rate.")
  @encodedName("application/json", "replaces_usage_dimension")
  replacesUsageDimension: string;

  @doc("Ordered evidence when a source override altered the selected subtype rate.")
  @encodedName("application/json", "conditional_evidence")
  conditionalEvidence?: ModelCatalogConditionalRateEvidence;
}

model ModelCatalogPublishedReplacementEvidence {
  @encodedName("application/json", "rate_relation")
  rateRelation: "replaces_published_rate";

  @doc("Published usage dimension whose prior base, surcharge, or subtype rate was replaced.")
  @encodedName("application/json", "replaces_usage_dimension")
  replacesUsageDimension: string;

  @encodedName("application/json", "conditional_evidence")
  conditionalEvidence: ModelCatalogConditionalRateEvidence;
}

@doc("Relation-specific evidence for a catalog rate omitted from a token-and-request estimate. The rate_relation literal selects the required target and ordered evidence shape.")
@oneOf
union ModelCatalogExclusionRateEvidence {
  baseRate: ModelCatalogBaseRateEvidence,
  additiveSurcharge: ModelCatalogAdditiveSurchargeEvidence,
  inclusiveReplacement: ModelCatalogInclusiveReplacementEvidence,
  publishedReplacement: ModelCatalogPublishedReplacementEvidence,
}

@doc("Fields shared by every catalog meter or conditional adjustment excluded from a token-and-request estimate.")
model ModelCatalogTokenEstimateExclusionBase {
  component: string;

  @encodedName("application/json", "usage_dimension")
  usageDimension: string;

  unit: string;

  @doc("Source-specific billing mode retained from the catalog or deterministically derived from the provider-defined meter, including unsupported modes.")
  @encodedName("application/json", "source_billing_mode")
  sourceBillingMode: string;

  @doc("Relation, replacement target, and ordered override evidence for the omitted rate.")
  @encodedName("application/json", "rate_evidence")
  rateEvidence: ModelCatalogExclusionRateEvidence;

  @doc("Catalog rate omitted from the estimate, when the source supplied one.")
  @encodedName("application/json", "unit_price_usd")
  unitPriceUsd?: CostUsd;
}

model ModelCatalogSupportedBillingExclusionBase extends ModelCatalogTokenEstimateExclusionBase {
  @encodedName("application/json", "billing_mode")
  billingMode: ModelCatalogBillingMode;
}

model ModelCatalogOptionallyNormalizedBillingExclusionBase extends ModelCatalogTokenEstimateExclusionBase {
  @doc("Normalized billing mode when qyl recognizes the source meter; absent when the source meter has no supported normalization.")
  @encodedName("application/json", "billing_mode")
  billingMode?: ModelCatalogBillingMode;
}

model ModelCatalogUsageNotObservedExclusion extends ModelCatalogSupportedBillingExclusionBase {
  reason: "usage_not_observed";
}

model ModelCatalogOutsideTokenScopeExclusion extends ModelCatalogOptionallyNormalizedBillingExclusionBase {
  reason: "outside_token_estimate_scope";
}

model ModelCatalogUnsupportedUsageExclusion extends ModelCatalogOptionallyNormalizedBillingExclusionBase {
  reason: "unsupported_usage_dimension";
}

model ModelCatalogUnsupportedBillingExclusion extends ModelCatalogTokenEstimateExclusionBase {
  @doc("Normalized billing mode when the source mode has a partial known mapping; absent when no supported normalization exists.")
  @encodedName("application/json", "billing_mode")
  billingMode?: ModelCatalogBillingMode;

  reason: "unsupported_billing_mode";
}

model ModelCatalogConditionalExclusionBase {
  component: string;

  @encodedName("application/json", "usage_dimension")
  usageDimension: string;

  unit: string;

  @doc("Source-specific billing mode retained from the catalog or deterministically derived from the provider-defined meter.")
  @encodedName("application/json", "source_billing_mode")
  sourceBillingMode: string;

  @doc("Normalized billing mode when qyl recognizes the conditional source meter; absent when the source meter has no supported normalization.")
  @encodedName("application/json", "billing_mode")
  billingMode?: ModelCatalogBillingMode;

  @doc("The ordered source override that was not applied or was superseded.")
  @encodedName("application/json", "rate_evidence")
  rateEvidence: ModelCatalogPublishedReplacementEvidence;

  @doc("Catalog rate omitted from the estimate, when the source supplied one.")
  @encodedName("application/json", "unit_price_usd")
  unitPriceUsd?: CostUsd;
}

model ModelCatalogConditionalAdjustmentNotAppliedExclusion extends ModelCatalogConditionalExclusionBase {
  reason: "conditional_adjustment_not_applied";
}

model ModelCatalogSupersededOverrideExclusion extends ModelCatalogConditionalExclusionBase {
  reason: "superseded_by_later_override";
}

@doc("Auditable catalog meter or conditional adjustment excluded from a token-and-request estimate. The reason literal selects the required evidence shape.")
@oneOf
union ModelCatalogTokenEstimateExclusion {
  usageNotObserved: ModelCatalogUsageNotObservedExclusion,
  conditionalAdjustmentNotApplied: ModelCatalogConditionalAdjustmentNotAppliedExclusion,
  supersededByLaterOverride: ModelCatalogSupersededOverrideExclusion,
  outsideTokenEstimateScope: ModelCatalogOutsideTokenScopeExclusion,
  unsupportedUsageDimension: ModelCatalogUnsupportedUsageExclusion,
  unsupportedBillingMode: ModelCatalogUnsupportedBillingExclusion,
}

@doc("Calculated all-or-nothing current-catalog token and request estimate for a complete workflow cluster.")
model GenAiEtlCatalogTokenCalculatedEstimate {
  status: "calculated";

  @doc("Estimated token and request cost for the reported cluster period using the current catalog snapshot; this is counterfactual for historical periods and is not an official billed total.")
  @encodedName("application/json", "estimated_catalog_token_cost_usd")
  estimatedCatalogTokenCostUsd: CostUsd;

  @doc("Estimated token and request cost per observed cluster call; this is not an official billed total.")
  @encodedName("application/json", "estimated_catalog_token_cost_per_call_usd")
  estimatedCatalogTokenCostPerCallUsd: CostUsd;

  @doc("Exact catalog snapshot and model-match evidence.")
  provenance: ModelCatalogPriceProvenance;

  @doc("Included token or request usage and rate contributions. Ordered source overrides carry conditional evidence; ordinary inclusive subtype replacements do not require it.")
  @minItems(1)
  components: ModelCatalogTokenEstimateComponent[];

  @doc("Meters or conditional adjustments explicitly omitted from this calculated estimate.")
  @minItems(1)
  exclusions?: ModelCatalogTokenEstimateExclusion[];
}

model GenAiEtlCatalogTokenEstimateFailureBase {
  @doc("Available meter or conditional evidence explaining why the cluster estimate failed closed.")
  @minItems(1)
  exclusions?: ModelCatalogTokenEstimateExclusion[];
}

model GenAiEtlCatalogTokenSourceUnavailableEstimate extends GenAiEtlCatalogTokenEstimateFailureBase {
  status: "source_unavailable";
}

model GenAiEtlCatalogTokenStaleSourceEstimate extends GenAiEtlCatalogTokenEstimateFailureBase {
  status: "stale_source";
}

model GenAiEtlCatalogTokenMissingModelIdentityEstimate extends GenAiEtlCatalogTokenEstimateFailureBase {
  status: "missing_model_identity";
}

model GenAiEtlCatalogTokenModelNotFoundEstimate extends GenAiEtlCatalogTokenEstimateFailureBase {
  status: "model_not_found";
}

model GenAiEtlCatalogTokenAmbiguousModelEstimate extends GenAiEtlCatalogTokenEstimateFailureBase {
  status: "ambiguous_model";
}

model GenAiEtlCatalogTokenIncompleteUsageEstimate extends GenAiEtlCatalogTokenEstimateFailureBase {
  status: "incomplete_usage";
}

model GenAiEtlCatalogTokenConditionalPricingUnresolvableEstimate extends GenAiEtlCatalogTokenEstimateFailureBase {
  status: "conditional_pricing_unresolvable";
}

model GenAiEtlCatalogTokenUnsupportedPricingEstimate extends GenAiEtlCatalogTokenEstimateFailureBase {
  status: "unsupported_pricing";
}

@doc("All-or-nothing current-catalog token and request estimate. The status literal selects the complete calculated or fail-closed response shape.")
@oneOf
union GenAiEtlCatalogTokenCostEstimate {
  calculated: GenAiEtlCatalogTokenCalculatedEstimate,
  sourceUnavailable: GenAiEtlCatalogTokenSourceUnavailableEstimate,
  staleSource: GenAiEtlCatalogTokenStaleSourceEstimate,
  missingModelIdentity: GenAiEtlCatalogTokenMissingModelIdentityEstimate,
  modelNotFound: GenAiEtlCatalogTokenModelNotFoundEstimate,
  ambiguousModel: GenAiEtlCatalogTokenAmbiguousModelEstimate,
  incompleteUsage: GenAiEtlCatalogTokenIncompleteUsageEstimate,
  conditionalPricingUnresolvable: GenAiEtlCatalogTokenConditionalPricingUnresolvableEstimate,
  unsupportedPricing: GenAiEtlCatalogTokenUnsupportedPricingEstimate,
}

@doc("Task family inferred for a repeated GenAI workflow cluster.")
enum GenAiEtlTaskFamily {
  openReasoningGeneration: "open_reasoning_generation",
  classification: "classification",
  sequenceLabeling: "sequence_labeling",
  structuredExtraction: "structured_extraction",
  retrievalEntityResolution: "retrieval_entity_resolution",
  similarityClustering: "similarity_clustering",
  normalizationTransformation: "normalization_transformation",
  numericAnalytical: "numeric_analytical",
  `unknown`: "unknown",
}

@doc("Machine-readable output contract inferred for a workflow cluster.")
enum GenAiEtlOutputContract {
  prose: "prose",
  label: "label",
  spanList: "span_list",
  record: "record",
  vector: "vector",
  catalogReference: "catalog_reference",
  number: "number",
  boolean: "boolean",
  `unknown`: "unknown",
}

@doc("Lowest-risk implementation class suggested by currently available evidence.")
enum GenAiEtlCandidatePath {
  exactCache: "exact_cache",
  deterministicCode: "deterministic_code",
  boundedRetrieval: "bounded_retrieval",
  smallClassifierExtractor: "small_classifier_extractor",
  smallerGenerativeModel: "smaller_generative_model",
  frontierModel: "frontier_model",
  insufficientEvidence: "insufficient_evidence",
}

@doc("Evidence status of the proposed replacement path.")
enum GenAiEtlCandidateStatus {
  @doc("The path is a heuristic hypothesis that still requires the declared validation metrics and promotion gates.")
  hypothesisOnly: "hypothesis_only",

  @doc("Available evidence is insufficient to propose a replacement path.")
  insufficientEvidence: "insufficient_evidence",
}

@doc("Task-specific metrics that can falsify a proposed replacement.")
enum GenAiEtlValidationMetric {
  accuracy: "accuracy",
  macroF1: "macro_f1",
  calibrationError: "calibration_error",
  spanPrecision: "span_precision",
  spanRecall: "span_recall",
  spanF1: "span_f1",
  fieldExactMatch: "field_exact_match",
  schemaValidity: "schema_validity",
  matchAccuracy: "match_accuracy",
  recallAtK: "recall_at_k",
  meanReciprocalRank: "mean_reciprocal_rank",
  exactMatch: "exact_match",
  numericTolerance: "numeric_tolerance",
  humanPreference: "human_preference",
  taskSuccess: "task_success",
  unavailable: "unavailable",
}

@doc("Fallback used for requests outside a promoted replacement's safe coverage.")
enum GenAiEtlResidualPath {
  frontierModel: "frontier_model",
  humanReview: "human_review",
  retry: "retry",
  degradedResponse: "degraded_response",
  none: "none",
  undetermined: "undetermined",
}

@doc("Observable evidence needed to promote an inferred replacement safely.")
enum GenAiEtlEvidenceSignal {
  workflowIdentity: "workflow_identity",
  outputContract: "output_contract",
  providerModel: "provider_model",
  tokenUsage: "token_usage",
  @doc("A complete current-catalog token-and-request estimate with exact model and snapshot provenance.")
  catalogTokenEstimate: "catalog_token_estimate",
  recurringSchema: "recurring_schema",
  boundedReference: "bounded_reference",
  taskMetric: "task_metric",
  acceptedOutputReplay: "accepted_output_replay",
  downstreamFate: "downstream_fate",
  calibratedConfidence: "calibrated_confidence",
  shadowComparison: "shadow_comparison",
  fallbackPolicy: "fallback_policy",
}

@doc("Promotion gate from replay through limited serving and rollback.")
enum GenAiEtlPromotionGateKind {
  contractStability: "contract_stability",
  offlineReplay: "offline_replay",
  calibratedConfidence: "calibrated_confidence",
  shadowTraffic: "shadow_traffic",
  limitedServing: "limited_serving",
  rollbackResidualPolicy: "rollback_residual_policy",
}

@doc("Evaluation state of a promotion gate.")
enum GenAiEtlPromotionGateState {
  passed: "passed",
  failed: "failed",
  notEvaluated: "not_evaluated",
  blockedMissingEvidence: "blocked_missing_evidence",
}

@doc("Promotion readiness for one gate.")
model GenAiEtlPromotionGate {
  gate: GenAiEtlPromotionGateKind;
  state: GenAiEtlPromotionGateState;

  @doc("Stable evidence code explaining the current gate state.")
  reason?: string;
}

@doc("Observed economics and evidence for one repeated GenAI workflow cluster.")
model GenAiEtlAuditCluster {
  @doc("Stable identifier derived from the privacy-safe cluster dimensions.")
  @encodedName("application/json", "cluster_id")
  clusterId: string;

  @doc("Privacy-safe derived grouping identity used to group repeated calls.")
  @encodedName("application/json", "workflow_key")
  workflowKey: string;

  @encodedName("application/json", "service_name")
  serviceName: string;

  @doc("Present only when an upstream source proves or canonicalizes a low-cardinality, privacy-safe span name.")
  @encodedName("application/json", "span_name")
  spanName?: string;

  @encodedName("application/json", "operation_name")
  operationName?: string;

  provider?: string;

  @encodedName("application/json", "model")
  modelName?: string;

  @encodedName("application/json", "output_contract")
  outputContract: GenAiEtlOutputContract;

  @encodedName("application/json", "task_family")
  taskFamily: GenAiEtlTaskFamily;

  @encodedName("application/json", "call_count")
  callCount: Count;

  @encodedName("application/json", "input_tokens")
  inputTokens: TokenCount;

  @encodedName("application/json", "output_tokens")
  outputTokens: TokenCount;

  @encodedName("application/json", "cache_read_input_tokens")
  cacheReadInputTokens: TokenCount;

  @encodedName("application/json", "cache_creation_input_tokens")
  cacheCreationInputTokens: TokenCount;

  @encodedName("application/json", "reasoning_output_tokens")
  reasoningOutputTokens: TokenCount;

  @encodedName("application/json", "error_count")
  errorCount: Count;

  @encodedName("application/json", "error_rate")
  errorRate: Ratio;

  @encodedName("application/json", "average_latency_ms")
  averageLatencyMs: DurationMs;

  @encodedName("application/json", "p95_latency_ms")
  p95LatencyMs: DurationMs;

  @doc("Outcome and, when calculated, detailed current-catalog token-and-request estimate for this cluster. Aggregate provider billing is never attributed to a cluster.")
  @encodedName("application/json", "catalog_token_estimate")
  catalogTokenEstimate: GenAiEtlCatalogTokenCostEstimate;

  @doc("Fraction of calls with a task-specific correctness signal.")
  @encodedName("application/json", "measurable_coverage")
  measurableCoverage?: Ratio;

  @doc("Fraction of calls proven safe to route to a residual path.")
  @encodedName("application/json", "safe_deferral_coverage")
  safeDeferralCoverage?: Ratio;

  @doc("Evidence status qualifying the proposed candidate path.")
  @encodedName("application/json", "candidate_status")
  candidateStatus: GenAiEtlCandidateStatus;

  @encodedName("application/json", "candidate_path")
  candidatePath: GenAiEtlCandidatePath;

  @doc("Task-specific metrics required to falsify the proposed replacement.")
  @encodedName("application/json", "validation_metrics")
  @minItems(1)
  validationMetrics: GenAiEtlValidationMetric[];

  @encodedName("application/json", "residual_path")
  residualPath: GenAiEtlResidualPath;

  @encodedName("application/json", "evidence_signals")
  evidenceSignals: GenAiEtlEvidenceSignal[];

  @encodedName("application/json", "missing_evidence")
  missingEvidence: GenAiEtlEvidenceSignal[];

  @encodedName("application/json", "promotion_gates")
  promotionGates: GenAiEtlPromotionGate[];
}

@doc("Aggregate trace-level economics for the requested audit period.")
model GenAiEtlAuditSummary {
  @encodedName("application/json", "total_calls")
  totalCalls: Count;

  @encodedName("application/json", "total_input_tokens")
  totalInputTokens: TokenCount;

  @encodedName("application/json", "total_output_tokens")
  totalOutputTokens: TokenCount;

  @doc("Counterfactual token and request cost of the full observed audit population before the cluster response limit is applied, using the current live catalog snapshot; this is not an official billed total or a historical price claim.")
  @encodedName("application/json", "estimated_catalog_token_cost_usd")
  estimatedCatalogTokenCostUsd?: CostUsd;

  @doc("Fraction of observed calls covered by all-or-nothing calculated token-and-request estimates; missing pricing is not treated as zero.")
  @encodedName("application/json", "catalog_token_priced_call_coverage")
  catalogTokenPricedCallCoverage: Ratio;

  @doc("Returned top-cluster token-and-request estimate divided by estimated_catalog_token_cost_usd for the full observed audit population.")
  @encodedName("application/json", "estimated_token_economic_concentration")
  estimatedTokenEconomicConcentration?: Ratio;

  @doc("Fraction of calls with a task-specific correctness signal.")
  @encodedName("application/json", "measurable_coverage")
  measurableCoverage?: Ratio;

  @doc("Fraction of calls proven safe to defer to a residual path.")
  @encodedName("application/json", "safe_deferral_coverage")
  safeDeferralCoverage?: Ratio;

  @doc("Fraction of estimated current-catalog token-and-request spend attached to ETL-shaped candidates.")
  @encodedName("application/json", "candidate_etl_estimated_token_spend_share")
  candidateEtlEstimatedTokenSpendShare?: Ratio;
}

@doc("Trace-level ETL audit for a bounded period.")
model GenAiEtlAuditReport {
  @encodedName("application/json", "generated_at")
  generatedAt: utcDateTime;

  @encodedName("application/json", "period_start")
  periodStart: utcDateTime;

  @encodedName("application/json", "period_end")
  periodEnd: utcDateTime;

  summary: GenAiEtlAuditSummary;

  @doc("Provider-owned aggregate billing sources. These totals are not attributed to clusters or used as evaluation baselines.")
  @encodedName("application/json", "billing_sources")
  billingSources: ProviderBillingSource[];

  @doc("Configured live model catalog sources and their current synchronization state.")
  @encodedName("application/json", "catalog_sources")
  catalogSources: ModelCatalogSource[];

  clusters: GenAiEtlAuditCluster[];
}

@doc("What-if assumptions for one workflow cluster over the requested period.")
model GenAiEtlClusterScenario {
  @encodedName("application/json", "cluster_id")
  clusterId: string;

  @doc("Fraction of cluster calls the replacement is expected to serve safely.")
  coverage: Ratio;

  @doc("Explicit scenario baseline cost per call. It wins over a calculated catalog estimate; when both are absent, evaluation fails closed.")
  @encodedName("application/json", "frontier_cost_per_call_usd")
  frontierCostPerCallUsd?: CostUsd;

  @encodedName("application/json", "alternative_cost_per_call_usd")
  alternativeCostPerCallUsd: CostUsd;

  @encodedName("application/json", "period_maintenance_cost_usd")
  periodMaintenanceCostUsd: CostUsd;

  @encodedName("application/json", "period_error_cost_usd")
  periodErrorCostUsd: CostUsd;
}

@doc("Batch of cluster scenarios evaluated against one audit period.")
model GenAiEtlAuditEvaluationRequest {
  @minItems(1)
  @maxItems(100)
  scenarios: GenAiEtlClusterScenario[];
}

@doc("Evidence basis for the frontier cost used in a replacement-value calculation.")
enum GenAiEtlFrontierCostBasis {
  @doc("The request supplied an explicit what-if scenario cost, which takes precedence over a catalog estimate.")
  scenario: "scenario",

  @doc("A token-and-request live model catalog estimate was used; this is not an official billed total.")
  catalogTokenEstimate: "catalog_token_estimate",

  @doc("No defensible frontier cost was available.")
  unavailable: "unavailable",
}

model GenAiEtlClusterEvaluationBase {
  @encodedName("application/json", "cluster_id")
  clusterId: string;

  @encodedName("application/json", "call_count")
  callCount: Count;

  coverage: Ratio;

  @encodedName("application/json", "served_call_count")
  servedCallCount: float64;

  @encodedName("application/json", "residual_call_count")
  residualCallCount: float64;

  @encodedName("application/json", "alternative_cost_per_call_usd")
  alternativeCostPerCallUsd: CostUsd;

  @encodedName("application/json", "period_maintenance_cost_usd")
  periodMaintenanceCostUsd: CostUsd;

  @encodedName("application/json", "period_error_cost_usd")
  periodErrorCostUsd: CostUsd;
}

model GenAiEtlCalculatedClusterEvaluationBase extends GenAiEtlClusterEvaluationBase {
  status: "calculated";

  @encodedName("application/json", "frontier_cost_per_call_usd")
  frontierCostPerCallUsd: CostUsd;

  @encodedName("application/json", "current_period_cost_usd")
  currentPeriodCostUsd: CostUsd;

  @encodedName("application/json", "gross_replaceable_value_usd")
  grossReplaceableValueUsd: float64;

  @doc("Net period value; this may be negative when maintenance or error cost exceeds gross savings.")
  @encodedName("application/json", "net_replaceable_value_usd")
  netReplaceableValueUsd: float64;
}

model GenAiEtlScenarioClusterEvaluation extends GenAiEtlCalculatedClusterEvaluationBase {
  @encodedName("application/json", "frontier_cost_basis")
  frontierCostBasis: "scenario";
}

model GenAiEtlCatalogTokenClusterEvaluation extends GenAiEtlCalculatedClusterEvaluationBase {
  @encodedName("application/json", "frontier_cost_basis")
  frontierCostBasis: "catalog_token_estimate";

  @doc("Exact live-catalog snapshot and model-match evidence used for the calculated frontier cost.")
  @encodedName("application/json", "catalog_provenance")
  catalogProvenance: ModelCatalogPriceProvenance;
}

model GenAiEtlUnavailableClusterEvaluation extends GenAiEtlClusterEvaluationBase {
  status: "missing_frontier_cost";

  @encodedName("application/json", "frontier_cost_basis")
  frontierCostBasis: "unavailable";
}

@doc("Result of replaceable_value = calls * coverage * (frontier - alternative) - maintenance - error. The frontier_cost_basis literal selects a complete calculated result or a fail-closed unavailable result.")
@oneOf
union GenAiEtlClusterEvaluation {
  scenario: GenAiEtlScenarioClusterEvaluation,
  catalogTokenEstimate: GenAiEtlCatalogTokenClusterEvaluation,
  unavailable: GenAiEtlUnavailableClusterEvaluation,
}

@doc("Batch result for ETL replacement scenarios.")
model GenAiEtlAuditEvaluationResponse {
  @encodedName("application/json", "generated_at")
  generatedAt: utcDateTime;

  @encodedName("application/json", "period_start")
  periodStart: utcDateTime;

  @encodedName("application/json", "period_end")
  periodEnd: utcDateTime;

  results: GenAiEtlClusterEvaluation[];
}
