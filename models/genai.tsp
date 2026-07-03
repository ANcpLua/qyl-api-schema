// =============================================================================
// ANcpLua v2.0 - GenAI Semantic Conventions
// =============================================================================
// Comprehensive AI/LLM telemetry following OpenTelemetry GenAI specifications.
// https://opentelemetry.io/docs/specs/semconv/gen-ai/
// =============================================================================

import "@typespec/versioning";
import "../common/types.tsp";
import "../otel/span.tsp";
import "../otel/metrics.tsp";

using TypeSpec.Versioning;
using Qyl.Api.Contracts.Common;
using Qyl.Api.Contracts.OTel.Traces;
using Qyl.Api.Contracts.OTel.Metrics;

@versioned(GenAiVersions)
namespace Qyl.Api.Contracts.Domains.AI.GenAi;

// =============================================================================
// Version History
// =============================================================================

@doc("GenAI semantic convention versions")
enum GenAiVersions {
  @doc("Initial GenAI semconv (OTel 1.27)")
  v1_27: "1.27.0",

  @doc("Added agent support (OTel 1.28)")
  v1_28: "1.28.0",

  @doc("Token type refinements (OTel 1.29)")
  v1_29: "1.29.0",

  @doc("Deprecated gen_ai.system (OTel 1.37)")
  v1_37: "1.37.0",

  @doc("GenAI.Agent support (OTel 1.38)")
  v1_38: "1.38.0",

  @doc("RPC metadata consolidation (OTel 1.39)")
  v1_39: "1.39.0",

  @doc("Current version (OTel 1.40)")
  v1_40: "1.40.0",
}

// =============================================================================
// GenAI Span Attributes
// =============================================================================

