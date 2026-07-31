import "@typespec/events";
import "@typespec/http";
import "@typespec/sse";

import "../common/errors.tsp";
import "../models/workflow.tsp";
import "./routes.tsp";

using TypeSpec.Events;
using TypeSpec.Http;
using TypeSpec.SSE;

using Qyl.Api.Contracts.Common.Errors;
using Qyl.Api.Contracts.Workflow;

namespace Qyl.Api.Contracts.Workflow;

@doc("Keep-alive emitted while a workflow event stream has no new event.")
model WorkflowHeartbeatEvent {
  type: "heartbeat";

  @encodedName("application/json", "high_water_mark")
  highWaterMark: WorkflowJournalPosition;

  timestamp: utcDateTime;
}

@doc("Signals that the requested cursor predates retained workflow history.")
model WorkflowCursorGapEvent {
  type: "cursor_gap";

  @encodedName("application/json", "oldest_available_sequence")
  oldestAvailableSequence: WorkflowJournalPosition;

  @encodedName("application/json", "high_water_mark")
  highWaterMark: WorkflowJournalPosition;

  timestamp: utcDateTime;
}

@events
union WorkflowStreamEvents {
  event: WorkflowJournalEvent,
  heartbeat: WorkflowHeartbeatEvent,
  cursorGap: WorkflowCursorGapEvent,
}

@doc("Which opaque graph cursor was rejected.")
enum WorkflowCursorKind {
  node: "node",
  edge: "edge",
}

@doc("Why an opaque graph cursor cannot be reused for this request.")
enum WorkflowCursorFailureReason {
  invalid: "invalid",
  wrongRun: "wrong_run",
  wrongGeneration: "wrong_generation",
  stale: "stale",
}

@doc("Opaque graph cursor is malformed, belongs to another run, or targets a stale generation.")
@error
model WorkflowCursorError extends ProblemDetails {
  @statusCode _: 409;
  title: "Invalid Workflow Cursor";

  @encodedName("application/json", "cursor_kind")
  cursorKind: WorkflowCursorKind;

  reason: WorkflowCursorFailureReason;

  @encodedName("application/json", "current_generation")
  currentGeneration?: WorkflowGeneration;
}

@doc("Workflow run was durably deleted and can no longer accept events or publish projections.")
@error
model WorkflowRunDeletedError extends ProblemDetails {
  @statusCode _: 410;
  title: "Workflow Run Deleted";

  @encodedName("application/json", "run_id")
  runId: WorkflowRunId;
}

@doc("Workflow projection is rebuilding or temporarily unavailable after a retryable storage failure.")
@error
model WorkflowProjectionUnavailableError extends ProblemDetails {
  @statusCode _: 503;
  title: "Workflow Projection Unavailable";

  @header("Retry-After")
  @encodedName("application/json", "retry_after")
  retryAfter: int32;

  @encodedName("application/json", "projection_status")
  projectionStatus: WorkflowProjectionStatus;
}

@doc("Workflow projection is non-retryably corrupt or incompatible. Internal storage details are intentionally omitted.")
@error
model WorkflowProjectionCorruptError extends ProblemDetails {
  @statusCode _: 500;
  title: "Workflow Projection Corrupt";
  @encodedName("application/json", "projection_status")
  projectionStatus: WorkflowProjectionStatus;
}

@route("/api/v1/workflow-runs")
@tag("Workflow runs")
@useAuth(Qyl.Api.Contracts.QylApiKeyHeaderAuth)
interface WorkflowRunsApi {
  @post
  create(
    ...Qyl.Api.Contracts.ProjectScopeHeader,
    @body request: WorkflowRunCreateRequest,
  ):
    | WorkflowRun
    | ValidationError
    | UnauthorizedError
    | ConflictError
    | WorkflowRunDeletedError
    | ServiceUnavailableError
    | InternalServerError;

  @get
  list(
    ...Qyl.Api.Contracts.ProjectScopeHeader,
    @query status?: WorkflowRunStatus,
    @query
    @minValue(1)
    @maxValue(200)
    limit?: int32 = 50,
    @doc("Opaque continuation scoped to the project and status filter. Reuse it unchanged from next_cursor; do not parse, construct, or modify it.")
    @query cursor?: WorkflowRunCursor,
  ):
    | WorkflowRunPage
    | ValidationError
    | UnauthorizedError
    | ServiceUnavailableError
    | InternalServerError;

  @get
  @route("/{run_id}")
  get(
    ...Qyl.Api.Contracts.ProjectScopeHeader,
    @path("run_id") runId: WorkflowRunId,
  ):
    | WorkflowRun
    | UnauthorizedError
    | NotFoundError
    | WorkflowRunDeletedError
    | ServiceUnavailableError
    | InternalServerError;

