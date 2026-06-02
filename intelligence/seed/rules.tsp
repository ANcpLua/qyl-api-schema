// =============================================================================
// ANcpLua v2.0 - Seed Causal Rules (v1)
// =============================================================================
// 6 initial causal rules. Source: specs/telemetry-intelligence.md §5.2
// These compile to static registries in CausalRules.g.cs.
// =============================================================================

namespace Qyl.Api.Contracts.Intelligence.Seed;

// ---------------------------------------------------------------------------
// Rule: deploy_causes_regression
// Cause: deployment_regression → Effect: http_5xx_cluster
// Strength: 0.85, Window: 1h
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Rule: rate_limit_causes_cascade
// Cause: genai_rate_limit → Effect: cascading_timeout
// Strength: 0.70, Window: 5m
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Rule: db_timeout_causes_http_error
// Cause: db_timeout → Effect: http_5xx_cluster
// Strength: 0.80, Window: 1m
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Rule: n_plus_one_causes_db_timeout
// Cause: db_n_plus_one → Effect: db_timeout
// Strength: 0.75, Window: 30s
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Rule: memory_causes_timeout
// Cause: memory_pressure_latency → Effect: cascading_timeout
// Strength: 0.65, Window: 5m
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Rule: token_exhaustion_causes_cost
// Cause: genai_token_exhaustion → Effect: cost_spike
// Strength: 0.60, Window: 1h
// ---------------------------------------------------------------------------