@doc("GenAI span attributes following OTel Semantic Conventions")
model GenAiSpanAttributes {
  // ---------------------------------------------------------------------------
  // Provider & System (REQUIRED)
  // ---------------------------------------------------------------------------

  @doc("The name of the GenAI provider (e.g., 'openai', 'anthropic', 'google', 'azure')")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ProviderName)
  providerName: GenAiProvider;

  @doc("The name of the GenAI system/product (e.g., 'ChatGPT', 'Claude', 'Gemini')")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.System)
  @removed(GenAiVersions.v1_37)
  system?: string;

  // ---------------------------------------------------------------------------
  // Operation Details
  // ---------------------------------------------------------------------------

  @doc("The type of GenAI operation being performed")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.OperationName)
  operationName: GenAiOperationType;

  // ---------------------------------------------------------------------------
  // Request Attributes (Model & Parameters)
  // ---------------------------------------------------------------------------

  @doc("The model ID requested by the client (e.g., 'gpt-4o', 'claude-3-opus-20240229')")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestModel)
  requestModel: string;

  @doc("The temperature parameter for randomness control")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestTemperature)
  @minValue(0.0)
  @maxValue(2.0)
  requestTemperature?: float64;

  @doc("The top_p (nucleus sampling) parameter")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestTopP)
  @minValue(0.0)
  @maxValue(1.0)
  requestTopP?: float64;

  @doc("Number of highest probability tokens to consider for sampling")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestTopK)
  requestTopK?: float64;

  @doc("Maximum tokens to generate in the response")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestMaxTokens)
  @minValue(1)
  requestMaxTokens?: int64;

  @doc("Stop sequences that will halt generation")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestStopSequences)
  requestStopSequences?: string[];

  @doc("Frequency penalty to reduce repetition (-2.0 to 2.0)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestFrequencyPenalty)
  @minValue(-2.0)
  @maxValue(2.0)
  requestFrequencyPenalty?: float64;

  @doc("Presence penalty for new topics (-2.0 to 2.0)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestPresencePenalty)
  @minValue(-2.0)
  @maxValue(2.0)
  requestPresencePenalty?: float64;

  @doc("Seed for deterministic sampling")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestSeed)
  requestSeed?: int64;

  @doc("Encoding format for embeddings")
  @encodedName("application/json", "gen_ai.request.encoding_format")
  requestEncodingFormat?: EmbeddingEncodingFormat;

  @doc("Number of dimensions for embeddings")
  @encodedName("application/json", "gen_ai.request.embedding_dimensions")
  @minValue(1)
  requestEmbeddingDimensions?: int32;

  // ---------------------------------------------------------------------------
  // Response Attributes
  // ---------------------------------------------------------------------------

  @doc("The actual model used (may differ from request)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ResponseModel)
  responseModel?: string;

  @doc("Response ID from the provider")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ResponseId)
  responseId?: string;

  @doc("Reasons why generation stopped")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ResponseFinishReasons)
  responseFinishReasons?: GenAiFinishReason[];

  // ---------------------------------------------------------------------------
  // Token Usage (RECOMMENDED)
  // ---------------------------------------------------------------------------

  @doc("Number of input/prompt tokens consumed")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.UsageInputTokens)
  usageInputTokens?: TokenCount;

  @doc("Number of output/completion tokens generated")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.UsageOutputTokens)
  usageOutputTokens?: TokenCount;

  @doc("Total tokens (deprecated - use input + output)")
  @encodedName("application/json", "gen_ai.usage.total_tokens")
  @removed(GenAiVersions.v1_38)
  usageTotalTokens?: TokenCount;

  @doc("Number of cached input tokens (prompt caching)")
  @encodedName("application/json", "gen_ai.usage.input_tokens.cached")
  @added(GenAiVersions.v1_38)
  usageInputTokensCached?: TokenCount;

  @doc("Number of reasoning tokens (for o1-like models)")
  @encodedName("application/json", "gen_ai.usage.output_tokens.reasoning")
  @added(GenAiVersions.v1_38)
  usageOutputTokensReasoning?: TokenCount;

  @doc("Number of cache read input tokens (prompt caching)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.UsageCacheReadInputTokens)
  @added(GenAiVersions.v1_40)
  usageCacheReadInputTokens?: TokenCount;

  @doc("Number of cache creation input tokens")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.UsageCacheCreationInputTokens)
  @added(GenAiVersions.v1_40)
  usageCacheCreationInputTokens?: TokenCount;

  // ---------------------------------------------------------------------------
  // Deprecated Attributes (for migration)
  // ---------------------------------------------------------------------------

  @doc("Prompt tokens (deprecated - use gen_ai.usage.input_tokens)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.UsagePromptTokens)
  @removed(GenAiVersions.v1_28)
  usagePromptTokens?: TokenCount;

  @doc("Completion tokens (deprecated - use gen_ai.usage.output_tokens)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.UsageCompletionTokens)
  @removed(GenAiVersions.v1_28)
  usageCompletionTokens?: TokenCount;

  // ---------------------------------------------------------------------------
  // Agent Attributes (v1.38+)
  // ---------------------------------------------------------------------------

  @doc("Unique identifier for the AI agent")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.AgentId)
  @added(GenAiVersions.v1_38)
  agentId?: string;

  @doc("Human-readable name of the AI agent")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.AgentName)
  @added(GenAiVersions.v1_38)
  agentName?: string;

  @doc("Description of the agent's purpose")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.AgentDescription)
  @added(GenAiVersions.v1_38)
  agentDescription?: string;

  @doc("Version of the AI agent")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.AgentVersion)
  @added(GenAiVersions.v1_40)
  agentVersion?: string;

  // ---------------------------------------------------------------------------
  // Conversation & Tool Calling
  // ---------------------------------------------------------------------------

  @doc("Conversation identifier for multi-turn interactions")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ConversationId)
  conversationId?: string;

  @doc("Names of tools available to the model")
  @encodedName("application/json", "gen_ai.request.tool_names")
  requestToolNames?: string[];

  @doc("Tool choice mode")
  @encodedName("application/json", "gen_ai.request.tool_choice")
  requestToolChoice?: GenAiToolChoice;

  @doc("The name of the tool utilized")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ToolName)
  toolName?: string;

  @doc("The tool call identifier")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ToolCallId)
  toolCallId?: string;

  // ---------------------------------------------------------------------------
  // Error Information
  // ---------------------------------------------------------------------------

  @doc("Error type if the request failed")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Error.Type)
  errorType?: GenAiErrorType;

  // ---------------------------------------------------------------------------
  // Data Source & Evaluation Attributes (OTel 1.40)
  // ---------------------------------------------------------------------------

  @doc("Identifier for the data source being used")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.DataSourceId)
  dataSourceId?: string;

  @doc("Explanation from an evaluation")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.EvaluationExplanation)
  evaluationExplanation?: string;

  @doc("Name of the evaluation being performed")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.EvaluationName)
  evaluationName?: string;

  @doc("Label for the evaluation score")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.EvaluationScoreLabel)
  evaluationScoreLabel?: string;

  @doc("Numeric value of the evaluation score")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.EvaluationScoreValue)
  evaluationScoreValue?: float64;

  // ---------------------------------------------------------------------------
  // Input/Output Messages & Prompt Attributes
  // ---------------------------------------------------------------------------

  @doc("Input messages content (may be redacted)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.InputMessages)
  inputMessages?: string;

  @doc("Output messages content (may be redacted)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.OutputMessages)
  outputMessages?: string;

  @doc("Output type (text, json, image, etc.)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.OutputType)
  outputType?: GenAiOutputType;

  @doc("Prompt content (may be redacted)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.Prompt)
  prompt?: string;

  @doc("Name of the prompt template being used")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.PromptName)
  promptName?: string;

  @doc("System instructions provided to the model")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.SystemInstructions)
  systemInstructions?: string;

  @doc("Completion content (may be redacted)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.Completion)
  completion?: string;

  // ---------------------------------------------------------------------------
  // Extended Request Attributes
  // ---------------------------------------------------------------------------

  @doc("Number of choices/completions requested")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestChoiceCount)
  @minValue(1)
  requestChoiceCount?: int32;

  @doc("Encoding formats requested for embeddings")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestEncodingFormats)
  requestEncodingFormats?: string[];

  // ---------------------------------------------------------------------------
  // Extended Tool Attributes
  // ---------------------------------------------------------------------------

  @doc("Arguments passed to the tool call (JSON)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ToolCallArguments)
  toolCallArguments?: string;

  @doc("Result returned from the tool call")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ToolCallResult)
  toolCallResult?: string;

  @doc("Tool definitions provided to the model (JSON)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ToolDefinitions)
  toolDefinitions?: string;

  @doc("Description of the tool")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ToolDescription)
  toolDescription?: string;

  @doc("Type of the tool (function, retrieval, etc.)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ToolType)
  toolType?: GenAiToolType;

  @doc("Token type for usage tracking")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.TokenType)
  tokenType?: GenAiTokenType;

  // ---------------------------------------------------------------------------
  // Embeddings Attributes
  // ---------------------------------------------------------------------------

  @doc("Number of dimensions in the embedding")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.EmbeddingsDimensionCount)
  @minValue(1)
  embeddingsDimensionCount?: int32;
}

