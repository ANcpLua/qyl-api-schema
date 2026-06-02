// =============================================================================
// ANcpLua v2.0 - Storage Models
// =============================================================================
// Flattened storage models with DuckDB table generation extensions.
// These are optimized for query performance, not wire format fidelity.
// =============================================================================

import "@typespec/openapi";
import "@typespec/json-schema";

import "../common/types.tsp";
import "./enums.tsp";

using TypeSpec.OpenAPI;
using TypeSpec.JsonSchema;
using Qyl.Api.Contracts.Common;
using Qyl.Api.Contracts.OTel.Enums;

namespace Qyl.Api.Contracts.Storage;

// =============================================================================
// SpanRecord - Primary Storage Model
// =============================================================================

@doc("OpenTelemetry span record for storage and query")
@TypeSpec.OpenAPI.extension("x-duckdb-table", "spans")
@TypeSpec.OpenAPI.extension("x-csharp-type", "SpanRecord")
model SpanRecord {
  // === Identifiers (Primary Key) ===

  @doc("Unique span identifier")
  @key
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "span_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-primary-key", true)
  spanId: SpanId;

  @doc("Trace identifier")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "trace_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_spans_trace_id")
  traceId: TraceId;

  @doc("Parent span identifier (null for root spans)")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "parent_span_id")
  parentSpanId?: SpanId;

  // === Session Grouping ===

  @doc("Session identifier for grouping related traces")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "session_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_spans_session_id")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  sessionId?: SessionId;

  // === Core Span Fields ===

  @doc("Human-readable span name")
  @minLength(1)
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "name")
  name: string;

  @doc("Span kind")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "kind")
  kind: SpanKind;

  @doc("Start timestamp in nanoseconds since epoch")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "start_time_unix_nano")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_spans_start_time")
  startTimeUnixNano: int64;

  @doc("End timestamp in nanoseconds since epoch")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "end_time_unix_nano")
  endTimeUnixNano: int64;

  @doc("Duration in nanoseconds")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "duration_ns")
  durationNs: DurationNs;

  // === Status ===

  @doc("Span status code")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "status_code")
  statusCode: SpanStatusCode;

  @doc("Status message (only for ERROR status)")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "status_message")
  statusMessage?: string;

  // === Service Info ===

  @doc("Service name from resource attributes")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "service_name")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_spans_service_name")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  serviceName?: string;

  // === GenAI Promoted Columns (Fast Access) ===

  @doc("GenAI provider name (e.g., openai, anthropic) - OTel 1.40: gen_ai.provider.name")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "gen_ai_provider_name")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_spans_gen_ai_provider_name")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  genAiProviderName?: string;

  @doc("Requested model name")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "gen_ai_request_model")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_spans_gen_ai_request_model")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  genAiRequestModel?: string;

  @doc("Actual response model name")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "gen_ai_response_model")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  genAiResponseModel?: string;

  @doc("Input/prompt tokens")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "gen_ai_input_tokens")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  genAiInputTokens?: TokenCount;

  @doc("Output/completion tokens")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "gen_ai_output_tokens")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  genAiOutputTokens?: TokenCount;

  @doc("Request temperature")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "gen_ai_temperature")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  genAiTemperature?: Temperature;

  @doc("Response finish reason")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "gen_ai_stop_reason")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  genAiStopReason?: string;

  @doc("Tool name for tool calls")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "gen_ai_tool_name")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  genAiToolName?: string;

  @doc("Tool call ID")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "gen_ai_tool_call_id")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  genAiToolCallId?: string;

  @doc("Estimated cost in USD")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "gen_ai_cost_usd")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  genAiCostUsd?: CostUsd;

  // === Attributes (JSON Blob) ===

  @doc("All span attributes as JSON")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "attributes_json")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR")
  attributesJson?: string;

  @doc("Resource attributes as JSON")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "resource_json")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR")
  resourceJson?: string;

  // === W3C Baggage (JSON) ===

  @doc("W3C Baggage key-value pairs as JSON for cross-cutting concern propagation")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "baggage_json")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR")
  baggageJson?: string;

  // === Schema URL Tracking ===

  @doc("OTel semantic convention schema URL (e.g., https://opentelemetry.io/schemas/1.40.0)")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "schema_url")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR(256)")
  schemaUrl?: string;

  // === Internal Storage Fields ===

  @doc("Row creation timestamp")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "created_at")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "TIMESTAMP DEFAULT now()")
  @TypeSpec.OpenAPI.extension("x-internal", true)
  createdAt?: utcDateTime;
}

