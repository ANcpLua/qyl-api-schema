import "../common/types.tsp";
import "../otel/logs.tsp";
import "../otel/span.tsp";
import "./session.tsp";
import "./workflow.tsp";

using Qyl.Api.Contracts.Common;
using Qyl.Api.Contracts.Domains.Observe.Session;
using Qyl.Api.Contracts.OTel.Logs;
using Qyl.Api.Contracts.OTel.Traces;
using Qyl.Api.Contracts.Workflow;

namespace Qyl.Api.Contracts.Mcp.Tools;

@doc("Whether a qyl MCP tool read live collector data or the explicit demo dataset.")
enum McpDataMode {
  live: "live",
  demo: "demo",
}

@doc("Data projection requested by the app-only fetch_telemetry tool.")
enum FetchTelemetryView {
  traces: "traces",
  trace: "trace",
  logs: "logs",
  mcpStats: "mcp_stats",
}

@doc("Input for display_traces.")
model DisplayTracesInput {
  @encodedName("application/json", "trace_id")
  traceId?: TraceId;
  @encodedName("application/json", "session_id")
  sessionId?: SessionId;
  @minValue(1)
  @maxValue(100)
  limit?: int32 = 20;
}

@doc("Structured output for display_traces.")
model DisplayTracesOutput {
  traces: Trace[];
  @encodedName("application/json", "selected_trace_id")
  selectedTraceId?: TraceId;
  mode: McpDataMode;
}

@doc("Input for display_mcp_dashboard.")
model DisplayMcpDashboardInput {
  @minValue(1)
  @maxValue(168)
  hours?: float64 = 24;
}

@doc("Structured output for display_mcp_dashboard.")
model DisplayMcpDashboardOutput {
  stats: McpDashboardStats;
}

@doc("Input for list_traces.")
model ListTracesInput {
  @minValue(1)
  @maxValue(100)
  limit?: int32 = 20;
}

@doc("Structured output for list_traces.")
model ListTracesOutput {
  traces: TraceSummary[];
  mode: McpDataMode;
}

@doc("Input for get_trace.")
model GetTraceInput {
  @encodedName("application/json", "trace_id")
  traceId: TraceId;
}

@doc("Structured output for get_trace.")
model GetTraceOutput {
  trace: Trace;
  mode: McpDataMode;
}

@doc("Input for list_sessions.")
model ListSessionsInput {
  @minValue(1)
  @maxValue(100)
  limit?: int32 = 20;
  @encodedName("application/json", "active_only")
  activeOnly?: boolean;
}

@doc("Structured output for list_sessions.")
model ListSessionsOutput {
  sessions: SessionEntity[];
  mode: McpDataMode;
}

@doc("Input for search_logs.")
model SearchLogsInput {
  @encodedName("application/json", "trace_id")
  traceId?: TraceId;
  @encodedName("application/json", "service_name")
  serviceName?: string;
  @encodedName("application/json", "severity_min")
  @minValue(1)
  @maxValue(24)
  severityMin?: int32;
  query?: string;
  @minValue(1)
  @maxValue(200)
  limit?: int32 = 50;
}

@doc("Structured output for search_logs.")
model SearchLogsOutput {
  logs: LogRecord[];
  mode: McpDataMode;
}

@doc("Outcome of one CI phase span, projected from its OpenTelemetry span status.")
enum CiPhaseStatus {
  ok: "ok",
  error: "error",
  unset: "unset",
}

@doc("Input for ci_log.")
model CiLogInput {
  @doc("Session id of one CI run for a per-leg phase breakdown; omit to list recent runs.")
  @encodedName("application/json", "run_id")
  runId?: SessionId;

  @doc("Maximum CI runs to list.")
  @minValue(1)
  @maxValue(50)
  limit?: int32 = 10;
}

@doc("One CI run, summarized from the session its telemetry is grouped under.")
model CiRunSummary {
  @encodedName("application/json", "run_id")
  runId: SessionId;

  state: SessionState;

  @encodedName("application/json", "start_time")
  startTime: utcDateTime;

  @encodedName("application/json", "duration_ms")
  durationMs?: DurationMs;

  @doc("Spans in the run that ended with an error status.")
  @encodedName("application/json", "error_count")
  @minValue(0)
  errorCount: int32;

  @doc("Service names observed in the run, at least one of which is CI-emitted.")
  services: string[];
}