// =============================================================================
// GenAI Exported Attribute Models (OTel 1.40 compliant)
// =============================================================================

@doc("GenAI request-specific attributes")
model GenAiRequestAttributes {
  @doc("The model ID for the request")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestModel)
  requestModel: string;

  @doc("Temperature parameter for randomness control")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestTemperature)
  @minValue(0.0)
  @maxValue(2.0)
  temperature?: float64;

  @doc("Maximum tokens to generate")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestMaxTokens)
  @minValue(1)
  maxTokens?: int64;

  @doc("Top-p (nucleus sampling) parameter")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestTopP)
  @minValue(0.0)
  @maxValue(1.0)
  topP?: float64;

  @doc("Number of highest probability tokens to consider for sampling")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestTopK)
  topK?: float64;

  @doc("Stop sequences that will halt generation")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestStopSequences)
  stopSequences?: string[];

  @doc("Frequency penalty parameter")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestFrequencyPenalty)
  @minValue(-2.0)
  @maxValue(2.0)
  frequencyPenalty?: float64;

  @doc("Presence penalty parameter")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestPresencePenalty)
  @minValue(-2.0)
  @maxValue(2.0)
  presencePenalty?: float64;

  @doc("Random seed for deterministic generation")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestSeed)
  seed?: int64;
}

@doc("GenAI response-specific attributes")
model GenAiResponseAttributes {
  @doc("The model ID returned by the provider")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ResponseModel)
  responseModel?: string;

  @doc("Unique identifier for this completion")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ResponseId)
  id?: string;

  @doc("Finish reasons for each choice")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ResponseFinishReasons)
  finishReasons?: GenAiFinishReason[];
}

@doc("GenAI usage/token attributes")
model GenAiUsageAttributes {
  @doc("Number of input/prompt tokens")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.UsageInputTokens)
  inputTokens: TokenCount;

  @doc("Number of output/completion tokens")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.UsageOutputTokens)
  outputTokens: TokenCount;

  @doc("Total tokens (computed: inputTokens + outputTokens)")
  @encodedName("application/json", "gen_ai.usage.total_tokens")
  totalTokens: TokenCount;

  @doc("Number of cached input tokens (prompt caching)")
  @encodedName("application/json", "gen_ai.usage.input_tokens.cached")
  @added(GenAiVersions.v1_38)
  cachedInputTokens?: TokenCount;

  @doc("Number of reasoning tokens (for o1-like models)")
  @encodedName("application/json", "gen_ai.usage.output_tokens.reasoning")
  @added(GenAiVersions.v1_38)
  reasoningTokens?: TokenCount;
}