// =============================================================================
// SessionSummary - Aggregated View
// =============================================================================

@doc("Session summary with aggregated metrics")
@TypeSpec.OpenAPI.extension("x-duckdb-table", "sessions")
@TypeSpec.OpenAPI.extension("x-csharp-type", "SessionSummary")
model SessionSummary {
  @doc("Session identifier")
  @key
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "session_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-primary-key", true)
  sessionId: SessionId;

  @doc("First span timestamp")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "start_time")
  startTime: int64;

  @doc("Last span timestamp")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "end_time")
  endTime: int64;

  @doc("Total span count")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "span_count")
  spanCount: Count;

  @doc("Error span count")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "error_count")
  errorCount: Count;

  @doc("Total input tokens")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "total_input_tokens")
  totalInputTokens: TokenCount;

  @doc("Total output tokens")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "total_output_tokens")
  totalOutputTokens: TokenCount;

  @doc("Total cost in USD")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "total_cost_usd")
  totalCostUsd: CostUsd;

  @doc("Primary service name")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "service_name")
  serviceName?: string;

  @doc("Primary GenAI provider")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "gen_ai_provider_name")
  genAiProviderName?: string;

  @doc("Primary model used")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "gen_ai_model")
  genAiModel?: string;
}

// =============================================================================
// LogRecordStorage - Log Storage Model
// =============================================================================

@doc("OpenTelemetry log record for storage and query")
@TypeSpec.OpenAPI.extension("x-duckdb-table", "logs")
@TypeSpec.OpenAPI.extension("x-csharp-type", "LogRecordStorage")
model LogRecordStorage {
  // === Identifiers ===

  @doc("Unique log record identifier")
  @key
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "log_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-primary-key", true)
  logId: string;

  @doc("Associated trace ID")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "trace_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_logs_trace_id")
  traceId?: TraceId;

  @doc("Associated span ID")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "span_id")
  spanId?: SpanId;

  // === Session Grouping ===

  @doc("Session identifier for grouping related logs")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "session_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_logs_session_id")
  sessionId?: SessionId;

  // === Timing ===

  @doc("Timestamp when the event occurred (nanoseconds since epoch)")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "time_unix_nano")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_logs_time")
  timeUnixNano: int64;

  @doc("Timestamp when the log was observed/collected")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "observed_time_unix_nano")
  observedTimeUnixNano?: int64;

  // === Severity ===

  @doc("Severity number (1-24)")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "severity_number")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_logs_severity")
  severityNumber: SeverityNumber;

  @doc("Severity text (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "severity_text")
  severityText?: string;

  // === Content ===

  @doc("Log body - the main content")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "body")
  body?: string;

  // === Service Info ===

  @doc("Service name from resource attributes")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "service_name")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_logs_service_name")
  serviceName?: string;

  // === Attributes (JSON Blob) ===

  @doc("Log attributes as JSON")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "attributes_json")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR")
  attributesJson?: string;

  @doc("Resource attributes as JSON")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "resource_json")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR")
  resourceJson?: string;

  // === Source Location ===

  @doc("Source file path where the log was emitted")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "source_file")
  sourceFile?: string;

  @doc("Source line number")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "source_line")
  sourceLine?: int32;

  @doc("Source column number")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "source_column")
  sourceColumn?: int32;

  @doc("Source method name")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "source_method")
  sourceMethod?: string;

  // === Internal Storage Fields ===

  @doc("Row creation timestamp")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "created_at")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "TIMESTAMP DEFAULT now()")
  @TypeSpec.OpenAPI.extension("x-internal", true)
  createdAt?: utcDateTime;
}

