// =============================================================================
// ANcpLua v2.0 - Tool Call Storage Model (OTel v1.40)
// =============================================================================
// Materialized tool call records extracted from OTLP spans.
// Maps OTel GenAI tool semantic convention attributes to DuckDB columns.
//
// OTel semconv mapping:
//   gen_ai.tool.name           → tool_name
//   gen_ai.tool.type           → tool_type
//   gen_ai.tool.call.id        → call_id
//   gen_ai.tool.call.arguments → arguments_json
//   gen_ai.tool.call.result    → result_json
//   gen_ai.tool.description    → tool_description
//   gen_ai.operation.name      → operation_name (= "execute_tool")
// =============================================================================

import "@typespec/openapi";
import "../../common/types.tsp";
import "../../otel/enums.tsp";

using TypeSpec.OpenAPI;
using Qyl.Api.Contracts.Common;
using Qyl.Api.Contracts.OTel.Enums;

namespace Qyl.Api.Contracts.Domains.Agent.ToolCall;

// =============================================================================
// Tool Call Status
// =============================================================================

@doc("Tool call execution status")
enum ToolCallStatus {
  @doc("Tool is currently executing")
  running: "running",

  @doc("Tool completed successfully")
  completed: "completed",

  @doc("Tool execution failed")
  failed: "failed",
}

// =============================================================================
// Tool Call Entity - Storage Model
// =============================================================================

@doc("Tool call entity materialized from OTLP spans with gen_ai.tool.* attributes")
@TypeSpec.OpenAPI.extension("x-duckdb-table", "tool_calls")
@TypeSpec.OpenAPI.extension("x-csharp-type", "ToolCallEntity")
model ToolCallEntity {
  // === Identifiers ===

  @doc("Unique tool call identifier - OTel: gen_ai.tool.call.id")
  @key
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "call_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-primary-key", true)
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  callId: string;

  @doc("Parent agent run identifier")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "run_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_tool_calls_run_id")
  runId: string;

  @doc("Parent OTel trace identifier")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "trace_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_tool_calls_trace_id")
  traceId: TraceId;

  @doc("Associated OTel span identifier")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "span_id")
  spanId: SpanId;

  // === Tool Identity (OTel gen_ai.tool.*) ===

  @doc("Tool name - OTel: gen_ai.tool.name (e.g., 'Read', 'Bash', 'Edit', 'TodoWrite')")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "tool_name")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_tool_calls_tool_name")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  toolName: string;

  @doc("Tool type categorization - OTel: gen_ai.tool.type (e.g., 'function', 'extension')")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "tool_type")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  toolType?: string;

  @doc("Tool description - OTel: gen_ai.tool.description")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "tool_description")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  toolDescription?: string;

  // === Tool Call Data (OTel gen_ai.tool.call.*) ===

  @doc("Tool input arguments as JSON - OTel: gen_ai.tool.call.arguments")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "arguments_json")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  argumentsJson?: string;

  @doc("Tool output result as JSON - OTel: gen_ai.tool.call.result")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "result_json")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR")
  @TypeSpec.OpenAPI.extension("x-promoted", true)
  resultJson?: string;

  // === Execution State ===

  @doc("Execution status")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "status")
  status: ToolCallStatus;

  // === Timing ===

  @doc("Tool call start time in nanoseconds since epoch")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "start_time_unix_nano")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_tool_calls_start_time")
  startTimeUnixNano: int64;

  @doc("Tool call end time in nanoseconds since epoch")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "end_time_unix_nano")
  endTimeUnixNano?: int64;

  @doc("Duration in nanoseconds")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "duration_ns")
  durationNs?: DurationNs;

  // === Error ===

  @doc("Error message if failed")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "error_message")
  errorMessage?: string;

  // === Ordering ===

  @doc("Execution order within the agent run")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "sequence_number")
  @minValue(0)
  sequenceNumber: int32;

  // === Internal ===

  @doc("Row creation timestamp")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "created_at")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "TIMESTAMP DEFAULT now()")
  @TypeSpec.OpenAPI.extension("x-internal", true)
  createdAt?: utcDateTime;
}