@doc("GenAI message in conversation")
model GenAiMessage {
  @doc("Role of the message sender")
  @encodedName("application/json", "msg_role")
  msgRole: GenAiMessageRole;

  @doc("Message content (text)")
  @encodedName("application/json", "msg_content")
  msgContent?: string;

  @doc("Content type")
  @encodedName("application/json", "content_type")
  contentType?: GenAiContentType;

  @doc("Optional name for the sender")
  @encodedName("application/json", "msg_name")
  msgName?: string;

  @doc("Tool calls made by assistant")
  @encodedName("application/json", "tool_calls")
  toolCalls?: GenAiToolCallEvent[];

  @doc("Tool call ID for tool results")
  @encodedName("application/json", "tool_call_id")
  toolCallId?: string;
}

@doc("Cost estimation for GenAI operations")
model GenAiCostEstimate {
  @doc("Estimated cost for input tokens (USD)")
  @encodedName("application/json", "input_cost_usd")
  @minValue(0.0)
  inputCostUsd: float64;

  @doc("Estimated cost for output tokens (USD)")
  @encodedName("application/json", "output_cost_usd")
  @minValue(0.0)
  outputCostUsd: float64;

  @doc("Total estimated cost (USD)")
  @encodedName("application/json", "total_cost_usd")
  @minValue(0.0)
  totalCostUsd: float64;

  @doc("Cost model/pricing source")
  @encodedName("application/json", "cost_model")
  costModel?: string;

  @doc("Pricing tier applied")
  @encodedName("application/json", "pricing_tier")
  pricingTier?: string;
}

// =============================================================================
// GenAI Enumerations
// =============================================================================

// =============================================================================
// GenAI Provider Names (OTel semconv 1.40 compliant)
// =============================================================================

@doc("GenAI provider names - OTel semconv 1.40 official values")
enum GenAiProvider {
  // ---------------------------------------------------------------------------
  // OFFICIAL OTel semconv 1.40 values
  // ---------------------------------------------------------------------------

  @doc("Anthropic / Claude")
  anthropic: "anthropic",

  @doc("Amazon Bedrock")
  awsBedrock: "aws.bedrock",

  @doc("Azure AI Inference")
  azureAiInference: "azure.ai.inference",

  @doc("Azure AI OpenAI")
  azureAiOpenai: "azure.ai.openai",

  @doc("Cohere")
  cohere: "cohere",

  @doc("DeepSeek")
  deepseek: "deepseek",

  @doc("Google Gemini")
  gcpGemini: "gcp.gemini",

  @doc("Google GenAI")
  gcpGenAi: "gcp.gen_ai",

  @doc("Google Vertex AI")
  gcpVertexAi: "gcp.vertex_ai",

  @doc("Groq")
  groq: "groq",

  @doc("IBM watsonx.ai")
  ibmWatsonxAi: "ibm.watsonx.ai",

  @doc("Mistral AI")
  mistralAi: "mistral_ai",

  @doc("OpenAI / ChatGPT")
  openai: "openai",

  @doc("Perplexity")
  perplexity: "perplexity",

  @doc("xAI / Grok")
  xAi: "x_ai",

  // ---------------------------------------------------------------------------
  // ANcpLua Extensions (not in OTel spec - use ancplua.* for custom attributes)
  // ---------------------------------------------------------------------------

  @doc("Meta / Llama (ANcpLua extension)")
  meta: "meta",

  @doc("Hugging Face (ANcpLua extension)")
  huggingface: "huggingface",

  @doc("Replicate (ANcpLua extension)")
  replicate: "replicate",

  @doc("Together AI (ANcpLua extension)")
  togetherai: "together_ai",

  @doc("Fireworks AI (ANcpLua extension)")
  fireworks: "fireworks",

  @doc("Anyscale (ANcpLua extension)")
  anyscale: "anyscale",

  @doc("Local/self-hosted model (ANcpLua extension)")
  local: "local",

  @doc("Custom/other provider (ANcpLua extension)")
  custom: "custom",
}

// =============================================================================
// GenAI Operation Types (OTel semconv 1.40 compliant)
// =============================================================================

@doc("GenAI operation types - OTel semconv 1.40 official values")
enum GenAiOperationType {
  // ---------------------------------------------------------------------------
  // OFFICIAL OTel semconv 1.40 values
  // ---------------------------------------------------------------------------

  @doc("Chat/conversation completion")
  chat: "chat",

  @doc("Text embedding generation")
  embeddings: "embeddings",

  @doc("Text completion (legacy)")
  textCompletion: "text_completion",

  @doc("Create an AI agent")
  createAgent: "create_agent",

  @doc("Execute a tool/function")
  executeTool: "execute_tool",

  @doc("Generate content (generic)")
  generateContent: "generate_content",

  @doc("Invoke an AI agent")
  invokeAgent: "invoke_agent",