// =============================================================================
// TraceNode - For Hierarchical Display
// =============================================================================

@jsonSchema
@doc("Trace tree node for hierarchical span display")
@TypeSpec.OpenAPI.extension("x-csharp-type", "TraceNode")
model TraceNode {
  @doc("Span data")
  span: SpanRecord;

  @doc("Child spans")
  children: TraceNode[];

  @doc("Depth in tree (0 = root)")
  depth: int32;
}

// =============================================================================
// GenAiSpanData - Extracted GenAI Attributes
// =============================================================================

@jsonSchema
@doc("Extracted GenAI attributes from a span")
@TypeSpec.OpenAPI.extension("x-csharp-type", "GenAiSpanData")
model GenAiSpanData {
  @doc("Provider name")
  providerName?: string;

  @doc("Requested model")
  requestModel?: string;

  @doc("Response model")
  responseModel?: string;

  @doc("Input tokens")
  inputTokens?: TokenCount;

  @doc("Output tokens")
  outputTokens?: TokenCount;

  @doc("Temperature")
  temperature?: Temperature;

  @doc("Finish reason")
  stopReason?: string;

  @doc("Tool name")
  toolName?: string;

  @doc("Tool call ID")
  toolCallId?: string;

  @doc("Estimated cost")
  costUsd?: CostUsd;
}

// =============================================================================
// ProfileRecord - Primary Profile Storage (v1development)
// =============================================================================

@doc("OpenTelemetry profile record for storage and query")
@TypeSpec.OpenAPI.extension("x-duckdb-table", "profiles")
@TypeSpec.OpenAPI.extension("x-csharp-type", "ProfileStorageRow")
model ProfileRecord {
  @doc("Unique profile identifier")
  @key
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "profile_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-primary-key", true)
  profileId: string;

  @doc("Correlated trace ID (from Link table)")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "trace_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_profiles_trace_id")
  traceId?: TraceId;

  @doc("Correlated span ID (from Link table)")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "span_id")
  spanId?: SpanId;

  @doc("Session identifier for grouping related profiles")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "session_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_profiles_session_id")
  sessionId?: SessionId;

  @doc("Profile start timestamp in nanoseconds since epoch")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "time_unix_nano")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_profiles_time")
  timeUnixNano: int64;

  @doc("Profile duration in nanoseconds")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "duration_nano")
  durationNano: int64;

  @doc("Number of samples in this profile")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "sample_count")
  sampleCount: int32;

  @doc("Sample type (e.g., cpu, alloc_objects, wall)")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "sample_type")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_profiles_sample_type")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  sampleType?: string;

  @doc("Sample unit (e.g., nanoseconds, bytes, count)")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "sample_unit")
  sampleUnit?: string;

  @doc("Original payload format")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "original_payload_format")
  originalPayloadFormat?: string;

  @doc("Service name from resource attributes")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "service_name")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_profiles_service")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  serviceName?: string;

  @doc("Profile frame type (dotnet, jvm, cpython, etc.)")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "profile_frame_type")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  profileFrameType?: string;

  @doc("Profile attributes as JSON")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "attributes_json")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR")
  attributesJson?: string;

  @doc("Resource attributes as JSON")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "resource_json")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR")
  resourceJson?: string;

  @doc("Full profile structure as JSON blob (denormalized for single-query access)")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "profile_data_json")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR")
  profileDataJson?: string;

  @doc("OTel semantic convention schema URL")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "schema_url")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR(256)")
  schemaUrl?: string;

  @doc("Row creation timestamp")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "created_at")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "TIMESTAMP DEFAULT CURRENT_TIMESTAMP")
  @TypeSpec.OpenAPI.extension("x-internal", true)
  createdAt?: utcDateTime;
}

