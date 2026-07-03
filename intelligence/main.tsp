// =============================================================================
// ANcpLua v2.0 - Telemetry Intelligence Model
// =============================================================================
// Canonical reasoning model over telemetry data. Schema-driven, generated,
// deterministic. Defines diagnostic patterns, causal rules, and investigation
// strategies as typed data consumed by Loom, MCP, and dashboard.
// =============================================================================

import "@typespec/openapi";

import "./signals.tsp";
import "./diagnostic-patterns.tsp";
import "./causal-rules.tsp";
import "./investigation-strategies.tsp";
import "./seed/patterns.tsp";
import "./seed/rules.tsp";
import "./seed/strategies.tsp";