  // ---------------------------------------------------------------------------
  // ANcpLua Extensions (not in OTel spec)
  // ---------------------------------------------------------------------------

  @doc("Image generation (ANcpLua extension)")
  imageGeneration: "image_generation",

  @doc("Audio transcription (ANcpLua extension)")
  audioTranscription: "audio_transcription",

  @doc("Text-to-speech synthesis (ANcpLua extension)")
  textToSpeech: "text_to_speech",

  @doc("Model reranking (ANcpLua extension)")
  rerank: "rerank",

  @doc("Content moderation (ANcpLua extension)")
  moderation: "moderation",
}

@doc("Reasons for generation completion")
enum GenAiFinishReason {
  @doc("Model reached natural stopping point")
  stop: "stop",

  @doc("Hit maximum token limit")
  maxTokens: "max_tokens",

  @doc("Hit length limit")
  length: "length",

  @doc("Content was filtered by safety systems")
  contentFilter: "content_filter",

  @doc("Model requested tool/function call")
  toolCalls: "tool_calls",

  @doc("Model requested function call (deprecated)")
  functionCall: "function_call",

  @doc("Generation was cancelled")
  cancelled: "cancelled",

  @doc("Error occurred during generation")
  error: "error",

  @doc("Recitation detected and blocked")
  recitation: "recitation",

  @doc("Safety stop triggered")
  safety: "safety",

  @doc("Unknown/other reason")
  other: "other",
}

@doc("Tool choice mode for function calling")
enum GenAiToolChoice {
  @doc("Model decides whether to call tools")
  auto: "auto",

  @doc("Model must call at least one tool")
  required: "required",

  @doc("Model must not call any tools")
  none: "none",

  @doc("Model must call a specific tool")
  specific: "specific",
}

@doc("Message roles in chat conversations")
enum GenAiMessageRole {
  @doc("System prompt/instructions")
  system: "system",

  @doc("User message")
  user: "user",

  @doc("Assistant/model response")
  assistant: "assistant",

  @doc("Tool/function result")
  tool: "tool",

  @doc("Function result (deprecated)")
  function: "function",
}

@doc("Content types in messages")
enum GenAiContentType {
  @doc("Plain text content")
  text: "text",

  @doc("Image content")
  image: "image",

  @doc("Audio content")
  audio: "audio",

  @doc("Video content")
  video: "video",

  @doc("File/document content")
  file: "file",

  @doc("Tool call request")
  toolCall: "tool_call",

  @doc("Tool call result")
  toolResult: "tool_result",

  @doc("Thinking/reasoning content")
  thinking: "thinking",

  @doc("Refusal message")
  refusal: "refusal",
}

@doc("Embedding encoding formats")
enum EmbeddingEncodingFormat {
  @doc("Array of floats")
  float: "float",

  @doc("Base64-encoded bytes")
  base64: "base64",
}

@doc("GenAI-specific error types")
enum GenAiErrorType {
  @doc("Authentication failed")
  authenticationError: "authentication_error",

  @doc("Insufficient quota/credits")
  insufficientQuota: "insufficient_quota",

  @doc("Rate limit exceeded")
  rateLimitExceeded: "rate_limit_exceeded",

  @doc("Invalid request parameters")
  invalidRequest: "invalid_request",

  @doc("Context length exceeded")
  contextLengthExceeded: "context_length_exceeded",

  @doc("Content policy violation")
  contentPolicyViolation: "content_policy_violation",

  @doc("Model not found")
  modelNotFound: "model_not_found",

  @doc("Model overloaded")
  modelOverloaded: "model_overloaded",

  @doc("Server error")
  serverError: "server_error",

  @doc("Service unavailable")
  serviceUnavailable: "service_unavailable",

  @doc("Timeout")
  timeout: "timeout",

  @doc("Connection error")
  connectionError: "connection_error",

  @doc("Unknown error")
  `unknown`: "unknown",
}

// =============================================================================
// GenAI Token Types (OTel semconv 1.40 compliant)
// =============================================================================

@doc("Token types for usage tracking - OTel semconv 1.40 official values")
enum GenAiTokenType {
  // ---------------------------------------------------------------------------
  // OFFICIAL OTel semconv 1.40 values
  // ---------------------------------------------------------------------------

  @doc("Input/prompt tokens")
  input: "input",

  @doc("Output/completion tokens")
  output: "output",

  // ---------------------------------------------------------------------------
  // ANcpLua Extensions (not in OTel spec)
  // ---------------------------------------------------------------------------

  @doc("Cached input tokens (ANcpLua extension)")
  cached: "cached",