  @post
  @route("/{run_id}/events")
  appendEvents(
    ...Qyl.Api.Contracts.ProjectScopeHeader,
    @path("run_id") runId: WorkflowRunId,
    @body request: WorkflowEventBatchAppendRequest,
  ):
    | WorkflowEventBatchAppendResponse
    | ValidationError
    | UnauthorizedError
    | NotFoundError
    | WorkflowRunDeletedError
    | ConflictError
    | ServiceUnavailableError
    | InternalServerError;

  @get
  @route("/{run_id}/events")
  readEvents(
    ...Qyl.Api.Contracts.ProjectScopeHeader,
    @path("run_id") runId: WorkflowRunId,
    @query("after_sequence") afterSequence?: WorkflowJournalPosition,
    @query
    @minValue(1)
    @maxValue(1000)
    limit?: int32 = 250,
    @query("wait_ms")
    @minValue(0)
    @maxValue(30000)
    waitMs?: int32 = 0,
  ):
    | WorkflowEventPage
    | ValidationError
    | UnauthorizedError
    | NotFoundError
    | WorkflowRunDeletedError
    | ServiceUnavailableError
    | InternalServerError;

  @get
  @route("/{run_id}/graph")
  getGraph(
    ...Qyl.Api.Contracts.ProjectScopeHeader,
    @path("run_id") runId: WorkflowRunId,
    @doc("Opaque node continuation. Reuse it unchanged from the preceding snapshot's next_node_cursor; do not parse, construct, or modify it.")
    @query("node_cursor") nodeCursor?: WorkflowNodeCursor,
    @query("node_limit")
    @minValue(1)
    @maxValue(1000)
    nodeLimit?: int32 = 250,
    @doc("Opaque edge continuation. Reuse it unchanged from the preceding snapshot's next_edge_cursor; do not parse, construct, or modify it.")
    @query("edge_cursor") edgeCursor?: WorkflowEdgeCursor,
    @query("edge_limit")
    @minValue(1)
    @maxValue(2000)
    edgeLimit?: int32 = 500,
  ):
    | WorkflowGraphSnapshot
    | ValidationError
    | UnauthorizedError
    | NotFoundError
    | WorkflowRunDeletedError
    | WorkflowCursorError
    | WorkflowProjectionUnavailableError
    | WorkflowProjectionCorruptError;

  @get
  @route("/{run_id}/content/{content_ref}")
  getContent(
    ...Qyl.Api.Contracts.ProjectScopeHeader,
    @path("run_id") runId: WorkflowRunId,
    @path("content_ref") contentRef: WorkflowContentRef,
  ):
    | WorkflowContent
    | UnauthorizedError
    | NotFoundError
    | WorkflowRunDeletedError
    | ServiceUnavailableError
    | InternalServerError;

  @get
  @route("/{run_id}/stream")
  stream(
    ...Qyl.Api.Contracts.ProjectScopeHeader,
    @path("run_id") runId: WorkflowRunId,
    @header("Last-Event-ID") lastEventId?: string,
  ):
    | SSEStream<WorkflowStreamEvents>
    | ValidationError
    | UnauthorizedError
    | NotFoundError
    | WorkflowRunDeletedError
    | ServiceUnavailableError
    | InternalServerError;

  @post
  @route("/{run_id}/commands")
  submitControl(
    ...Qyl.Api.Contracts.ProjectScopeHeader,
    @path("run_id") runId: WorkflowRunId,
    @body request: WorkflowControlRequest,
  ):
    | WorkflowControlCommand
    | ValidationError
    | UnauthorizedError
    | NotFoundError
    | WorkflowRunDeletedError
    | ConflictError
    | ServiceUnavailableError
    | InternalServerError;

  @get
  @route("/{run_id}/commands")
  pollControls(
    ...Qyl.Api.Contracts.ProjectScopeHeader,
    @path("run_id") runId: WorkflowRunId,
    @query("after_sequence") afterSequence?: WorkflowSequence,
    @query
    @minValue(1)
    @maxValue(100)
    limit?: int32 = 20,
    @query("wait_ms")
    @minValue(0)
    @maxValue(30000)
    waitMs?: int32 = 0,
  ):
    | WorkflowControlCommandPage
    | ValidationError
    | UnauthorizedError
    | NotFoundError
    | WorkflowRunDeletedError
    | ServiceUnavailableError
    | InternalServerError;

  @post
  @route("/{run_id}/commands/{command_id}/status")
  updateControl(
    ...Qyl.Api.Contracts.ProjectScopeHeader,
    @path("run_id") runId: WorkflowRunId,
    @path("command_id") commandId: WorkflowCommandId,
    @body request: WorkflowControlStatusUpdateRequest,
  ):
    | WorkflowControlCommand
    | ValidationError
    | UnauthorizedError
    | NotFoundError
    | WorkflowRunDeletedError
    | ConflictError
    | ServiceUnavailableError
    | InternalServerError;
}
