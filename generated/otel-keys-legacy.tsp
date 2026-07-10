// Hand-maintained companion to otel-keys.gen.tsp — NOT generated. Frozen legacy
// wire keys that upstream removed from the registries at the 1.41→1.43 bump
// (the GenAI split: gen_ai.system/prompt/completion/usage.{prompt,completion}_tokens
// were dropped outright; of the gen_ai.openai.* vendor keys, service_tier ×2 and
// response.system_fingerprint were renamed to openai.*, seed and
// request.response_format were removed with no successor).
//
// qyl's public contracts still carry these dotted keys on deliberately-deprecated
// migration fields (`@removed(GenAiVersions.…)` in models/genai.tsp). A wire name
// is a published contract: it stays frozen even after upstream deletes the key.
// The values below are verbatim from the last registry that defined them
// (open-telemetry/semantic-conventions v1.41.0, via the retired
// @ancplua/typespec-otel-semconv@1.41.0-2 projection).
//
// TypeSpec merges namespaces across files, so these consts land in the same
// Keys.GenAi namespace the generated file populates — consuming models did not
// change. If a future regeneration re-introduces one of these names, the
// compiler will error on the duplicate: resolve by deleting it HERE.

namespace ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi {
  /** Frozen legacy wire key; removed from semconv (replaced by gen_ai.output.messages). */
  #deprecated "Removed upstream; frozen for contract compatibility."
  const Completion: string = "gen_ai.completion";
  /** Frozen legacy wire key; removed from semconv (no openai.* successor at 1.43). */
  #deprecated "Removed upstream; frozen for contract compatibility."
  const OpenaiRequestResponseFormat: string = "gen_ai.openai.request.response_format";
  /** Frozen legacy wire key; removed from semconv (no openai.* successor at 1.43). */
  #deprecated "Removed upstream; frozen for contract compatibility."
  const OpenaiRequestSeed: string = "gen_ai.openai.request.seed";
  /** Frozen legacy wire key; renamed upstream to openai.request.service_tier. */
  #deprecated "Renamed upstream to openai.request.service_tier; frozen for contract compatibility."
  const OpenaiRequestServiceTier: string = "gen_ai.openai.request.service_tier";
  /** Frozen legacy wire key; renamed upstream to openai.response.service_tier. */
  #deprecated "Renamed upstream to openai.response.service_tier; frozen for contract compatibility."
  const OpenaiResponseServiceTier: string = "gen_ai.openai.response.service_tier";
  /** Frozen legacy wire key; renamed upstream to openai.response.system_fingerprint. */
  #deprecated "Renamed upstream to openai.response.system_fingerprint; frozen for contract compatibility."
  const OpenaiResponseSystemFingerprint: string = "gen_ai.openai.response.system_fingerprint";
  /** Frozen legacy wire key; removed from semconv (replaced by gen_ai.input.messages). */
  #deprecated "Removed upstream; frozen for contract compatibility."
  const Prompt: string = "gen_ai.prompt";
  /** Frozen legacy wire key; removed from semconv (replaced by gen_ai.provider.name). */
  #deprecated "Replaced by gen_ai.provider.name; frozen for contract compatibility."
  const System: string = "gen_ai.system";
  /** Frozen legacy wire key; removed from semconv (replaced by gen_ai.usage.output_tokens). */
  #deprecated "Replaced by gen_ai.usage.output_tokens; frozen for contract compatibility."
  const UsageCompletionTokens: string = "gen_ai.usage.completion_tokens";
  /** Frozen legacy wire key; removed from semconv (replaced by gen_ai.usage.input_tokens). */
  #deprecated "Replaced by gen_ai.usage.input_tokens; frozen for contract compatibility."
  const UsagePromptTokens: string = "gen_ai.usage.prompt_tokens";
}