  @doc("Reasoning tokens for CoT models (ANcpLua extension)")
  reasoning: "reasoning",
}

// =============================================================================
// GenAI Tool Types (OTel semconv 1.40 compliant)
// =============================================================================

@doc("Tool types for GenAI function calling - OTel semconv 1.40 official values")
enum GenAiToolType {
  // ---------------------------------------------------------------------------
  // OFFICIAL OTel semconv 1.40 values
  // ---------------------------------------------------------------------------

  @doc("Function/method call")
  function: "function",

  @doc("Extension tool")
  extension: "extension",

  @doc("Datastore access")
  datastore: "datastore",

  // ---------------------------------------------------------------------------
  // ANcpLua Extensions (not in OTel spec)
  // ---------------------------------------------------------------------------

  @doc("Code interpreter/execution (ANcpLua extension)")
  codeInterpreter: "code_interpreter",

  @doc("MCP (Model Context Protocol) tool (ANcpLua extension)")
  mcp: "mcp",

  @doc("Web search (ANcpLua extension)")
  webSearch: "web_search",
}

@doc("GenAI output types")
enum GenAiOutputType {
  @doc("Text output")
  text: "text",

  @doc("JSON output")
  json: "json",

  @doc("Image output")
  image: "image",

  @doc("Speech/audio output")
  speech: "speech",
}

@doc("Image quality settings")
enum GenAiImageQuality {
  @doc("Standard quality")
  standard: "standard",

  @doc("High quality")
  hd: "hd",

  @doc("Ultra high quality")
  ultra: "ultra",
}

@doc("Image sizes")
enum GenAiImageSize {
  @doc("256x256 pixels")
  size256: "256x256",

  @doc("512x512 pixels")
  size512: "512x512",

  @doc("1024x1024 pixels")
  size1024: "1024x1024",

  @doc("1792x1024 pixels (wide)")
  size1792x1024: "1792x1024",

  @doc("1024x1792 pixels (tall)")
  size1024x1792: "1024x1792",
}

@doc("Audio voice options")
enum GenAiVoice {
  @doc("Alloy voice")
  alloy: "alloy",

  @doc("Echo voice")
  echo: "echo",

  @doc("Fable voice")
  fable: "fable",

  @doc("Onyx voice")
  onyx: "onyx",

  @doc("Nova voice")
  nova: "nova",

  @doc("Shimmer voice")
  shimmer: "shimmer",
}

@doc("Audio response formats")
enum GenAiAudioFormat {
  @doc("MP3 format")
  mp3: "mp3",

  @doc("Opus format")
  opus: "opus",

  @doc("AAC format")
  aac: "aac",

  @doc("FLAC format")
  flac: "flac",

  @doc("WAV format")
  wav: "wav",

  @doc("PCM format")
  pcm: "pcm",
}

@doc("Moderation categories")
enum GenAiModerationCategory {
  @doc("Hate speech")
  hate: "hate",

  @doc("Hate speech with threats")
  hateThreatening: "hate/threatening",

  @doc("Harassment")
  harassment: "harassment",

  @doc("Harassment with threats")
  harassmentThreatening: "harassment/threatening",

  @doc("Self-harm content")
  selfHarm: "self-harm",

  @doc("Self-harm instructions")
  selfHarmInstructions: "self-harm/instructions",

  @doc("Self-harm intent")
  selfHarmIntent: "self-harm/intent",

  @doc("Sexual content")
  sexual: "sexual",

  @doc("Sexual content involving minors")
  sexualMinors: "sexual/minors",

  @doc("Violence")
  violence: "violence",

  @doc("Graphic violence")
  violenceGraphic: "violence/graphic",
}

@doc("Content filter severity levels")
enum GenAiFilterSeverity {
  @doc("Safe content")
  safe: "safe",

  @doc("Low severity")
  low: "low",

  @doc("Medium severity")
  medium: "medium",

  @doc("High severity")
  high: "high",
}

@doc("Response format types")
enum GenAiResponseFormat {
  @doc("Plain text response")
  text: "text",

  @doc("JSON object response")
  jsonObject: "json_object",

  @doc("JSON schema-constrained response")
  jsonSchema: "json_schema",
}

// =============================================================================
// GenAI Event Models
// =============================================================================