@doc("One phase span of a CI run, attributed to the leg that executed it.")
model CiPhase {
  @doc("Value of the span's ci.leg attribute, falling back to its service name.")
  leg: string;

  @doc("Span name, which the CI emitter convention sets to the phase name.")
  phase: string;

  status: CiPhaseStatus;

  @encodedName("application/json", "duration_ms")
  durationMs: DurationMs;

  @doc("Span status message, present on a failed phase.")
  message?: string;
}

@doc("Structured output for ci_log: recent runs, or one run's phases.")
model CiLogOutput {
  runs?: CiRunSummary[];

  @encodedName("application/json", "run_id")
  runId?: SessionId;

  phases?: CiPhase[];

  mode: McpDataMode;
}

@doc("Input for the app-only fetch_telemetry tool.")
model FetchTelemetryInput {
  view: FetchTelemetryView;
  @encodedName("application/json", "trace_id")
  traceId?: TraceId;
  @encodedName("application/json", "service_name")
  serviceName?: string;
  @encodedName("application/json", "severity_min")
  @minValue(1)
  @maxValue(24)
  severityMin?: int32;
  query?: string;
  @minValue(1)
  @maxValue(200)
  limit?: int32;
  @minValue(1)
  @maxValue(168)
  hours?: float64;
}

@doc("Structured output for the app-only fetch_telemetry tool.")
model FetchTelemetryOutput {
  traces?: Trace[];
  trace?: Trace;
  logs?: LogRecord[];
  stats?: McpDashboardStats;
  mode: McpDataMode;
}

@doc("Input for list_workflow_runs.")
model ListWorkflowRunsInput {
  status?: WorkflowRunStatus;

  cursor?: WorkflowRunCursor;

  @minValue(1)
  @maxValue(100)
  limit?: int32 = 20;
}

@doc("Structured output for list_workflow_runs.")
model ListWorkflowRunsOutput {
  runs: WorkflowRun[];

  @encodedName("application/json", "next_cursor")
  nextCursor?: WorkflowRunCursor;

  @encodedName("application/json", "has_more")
  hasMore: boolean;

  mode: McpDataMode;
}

@doc("Input for get_workflow_graph.")
model GetWorkflowGraphInput {
  @encodedName("application/json", "run_id")
  runId: WorkflowRunId;

  @doc("Opaque node continuation. Reuse it unchanged from the preceding snapshot's next_node_cursor; do not parse, construct, or modify it.")
  @encodedName("application/json", "node_cursor")
  nodeCursor?: WorkflowNodeCursor;

  @encodedName("application/json", "node_limit")
  @minValue(1)
  @maxValue(1000)
  nodeLimit?: int32 = 250;

  @doc("Opaque edge continuation. Reuse it unchanged from the preceding snapshot's next_edge_cursor; do not parse, construct, or modify it.")
  @encodedName("application/json", "edge_cursor")
  edgeCursor?: WorkflowEdgeCursor;

  @encodedName("application/json", "edge_limit")
  @minValue(1)
  @maxValue(2000)
  edgeLimit?: int32 = 500;
}

@doc("Structured output for get_workflow_graph.")
model GetWorkflowGraphOutput {
  graph: WorkflowGraphSnapshot;
  mode: McpDataMode;
}

@doc("Input for display_workflow_graph. Omit run_id to select the most recent run.")
model DisplayWorkflowGraphInput {
  @encodedName("application/json", "run_id")
  runId?: WorkflowRunId;

  @doc("Opaque node continuation. Reuse it unchanged from the preceding snapshot's next_node_cursor; do not parse, construct, or modify it.")
  @encodedName("application/json", "node_cursor")
  nodeCursor?: WorkflowNodeCursor;

  @encodedName("application/json", "node_limit")
  @minValue(1)
  @maxValue(1000)
  nodeLimit?: int32 = 250;

  @doc("Opaque edge continuation. Reuse it unchanged from the preceding snapshot's next_edge_cursor; do not parse, construct, or modify it.")
  @encodedName("application/json", "edge_cursor")
  edgeCursor?: WorkflowEdgeCursor;

  @encodedName("application/json", "edge_limit")
  @minValue(1)
  @maxValue(2000)
  edgeLimit?: int32 = 500;
}

@doc("Structured output for display_workflow_graph.")
model DisplayWorkflowGraphOutput {
  graph: WorkflowGraphSnapshot;

  @encodedName("application/json", "live_controls_available")
  liveControlsAvailable: boolean;

  mode: McpDataMode;
}

