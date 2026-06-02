// =============================================================================
// ANcpLua v2.0 - Workflow Checkpoint Storage Model (OTel v1.40)
// =============================================================================
// Checkpoint state persistence for workflow execution recovery.
// Enables resume-from-checkpoint after failures or cancellations.
// =============================================================================

import "@typespec/openapi";
import "../../common/types.tsp";

using TypeSpec.OpenAPI;
using Qyl.Api.Contracts.Common;

namespace Qyl.Api.Contracts.Domains.Agent.Checkpoint;

// =============================================================================
// Workflow Checkpoint Entity - Storage Model
// =============================================================================

@doc("Workflow checkpoint entity for persisting workflow node state for recovery")
@TypeSpec.OpenAPI.extension("x-duckdb-table", "workflow_checkpoints")
@TypeSpec.OpenAPI.extension("x-csharp-type", "WorkflowCheckpointEntity")
model WorkflowCheckpointEntity {
  // === Identifiers ===

  @doc("Unique checkpoint identifier")
  @key
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "checkpoint_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-primary-key", true)
  checkpointId: string;

  @doc("Parent workflow execution identifier")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "execution_id")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_checkpoints_execution_id")
  executionId: string;

  // === Node State ===

  @doc("Workflow node identifier")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "node_id")
  nodeId: string;

  @doc("Serialized node state as JSON")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "state_json")
  @TypeSpec.OpenAPI.extension("x-duckdb-type", "VARCHAR")
  stateJson: string;

  // === Ordering ===

  @doc("Checkpoint sequence number within the execution")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "sequence_number")
  @minValue(0)
  sequenceNumber: int32;

  // === Timing ===

  @doc("Checkpoint creation time in nanoseconds since epoch")
  @TypeSpec.OpenAPI.extension("x-duckdb-column", "created_at_unix_nano")
  @TypeSpec.OpenAPI.extension("x-duckdb-index", "idx_checkpoints_created_at")
  createdAtUnixNano: int64;
}