@doc("Event for prompt/message content")
model GenAiPromptEvent {
  @doc("Event name")
  @encodedName("application/json", "event.name")
  eventName: "gen_ai.content.prompt";

  @doc("Message index in conversation")
  @encodedName("application/json", "gen_ai.prompt.index")
  promptIndex: int32;

  @doc("Role of the message sender")
  @encodedName("application/json", "gen_ai.prompt.role")
  promptRole: GenAiMessageRole;

  @doc("Content type")
  @encodedName("application/json", "gen_ai.prompt.content_type")
  contentType?: GenAiContentType;

  @doc("Content (may be redacted for privacy)")
  @encodedName("application/json", "gen_ai.prompt.content")
  content?: string;

  @doc("Token count for this message")
  @encodedName("application/json", "gen_ai.prompt.tokens")
  tokens?: TokenCount;
}

@doc("Event for completion/response content")
model GenAiCompletionEvent {
  @doc("Event name")
  @encodedName("application/json", "event.name")
  eventName: "gen_ai.content.completion";

  @doc("Choice index for multi-choice responses")
  @encodedName("application/json", "gen_ai.completion.index")
  completionIndex: int32;

  @doc("Role (always assistant)")
  @encodedName("application/json", "gen_ai.completion.role")
  completionRole: "assistant";

  @doc("Finish reason for this choice")
  @encodedName("application/json", "gen_ai.completion.finish_reason")
  finishReason?: GenAiFinishReason;

  @doc("Content (may be redacted for privacy)")
  @encodedName("application/json", "gen_ai.completion.content")
  content?: string;

  @doc("Token count for this completion")
  @encodedName("application/json", "gen_ai.completion.tokens")
  tokens?: TokenCount;
}

