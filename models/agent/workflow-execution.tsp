// =============================================================================
// ANcpLua v2.0 - Workflow Execution Storage Model (OTel v1.40)
// =============================================================================
// Workflow execution tracking for multi-step AI agent workflows.
// Formalizes the existing manual DuckDB table into TypeSpec.
// =============================================================================

import "@typespec/openapi";
import "../../common/types.tsp";
import "../../otel/enums.tsp";

using TypeSpec.OpenAPI;
using Qyl.Api.Contracts.Common;
using Qyl.Api.Contracts.OTel.Enums;

namespace Qyl.Api.Contracts.Domains.Agent.Workflow;

// =============================================================================
// Workflow Execution Status
// =============================================================================

@doc("Workflow execution status")
enum WorkflowExecutionStatus {
  @doc("Workflow is pending execution")
  pending: "pending",

  @doc("Workflow is currently running")
  running: "running",

  @doc("Workflow completed successfully")
  completed: "completed",

  @doc("Workflow execution failed")
  failed: "failed",

  @doc("Workflow execution was cancelled")
  cancelled: "cancelled",
}

// =============================================================================
// Workflow Trigger Type
// =============================================================================

@doc("What triggered a workflow execution")
enum WorkflowTrigger {
  @doc("Manually triggered by user or agent")
  manual: "manual",

  @doc("Triggered by schedule/cron")
  schedule: "schedule",

  @doc("Triggered by event (e.g., error, alert)")
  event: "event",

  @doc("Triggered by another workflow")
  workflow: "workflow",
}

// =============================================================================
// Workflow Execution Entity - Storage Model
// =============================================================================

@doc("Workflow execution entity for tracking multi-step agent workflows")
@TypeSpec.OpenAPI.extension("x-duckdb-table", "workflow_executions")
@TypeSpec.OpenAPI.extension("x-csharp-type", "WorkflowExecutionEntity")
model WorkflowExecutionEntity {
  // === Identifiers ===

  @doc("Unique execution identifier")
  @key
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "execution_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-primary-key", true)
  executionId: string;

  @doc("Associated OTel trace identifier")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "trace_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_workflow_executions_trace_id")
  traceId?: TraceId;

  // === Workflow Identity ===

  @doc("Workflow name identifier")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "workflow_name")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_workflow_executions_name")
  workflowName: string;

  @doc("What triggered the workflow")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "trigger")
  trigger: WorkflowTrigger;

  // === Execution State ===

  @doc("Execution status")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "status")
  status: WorkflowExecutionStatus;

  // === I/O ===

  @doc("Workflow input as JSON")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "input_json")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR")
  inputJson?: string;

  @doc("Workflow output as JSON")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "output_json")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR")
  outputJson?: string;

  // === Token Usage (OTel gen_ai.usage.*) ===

  @doc("Total input tokens - OTel: gen_ai.usage.input_tokens")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "gen_ai_input_tokens")
  genAiInputTokens?: TokenCount;

  @doc("Total output tokens - OTel: gen_ai.usage.output_tokens")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "gen_ai_output_tokens")
  genAiOutputTokens?: TokenCount;

  @doc("Estimated cost in USD")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "gen_ai_cost_usd")
  genAiCostUsd?: CostUsd;

  // === Progress ===

  @doc("Total number of workflow nodes")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "node_count")
  nodeCount?: int32;

  @doc("Number of completed nodes")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "completed_nodes")
  completedNodes?: int32;

  // === Timing ===

  @doc("Start timestamp in nanoseconds since epoch")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "start_time_unix_nano")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_workflow_executions_start_time")
  startTimeUnixNano: int64;

  @doc("End timestamp in nanoseconds since epoch")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "end_time_unix_nano")
  endTimeUnixNano?: int64;

  @doc("Duration in nanoseconds")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "duration_ns")
  durationNs?: DurationNs;

  // === Error ===

  @doc("Error message if failed")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "error_message")
  errorMessage?: string;

  // === Internal ===

  @doc("Row creation timestamp")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "created_at")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "TIMESTAMP DEFAULT now()")
  @TypeSpec.OpenAPI.extension("x-internal", true)
  createdAt?: utcDateTime;
}