@doc("Input for the app-only fetch_workflow_graph_updates tool.")
model FetchWorkflowGraphUpdatesInput {
  @encodedName("application/json", "run_id")
  runId: WorkflowRunId;

  @encodedName("application/json", "after_sequence")
  afterSequence: WorkflowJournalPosition;

  @minValue(1)
  @maxValue(1000)
  limit?: int32 = 250;

  @encodedName("application/json", "wait_ms")
  @minValue(0)
  @maxValue(30000)
  waitMs?: int32 = 20000;

  @doc("Opaque node continuation. Reuse it unchanged from the preceding snapshot's next_node_cursor; do not parse, construct, or modify it.")
  @encodedName("application/json", "node_cursor")
  nodeCursor?: WorkflowNodeCursor;

  @encodedName("application/json", "node_limit")
  @minValue(1)
  @maxValue(1000)
  nodeLimit?: int32 = 250;

  @doc("Opaque edge continuation. Reuse it unchanged from the preceding snapshot's next_edge_cursor; do not parse, construct, or modify it.")
  @encodedName("application/json", "edge_cursor")
  edgeCursor?: WorkflowEdgeCursor;

  @encodedName("application/json", "edge_limit")
  @minValue(1)
  @maxValue(2000)
  edgeLimit?: int32 = 500;

  @doc("Optional captured payload to retrieve lazily for the selected run.")
  @encodedName("application/json", "content_ref")
  contentRef?: WorkflowContentRef;
}

@doc("Structured output for the app-only fetch_workflow_graph_updates tool.")
model FetchWorkflowGraphUpdatesOutput {
  page: WorkflowEventPage;
  graph?: WorkflowGraphSnapshot;
  content?: WorkflowContent;
  mode: McpDataMode;
}

@doc("Input for inspect_workflow_events.")
model InspectWorkflowEventsInput {
  @encodedName("application/json", "run_id")
  runId: WorkflowRunId;

  @encodedName("application/json", "after_sequence")
  afterSequence: WorkflowJournalPosition;

  @minValue(1)
  @maxValue(1000)
  limit?: int32 = 250;

  @doc("Optional captured payload to retrieve lazily for the selected run.")
  @encodedName("application/json", "content_ref")
  contentRef?: WorkflowContentRef;
}

@doc("Structured output for inspect_workflow_events.")
model InspectWorkflowEventsOutput {
  page: WorkflowEventPage;
  content?: WorkflowContent;
  mode: McpDataMode;
}

@doc("Input for control_workflow_run.")
model ControlWorkflowRunInput {
  @encodedName("application/json", "run_id")
  runId: WorkflowRunId;

  action: WorkflowControlAction;

  @encodedName("application/json", "idempotency_key")
  @minLength(1)
  @maxLength(160)
  idempotencyKey: string;

  @maxLength(32768)
  input?: string;
}

@doc("Structured output for control_workflow_run.")
model ControlWorkflowRunOutput {
  command: WorkflowControlCommand;
}

@doc("Aggregate MCP traffic statistics shown by qyl.mcp.")
model McpDashboardStats {
  window: McpDashboardWindow;
  buckets: McpDashboardBucket[];
  totals: McpDashboardTotals;
  @encodedName("application/json", "by_server")
  byServer: McpNameRequestCount[];
  @encodedName("application/json", "by_transport")
  byTransport: McpNameRequestCount[];
  @encodedName("application/json", "by_method")
  byMethod: McpNameRequestCount[];
  tools: McpToolStats[];
  @encodedName("application/json", "span_count_analyzed")
  @minValue(0)
  spanCountAnalyzed: int32;
  truncated: boolean;
  mode: McpDataMode;
}

model McpDashboardWindow {
  start: utcDateTime;
  end: utcDateTime;
  @encodedName("application/json", "bucket_ms")
  @minValue(0)
  bucketMs: float64;
}

model McpDashboardBucket {
  start: utcDateTime;
  @minValue(0)
  requests: int32;
  @minValue(0)
  errors: int32;
}

model McpDashboardTotals {
  @minValue(0)
  requests: int32;
  @minValue(0)
  errors: int32;
  @encodedName("application/json", "error_rate")
  @minValue(0)
  @maxValue(1)
  errorRate: float64;
}

model McpNameRequestCount {
  name: string;
  @minValue(0)
  requests: int32;
}

model McpToolStats {
  name: string;
  @minValue(0)
  requests: int32;
  @minValue(0)
  errors: int32;
  @encodedName("application/json", "error_rate")
  @minValue(0)
  @maxValue(1)
  errorRate: float64;
  @encodedName("application/json", "avg_ms")
  @minValue(0)
  avgMs: float64;
  @encodedName("application/json", "p95_ms")
  @minValue(0)
  p95Ms: float64;
}