@doc("Event for tool/function calls")
model GenAiToolCallEvent {
  @doc("Event name")
  @encodedName("application/json", "event.name")
  eventName: "gen_ai.tool.call";

  @doc("Tool call ID")
  @encodedName("application/json", "gen_ai.tool.id")
  toolId: string;

  @doc("Tool/function name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ToolName)
  toolName: string;

  @doc("Tool arguments (JSON string)")
  @encodedName("application/json", "gen_ai.tool.arguments")
  toolArguments?: string;
}

@doc("Event for tool/function results")
model GenAiToolResultEvent {
  @doc("Event name")
  @encodedName("application/json", "event.name")
  eventName: "gen_ai.tool.result";

  @doc("Tool call ID")
  @encodedName("application/json", "gen_ai.tool.id")
  toolId: string;

  @doc("Tool result (may be truncated)")
  @encodedName("application/json", "gen_ai.tool.result")
  toolResult?: string;

  @doc("Whether the tool execution succeeded")
  @encodedName("application/json", "gen_ai.tool.success")
  toolSuccess: boolean;

  @doc("Error message if failed")
  @encodedName("application/json", "gen_ai.tool.error")
  toolError?: string;
}

// =============================================================================
// GenAI Metrics
// =============================================================================

@doc("GenAI token usage metric (counter)")
model GenAiTokenUsageMetric {
  @doc("Metric name")
  name: "gen_ai.client.token.usage";

  @doc("Metric unit")
  unit: "{token}";

  @doc("Token type (input or output)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.TokenType)
  tokenType: GenAiTokenType;

  @doc("Provider name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ProviderName)
  providerName: GenAiProvider;

  @doc("Model name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestModel)
  requestModel: string;
}

@doc("GenAI operation duration metric (histogram)")
model GenAiOperationDurationMetric {
  @doc("Metric name")
  name: "gen_ai.client.operation.duration";

  @doc("Metric unit (seconds)")
  unit: "s";

  @doc("Operation type")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.OperationName)
  operationName: GenAiOperationType;

  @doc("Provider name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ProviderName)
  providerName: GenAiProvider;

  @doc("Model name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestModel)
  requestModel: string;

  @doc("Error type if failed")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Error.Type)
  errorType?: GenAiErrorType;
}

@doc("Time to first token metric (histogram)")
model GenAiTimeToFirstTokenMetric {
  @doc("Metric name")
  name: "gen_ai.client.time_to_first_token";

  @doc("Metric unit (seconds)")
  unit: "s";

  @doc("Provider name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.ProviderName)
  providerName: GenAiProvider;

  @doc("Model name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.RequestModel)
  requestModel: string;
}

// =============================================================================
// GenAI Aggregated Statistics
// =============================================================================

@doc("Aggregated GenAI usage statistics")
model GenAiStats {
  @doc("Total number of GenAI operations")
  @encodedName("application/json", "total_operations")
  totalOperations: Count;

  @doc("Total input tokens consumed")
  @encodedName("application/json", "total_input_tokens")
  totalInputTokens: TokenCount;

  @doc("Total output tokens generated")
  @encodedName("application/json", "total_output_tokens")
  totalOutputTokens: TokenCount;

  @doc("Total cached input tokens")
  @encodedName("application/json", "total_cached_tokens")
  totalCachedTokens?: TokenCount;

  @doc("Token usage by model")
  @encodedName("application/json", "usage_by_model")
  usageByModel: GenAiModelUsage[];

  @doc("Token usage by provider")
  @encodedName("application/json", "usage_by_provider")
  usageByProvider: GenAiProviderUsage[];

  @doc("Usage by operation type")
  @encodedName("application/json", "usage_by_operation")
  usageByOperation: GenAiOperationUsage[];

  @doc("Error statistics")
  @encodedName("application/json", "error_stats")
  errorStats: GenAiErrorStats;

  @doc("Latency percentiles (in milliseconds)")
  @encodedName("application/json", "latency_percentiles")
  latencyPercentiles: LatencyPercentiles;

  @doc("Estimated cost in USD (if available)")
  @encodedName("application/json", "estimated_cost_usd")
  estimatedCostUsd?: float64;
}

@doc("Model-level usage statistics")
model GenAiModelUsage {
  @doc("Model identifier")
  @encodedName("application/json", "model_name")
  modelName: string;

  @doc("Provider name")
  provider: GenAiProvider;

  @doc("Operation count")
  @encodedName("application/json", "operation_count")
  operationCount: Count;

  @doc("Input tokens")
  @encodedName("application/json", "input_tokens")
  inputTokens: TokenCount;

  @doc("Output tokens")
  @encodedName("application/json", "output_tokens")
  outputTokens: TokenCount;

  @doc("Error count")
  @encodedName("application/json", "error_count")
  errorCount: Count;

  @doc("Average latency in milliseconds")
  @encodedName("application/json", "avg_latency_ms")
  avgLatencyMs: float64;
}

@doc("Provider-level usage statistics")
model GenAiProviderUsage {
  @doc("Provider name")
  provider: GenAiProvider;

  @doc("Operation count")
  @encodedName("application/json", "operation_count")
  operationCount: Count;

  @doc("Total tokens (input + output)")
  @encodedName("application/json", "total_tokens")
  totalTokens: TokenCount;

  @doc("Error rate")
  @encodedName("application/json", "error_rate")
  errorRate: Ratio;
}

@doc("Operation-level usage statistics")
model GenAiOperationUsage {
  @doc("Operation type")
  @encodedName("application/json", "operation_type")
  operationType: GenAiOperationType;

  @doc("Operation count")
  @encodedName("application/json", "operation_count")
  operationCount: Count;

  @doc("Average tokens per operation")
  @encodedName("application/json", "avg_tokens")
  avgTokens: float64;
}

@doc("Error statistics")
model GenAiErrorStats {
  @doc("Total error count")
  @encodedName("application/json", "total_errors")
  totalErrors: Count;

  @doc("Error rate")
  @encodedName("application/json", "error_rate")
  errorRate: Ratio;

  @doc("Errors by type")
  @encodedName("application/json", "by_type")
  byType: GenAiErrorCount[];
}

@doc("Error count by type")
model GenAiErrorCount {
  @doc("Error type")
  @encodedName("application/json", "error_type")
  errorType: GenAiErrorType;

  @doc("Count")
  count: Count;
}

@doc("Latency percentiles")
model LatencyPercentiles {
  @doc("P50 (median) in milliseconds")
  p50: float64;

  @doc("P75 in milliseconds")
  p75: float64;

  @doc("P90 in milliseconds")
  p90: float64;

  @doc("P95 in milliseconds")
  p95: float64;

  @doc("P99 in milliseconds")
  p99: float64;
}

// =============================================================================
// Vendor-Specific Extensions (OTel 1.40)
// =============================================================================

@doc("OpenAI-specific request attributes")
model OpenAiRequestAttributes {
  @doc("Response format requested (text, json_object, json_schema)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.OpenaiRequestResponseFormat)
  responseFormat?: OpenAiResponseFormat;

  @doc("Random seed for deterministic generation")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.OpenaiRequestSeed)
  seed?: int64;

  @doc("Service tier for the request (auto, default, etc.)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.OpenaiRequestServiceTier)
  serviceTier?: string;
}

@doc("OpenAI-specific response attributes")
model OpenAiResponseAttributes {
  @doc("Service tier used for the response")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.OpenaiResponseServiceTier)
  serviceTier?: string;

  @doc("System fingerprint for reproducibility")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.GenAi.OpenaiResponseSystemFingerprint)
  systemFingerprint?: string;
}

@doc("OpenAI response format types")
enum OpenAiResponseFormat {
  @doc("Plain text response")
  text: "text",

  @doc("JSON object response")
  jsonObject: "json_object",

  @doc("JSON schema-constrained response")
  jsonSchema: "json_schema",
}