// =============================================================================
// Profile Child Tables (Normalized from ProfilesDictionary)
// =============================================================================

@doc("Dereferenced function from profile dictionary")
@TypeSpec.OpenAPI.extension("x-duckdb-table", "profile_functions")
@TypeSpec.OpenAPI.extension("x-csharp-type", "ProfileFunctionRow")
model ProfileFunctionRecord {
  @doc("Parent profile ID")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "profile_id")
  profileId: string;

  @doc("Ordinal position in function table")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "ordinal")
  ordinal: int32;

  @doc("Resolved function name")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "name")
  name?: string;

  @doc("Resolved system/mangled function name")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "system_name")
  systemName?: string;

  @doc("Resolved source filename")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "filename")
  filename?: string;

  @doc("First line number of the function")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "start_line")
  startLine?: int64;
}

@doc("Dereferenced location from profile dictionary")
@TypeSpec.OpenAPI.extension("x-duckdb-table", "profile_locations")
@TypeSpec.OpenAPI.extension("x-csharp-type", "ProfileLocationRow")
model ProfileLocationRecord {
  @doc("Parent profile ID")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "profile_id")
  profileId: string;

  @doc("Ordinal position in location table")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "ordinal")
  ordinal: int32;

  @doc("Mapping ordinal for the binary this location belongs to")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "mapping_ordinal")
  mappingOrdinal?: int32;

  @doc("Instruction address")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "address")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "UBIGINT")
  address?: int64;

  @doc("Source lines as JSON (function ordinal, line, column)")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "lines_json")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR")
  linesJson?: string;
}

@doc("Dereferenced memory mapping from profile dictionary")
@TypeSpec.OpenAPI.extension("x-duckdb-table", "profile_mappings")
@TypeSpec.OpenAPI.extension("x-csharp-type", "ProfileMappingRow")
model ProfileMappingRecord {
  @doc("Parent profile ID")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "profile_id")
  profileId: string;

  @doc("Ordinal position in mapping table")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "ordinal")
  ordinal: int32;

  @doc("Resolved filename of the mapped binary")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "filename")
  filename?: string;

  @doc("Start address in virtual memory")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "memory_start")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "UBIGINT")
  memoryStart?: int64;

  @doc("Limit address (exclusive)")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "memory_limit")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "UBIGINT")
  memoryLimit?: int64;

  @doc("Offset within the mapped file")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "file_offset")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "UBIGINT")
  fileOffset?: int64;
}

@doc("Profile sample with resolved cross-signal links")
@TypeSpec.OpenAPI.extension("x-duckdb-table", "profile_samples")
@TypeSpec.OpenAPI.extension("x-csharp-type", "ProfileSampleRow")
model ProfileSampleRecord {
  @doc("Parent profile ID")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "profile_id")
  profileId: string;

  @doc("Ordinal position in sample list")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "ordinal")
  ordinal: int32;

  @doc("Stack ordinal referencing profile_stacks")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "stack_ordinal")
  stackOrdinal?: int32;

  @doc("Resolved trace ID from link table")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "link_trace_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_profile_samples_trace")
  linkTraceId?: TraceId;

  @doc("Resolved span ID from link table")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "link_span_id")
  linkSpanId?: SpanId;

  @doc("Sample values as JSON array")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "values_json")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR")
  valuesJson?: string;

  @doc("Sample timestamps as JSON array")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "timestamps_json")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR")
  timestampsJson?: string;
}

@doc("Profile stack — ordered sequence of location ordinals")
@TypeSpec.OpenAPI.extension("x-duckdb-table", "profile_stacks")
@TypeSpec.OpenAPI.extension("x-csharp-type", "ProfileStackRow")
model ProfileStackRecord {
  @doc("Parent profile ID")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "profile_id")
  profileId: string;

  @doc("Ordinal position in stack table")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "ordinal")
  ordinal: int32;

  @doc("Location ordinals as JSON array (leaf to root)")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "location_ordinals_json")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR")
  locationOrdinalsJson?: string;
}
