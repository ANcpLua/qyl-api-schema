// =============================================================================
// GenAI cost provenance and ETL-audit contracts
// =============================================================================

import "@typespec/openapi";
import "../common/types.tsp";

using TypeSpec.OpenAPI;
using Qyl.Api.Contracts.Common;

namespace Qyl.Api.Contracts.Cost;

@doc("How a provider-owned API supplied a cost value.")
enum ProviderCostSourceKind {
  @doc("Actual billed cost returned by a provider organization or cloud billing API.")
  actualBilledCost: "actual_billed_cost",

  @doc("A public SKU price returned by an official provider or cloud pricing API.")
  officialPublicCatalog: "official_public_catalog",
}

@doc("Current synchronization state for a provider-owned cost source.")
enum ProviderCostSourceStatus {
  @doc("The source has no configured provider credential or cloud identity.")
  unconfigured: "unconfigured",

  @doc("The most recent provider fetch completed inside its freshness window.")
  current: "current",

  @doc("The last successful provider response is older than its freshness window.")
  stale: "stale",

  @doc("The latest provider fetch failed; no raw credential or upstream response is exposed.")
  syncFailed: "sync_failed",

  @doc("Provider cost exists but cannot be attributed to the reported trace clusters.")
  notAttributable: "not_attributable",
}

@doc("Granularity at which a cost value can be attributed to telemetry.")
enum ProviderCostAttribution {
  @doc("The provider API identified the model and period represented by the value.")
  providerModelPeriod: "provider_model_period",

  @doc("The provider API identified only a provider/account period, not a model or request.")
  providerPeriod: "provider_period",

  @doc("The value was supplied explicitly as a what-if scenario input.")
  scenario: "scenario",

  @doc("No defensible attribution is available.")
  unavailable: "unavailable",
}

@doc("Provenance for cost data fetched directly from a provider-owned API.")
model ProviderCostSource {
  @doc("Canonical GenAI provider or cloud billing system name.")
  provider: string;

  @doc("Whether the API returned billed cost or a public catalog price.")
  kind: ProviderCostSourceKind;

  @doc("Current synchronization and attribution state.")
  status: ProviderCostSourceStatus;

  @doc("Official provider-owned API endpoint used for the fetch.")
  @encodedName("application/json", "source_endpoint")
  sourceEndpoint: UrlString;

  @doc("Attribution granularity supported by this source response.")
  attribution: ProviderCostAttribution;

  @doc("UTC time of the latest fetch attempt.")
  @encodedName("application/json", "last_attempt_at")
  lastAttemptAt?: utcDateTime;

  @doc("UTC time of the latest successful fetch.")
  @encodedName("application/json", "last_success_at")
  lastSuccessAt?: utcDateTime;

  @doc("Start of the provider billing or catalog validity period.")
  @encodedName("application/json", "period_start")
  periodStart?: utcDateTime;

  @doc("End of the provider billing or catalog validity period.")
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

@doc("Task-specific metric that can falsify a proposed replacement.")
enum GenAiEtlValidationMetric {
  accuracy: "accuracy",
  macroF1: "macro_f1",
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
  providerCost: "provider_cost",
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

  @doc("Provider-sourced cost attributable to this cluster, absent when attribution is not defensible.")
  @encodedName("application/json", "observed_cost_usd")
  observedCostUsd?: CostUsd;

  @encodedName("application/json", "cost_per_call_usd")
  costPerCallUsd?: CostUsd;

  @encodedName("application/json", "cost_attribution")
  costAttribution: ProviderCostAttribution;

  @doc("Fraction of attributable spend represented by this cluster.")
  @encodedName("application/json", "spend_share")
  spendShare?: Ratio;

  @doc("Fraction of calls with a task-specific correctness signal.")
  @encodedName("application/json", "measurable_coverage")
  measurableCoverage?: Ratio;

  @doc("Fraction of calls proven safe to route to a residual path.")
  @encodedName("application/json", "safe_deferral_coverage")
  safeDeferralCoverage?: Ratio;

  @encodedName("application/json", "candidate_path")
  candidatePath: GenAiEtlCandidatePath;

  @encodedName("application/json", "validation_metric")
  validationMetric: GenAiEtlValidationMetric;

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

  @doc("Provider-sourced cost attributable to the returned trace population.")
  @encodedName("application/json", "attributed_cost_usd")
  attributedCostUsd?: CostUsd;

  @doc("Fraction of calls covered by provider cost attribution.")
  @encodedName("application/json", "priced_call_coverage")
  pricedCallCoverage: Ratio;

  @doc("Fraction of attributable spend represented by the returned top clusters.")
  @encodedName("application/json", "economic_concentration")
  economicConcentration?: Ratio;

  @doc("Fraction of calls with a task-specific correctness signal.")
  @encodedName("application/json", "measurable_coverage")
  measurableCoverage?: Ratio;

  @doc("Fraction of calls proven safe to defer to a residual path.")
  @encodedName("application/json", "safe_deferral_coverage")
  safeDeferralCoverage?: Ratio;

  @doc("Fraction of attributable spend attached to ETL-shaped candidates.")
  @encodedName("application/json", "candidate_etl_spend_share")
  candidateEtlSpendShare?: Ratio;
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

  @encodedName("application/json", "cost_sources")
  costSources: ProviderCostSource[];

  clusters: GenAiEtlAuditCluster[];
}

@doc("What-if assumptions for one workflow cluster over the requested period.")
model GenAiEtlClusterScenario {
  @encodedName("application/json", "cluster_id")
  clusterId: string;

  @doc("Fraction of cluster calls the replacement is expected to serve safely.")
  coverage: Ratio;

  @doc("Explicit baseline cost per call. When absent, qyl uses provider-attributed cluster cost and otherwise fails closed.")
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

@doc("Whether the replaceable-value formula had a defensible baseline cost.")
enum GenAiEtlCalculationStatus {
  calculated: "calculated",
  missingFrontierCost: "missing_frontier_cost",
}

@doc("Result of replaceable_value = calls * coverage * (frontier - alternative) - maintenance - error.")
model GenAiEtlClusterEvaluation {
  @encodedName("application/json", "cluster_id")
  clusterId: string;

  status: GenAiEtlCalculationStatus;

  @encodedName("application/json", "call_count")
  callCount: Count;

  coverage: Ratio;

  @encodedName("application/json", "served_call_count")
  servedCallCount: float64;

  @encodedName("application/json", "residual_call_count")
  residualCallCount: float64;

  @encodedName("application/json", "frontier_cost_per_call_usd")
  frontierCostPerCallUsd?: CostUsd;

  @encodedName("application/json", "frontier_cost_basis")
  frontierCostBasis: ProviderCostAttribution;

  @encodedName("application/json", "alternative_cost_per_call_usd")
  alternativeCostPerCallUsd: CostUsd;

  @encodedName("application/json", "current_period_cost_usd")
  currentPeriodCostUsd?: CostUsd;

  @encodedName("application/json", "gross_replaceable_value_usd")
  grossReplaceableValueUsd?: float64;

  @encodedName("application/json", "period_maintenance_cost_usd")
  periodMaintenanceCostUsd: CostUsd;

  @encodedName("application/json", "period_error_cost_usd")
  periodErrorCostUsd: CostUsd;

  @doc("Net period value; this may be negative when maintenance or error cost exceeds gross savings.")
  @encodedName("application/json", "net_replaceable_value_usd")
  netReplaceableValueUsd?: float64;
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
