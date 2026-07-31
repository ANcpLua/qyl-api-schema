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
  highWaterMark: WorkflowSequence;

  timestamp: utcDateTime;
}

@doc("Signals that the requested cursor predates retained workflow history.")
model WorkflowCursorGapEvent {
  type: "cursor_gap";

  @encodedName("application/json", "oldest_available_sequence")
  oldestAvailableSequence: WorkflowSequence;

  @encodedName("application/json", "high_water_mark")
  highWaterMark: WorkflowSequence;

  timestamp: utcDateTime;
}

@events
union WorkflowStreamEvents {
  event: WorkflowJournalEvent,
  heartbeat: WorkflowHeartbeatEvent,
  cursorGap: WorkflowCursorGapEvent,
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
    @query cursor?: string,
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
    | ConflictError
    | ServiceUnavailableError
    | InternalServerError;

  @get
  @route("/{run_id}/events")
  readEvents(
    ...Qyl.Api.Contracts.ProjectScopeHeader,
    @path("run_id") runId: WorkflowRunId,
    @query("after_sequence") afterSequence?: WorkflowSequence,
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
    | ServiceUnavailableError
    | InternalServerError;

  @get
  @route("/{run_id}/graph")
  getGraph(
    ...Qyl.Api.Contracts.ProjectScopeHeader,
    @path("run_id") runId: WorkflowRunId,
    @doc("Opaque node continuation. Reuse it unchanged from the preceding snapshot's next_node_cursor; do not parse, construct, or modify it.")
    @query("node_cursor") nodeCursor?: WorkflowNodeId,
    @query("node_limit")
    @minValue(1)
    @maxValue(1000)
    nodeLimit?: int32 = 250,
    @doc("Opaque edge continuation. Reuse it unchanged from the preceding snapshot's next_edge_cursor; do not parse, construct, or modify it.")
    @query("edge_cursor") edgeCursor?: WorkflowEdgeId,
    @query("edge_limit")
    @minValue(1)
    @maxValue(2000)
    edgeLimit?: int32 = 500,
  ):
    | WorkflowGraphSnapshot
    | ValidationError
    | UnauthorizedError
    | NotFoundError
    | ServiceUnavailableError
    | InternalServerError;

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
    | ConflictError
    | ServiceUnavailableError
    | InternalServerError;
}
