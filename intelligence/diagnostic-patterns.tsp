// =============================================================================
// ANcpLua v2.0 - Diagnostic Patterns
// =============================================================================
// A named combination of signals that identifies a known failure mode.
// All signals in a pattern must match (conjunction). Multiple patterns can
// match the same telemetry — the engine returns all matches ranked by confidence.
// =============================================================================

import "@typespec/openapi";

using TypeSpec.OpenAPI;

namespace Qyl.Api.Contracts.Intelligence;

@doc("Classification category for diagnostic patterns")
enum PatternCategory {
  @doc("Exception and error patterns")
  error: "error",

  @doc("Performance degradation")
  latency: "latency",

  @doc("Token/cost anomalies")
  cost: "cost",

  @doc("Service health patterns")
  availability: "availability",

  @doc("GenAI-specific failure modes")
  genai: "genai",

  @doc("Database and storage patterns")
  data: "data",
}

@doc("Named combination of signals identifying a known failure mode")
model DiagnosticPattern {
  @doc("Unique pattern identifier (e.g. genai_rate_limit)")
  id: string;

  @doc("Pattern classification")
  category: PatternCategory;

  @doc("Signals that must all match (conjunction)")
  signals: Signal[];

  @doc("What this pattern means diagnostically")
  hypothesis: string;

  @doc("Base confidence weight (0.0-1.0)")
  @minValue(0.0)
  @maxValue(1.0)
  confidence: float64;
}
