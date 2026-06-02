// =============================================================================
// ANcpLua v2.0 - Causal Rules
// =============================================================================
// Directed relationship between two diagnostic patterns: if cause is observed,
// effect is likely. Causal rules build a directed graph. Given matched patterns,
// the engine traverses causal edges to identify root causes (patterns with no
// incoming causal edges).
// =============================================================================

import "@typespec/openapi";

using TypeSpec.OpenAPI;

namespace Qyl.Api.Contracts.Intelligence;

@doc("Directed causal relationship between two diagnostic patterns")
model CausalRule {
  @doc("Unique rule identifier")
  id: string;

  @doc("ID of the cause DiagnosticPattern")
  causePattern: string;

  @doc("ID of the effect DiagnosticPattern")
  effectPattern: string;

  @doc("Causal confidence (0.0-1.0)")
  @minValue(0.0)
  @maxValue(1.0)
  strength: float64;

  @doc("Time window for correlation (e.g. 5m, 1h)")
  temporalWindow?: string;
}
