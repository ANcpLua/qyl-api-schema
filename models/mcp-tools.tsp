import "../common/types.tsp";
import "../otel/logs.tsp";
import "../otel/span.tsp";
import "./session.tsp";
import "./metrics.tsp";
import "./annotations.tsp";
import "./saved-queries.tsp";
import "../common/resource.tsp";

using TypeSpec.OpenAPI;
using Qyl.Api.Contracts.Common;
using Qyl.Api.Contracts.Annotations;
using Qyl.Api.Contracts.SavedQueries;
using Qyl.Api.Contracts.OTel.Metrics;
using Qyl.Api.Contracts.Domains.Observe.Session;
using Qyl.Api.Contracts.OTel.Logs;
using Qyl.Api.Contracts.OTel.Traces;

namespace Qyl.Api.Contracts.Mcp.Tools;

@doc("Whether a qyl MCP tool read live collector data or the explicit demo dataset.")
enum McpDataMode {
  live: "live",
  demo: "demo",
}

@doc("""
  OAuth scopes of the qyl MCP server. `qyl:read` alone keeps the read-only
  tool surface; `qyl:write` adds the create and update tools; `qyl:delete`
  adds the one delete tool. No scope deletes telemetry.
  """)
enum McpScope {
  read: "qyl:read",
  write: "qyl:write",
  delete: "qyl:delete",
}

@doc("Stable failure code of a qyl MCP tool result. A model branches on the code, never on the message.")
union ToolErrorCode {
  invalidArgument: "invalid_argument",
  notFound: "not_found",
  noProjectAccess: "no_project_access",
  collectorUnreachable: "collector_unreachable",
  collectorTimeout: "collector_timeout",
  cancelled: "cancelled",
  collectorUnauthorized: "collector_unauthorized",
  collectorRateLimited: "collector_rate_limited",
  collectorRejected: "collector_rejected",
  collectorError: "collector_error",
  contractMismatch: "contract_mismatch",

  @doc("The token lacks the scope the tool needs: qyl:write or qyl:delete.")
  insufficientScope: "insufficient_scope",

  @doc("HTTP 409: the change conflicts with existing state, e.g. a duplicate saved-query name.")
  conflict: "conflict",

  @doc("HTTP 412: the etag is stale; re-read the resource and retry with its current etag.")
  preconditionFailed: "precondition_failed",

  @doc("HTTP 428: the request carried no etag.")
  preconditionRequired: "precondition_required",

  internal: "internal",
}

@doc("A failed tool call, carried in structuredContent.error.")
model ToolError {
  code: ToolErrorCode;

  @doc("Human-readable description of this failure.")
  message: string;

  @doc("Whether the same call can succeed when repeated unchanged.")
  retryable: boolean;
}

@doc("Pagination members of a paged tool output.")
model ToolPage {
  @doc("Whether more items exist beyond this page. False only when the result is complete; `next_cursor` is present exactly when this is true.")
  @encodedName("application/json", "has_more")
  hasMore: boolean;

  @doc("Pass as `cursor` to the same tool with the same filters for the next page. Absent on the last page.")
  @encodedName("application/json", "next_cursor")
  nextCursor?: Cursor;
}

@doc("Time-range members of a tool input.")
model ToolTimeRange {
  @doc("Start of the window (inclusive), RFC 3339.")
  @encodedName("application/json", "start_time")
  startTime?: utcDateTime;

  @doc("End of the window (exclusive), RFC 3339.")
  @encodedName("application/json", "end_time")
  endTime?: utcDateTime;
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
  @doc("Open this trace selected; omit to list recent traces.")
  @encodedName("application/json", "trace_id")
  traceId?: TraceId;

  @doc("List only the traces of this session.")
  @encodedName("application/json", "session_id")
  sessionId?: SessionId;

  @doc("Maximum traces to list.")
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

  @doc("Set when the call failed.")
  error?: ToolError;
}

@doc("Input for display_mcp_dashboard.")
model DisplayMcpDashboardInput {
  @doc("Window length in whole hours.")
  @minValue(1)
  @maxValue(168)
  hours?: int32 = 24;
}

@doc("Structured output for display_mcp_dashboard.")
model DisplayMcpDashboardOutput {
  stats: McpDashboardStats;

  @doc("Set when the call failed.")
  error?: ToolError;
}

@doc("Input for list_traces.")
model ListTracesInput {
  @doc("Maximum traces to return in this page.")
  @minValue(1)
  @maxValue(100)
  limit?: int32 = 20;

  ...ToolTimeRange;

  @doc("Keep traces with at least one span from this service.")
  @encodedName("application/json", "service_name")
  serviceName?: string;

  @doc("Keep only traces with at least one error span.")
  @encodedName("application/json", "errors_only")
  errorsOnly?: boolean;

  @doc("`next_cursor` of a previous list_traces call with the same filters.")
  cursor?: Cursor;
}

@doc("Structured output for list_traces.")
model ListTracesOutput {
  traces: TraceSummary[];
  mode: McpDataMode;
  ...ToolPage;

  @doc("Set when the call failed.")
  error?: ToolError;
}

@doc("Input for get_trace.")
model GetTraceInput {
  @encodedName("application/json", "trace_id")
  traceId: TraceId;

  @doc("Return only spans with error status; omitted or false includes all span statuses.")
  @encodedName("application/json", "errors_only")
  errorsOnly?: boolean = false;

  @doc("Maximum spans to return after filtering; omit to keep all matching spans.")
  @encodedName("application/json", "max_spans")
  @minValue(1)
  @maxValue(1000)
  maxSpans?: int32;

  @doc("Include span, resource, event and link attributes; false omits those attribute collections.")
  @encodedName("application/json", "include_attributes")
  includeAttributes?: boolean = true;
}

@doc("Structured output for get_trace.")
model GetTraceOutput {
  trace: Trace;
  mode: McpDataMode;

  @doc("Annotations on the trace and its spans, newest first.")
  annotations?: Annotation[];

  @doc("Set when the call failed.")
  error?: ToolError;
}

@doc("Input for list_sessions.")
model ListSessionsInput {
  @doc("Maximum sessions to return in this page.")
  @minValue(1)
  @maxValue(100)
  limit?: int32 = 20;

  @doc("Return only sessions that are still active; omitted or false includes ended sessions.")
  @encodedName("application/json", "active_only")
  activeOnly?: boolean;

  ...ToolTimeRange;

  @doc("`next_cursor` of a previous list_sessions call with the same filters.")
  cursor?: Cursor;
}

@doc("Structured output for list_sessions.")
model ListSessionsOutput {
  sessions: SessionEntity[];
  mode: McpDataMode;
  ...ToolPage;

  @doc("Annotations on the listed sessions, newest first; each names its session in `target`.")
  annotations?: Annotation[];

  @doc("Set when the call failed.")
  error?: ToolError;
}

@doc("Input for search_logs.")
model SearchLogsInput {
  @doc("Return only log records correlated with this trace.")
  @encodedName("application/json", "trace_id")
  traceId?: TraceId;

  @doc("Return only log records from this service.")
  @encodedName("application/json", "service_name")
  serviceName?: string;

  @doc("Minimum OpenTelemetry severity number: 9 info, 13 warn, 17 error.")
  @encodedName("application/json", "severity_min")
  @minValue(1)
  @maxValue(24)
  severityMin?: int32;

  @doc("Substring searched in the log body.")
  query?: string;

  @doc("Maximum log records to return in this page.")
  @minValue(1)
  @maxValue(200)
  limit?: int32 = 50;

  @doc("Return only log records of this session.")
  @encodedName("application/json", "session_id")
  sessionId?: SessionId;

  ...ToolTimeRange;

  @doc("`next_cursor` of a previous search_logs call with the same filters.")
  cursor?: Cursor;
}

@doc("Structured output for search_logs.")
model SearchLogsOutput {
  logs: LogRecord[];
  mode: McpDataMode;
  ...ToolPage;

  @doc("Set when the call failed.")
  error?: ToolError;
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

  @doc("Case-sensitive service-name prefix identifying CI telemetry in both run lists and phase breakdowns.")
  @encodedName("application/json", "service_prefix")
  @minLength(1)
  @maxLength(256)
  servicePrefix?: string = "qyl-ci";

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

  @doc("Set when the call failed.")
  error?: ToolError;
}

@doc("fetch_telemetry input for the trace list (view `traces`).")
model FetchTelemetryTracesInput {
  view: "traces";

  @doc("Return this one trace as the list, selected.")
  @encodedName("application/json", "trace_id")
  traceId?: TraceId;

  @minValue(1)
  @maxValue(200)
  limit?: int32;
}

@doc("fetch_telemetry input for one trace (view `trace`).")
model FetchTelemetryTraceInput {
  view: "trace";

  @encodedName("application/json", "trace_id")
  traceId: TraceId;
}

@doc("fetch_telemetry input for log records (view `logs`).")
model FetchTelemetryLogsInput {
  view: "logs";

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
}

@doc("fetch_telemetry input for MCP traffic statistics (view `mcp_stats`).")
model FetchTelemetryMcpStatsInput {
  view: "mcp_stats";

  @doc("Window length in whole hours.")
  @minValue(1)
  @maxValue(168)
  hours?: int32;
}

@doc("Input for the app-only fetch_telemetry tool: exactly one view and the members that view takes.")
@discriminated(#{ envelope: "none", discriminatorPropertyName: "view" })
union FetchTelemetryInput {
  traces: FetchTelemetryTracesInput,
  trace: FetchTelemetryTraceInput,
  logs: FetchTelemetryLogsInput,
  mcp_stats: FetchTelemetryMcpStatsInput,
}

@doc("Structured output for the app-only fetch_telemetry tool.")
model FetchTelemetryOutput {
  traces?: Trace[];
  trace?: Trace;
  logs?: LogRecord[];
  stats?: McpDashboardStats;
  mode: McpDataMode;

  @doc("Set when the call failed.")
  error?: ToolError;
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

  @doc("Bucket width in integer milliseconds.")
  @encodedName("application/json", "bucket_ms")
  @minValue(0)
  bucketMs: int64;
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

// -----------------------------------------------------------------------------
// Metric tools: list_metrics, get_metric_series, query_metric
// -----------------------------------------------------------------------------

@doc("Input for list_metrics.")
model ListMetricsInput {
  @doc("Return only names starting with this prefix.")
  @encodedName("application/json", "name_prefix")
  namePrefix?: string;

  @minValue(1)
  @maxValue(1000)
  limit?: int32 = 200;

  @doc("`next_cursor` of a previous list_metrics call with the same prefix.")
  cursor?: Cursor;
}

@doc("Structured output for list_metrics.")
model ListMetricsOutput {
  items: MetricDescriptor[];
  ...ToolPage;

  @doc("Set when the call failed.")
  error?: ToolError;
}

@doc("Input for get_metric_series.")
model GetMetricSeriesInput {
  @encodedName("application/json", "metric_name")
  @minLength(1)
  metricName: string;

  @doc("Attribute matchers a series must all satisfy; serialized to `attr` and `attr_prefix`.")
  @maxItems(32)
  matchers?: MetricAttributeMatcher[];

  @minValue(1)
  @maxValue(1000)
  limit?: int32 = 200;

  @doc("`next_cursor` of a previous get_metric_series call with the same filters.")
  cursor?: Cursor;
}

@doc("Structured output for get_metric_series.")
model GetMetricSeriesOutput {
  items: MetricSeries[];
  ...ToolPage;

  @doc("Set when the call failed.")
  error?: ToolError;
}

@doc("Input for query_metric.")
model QueryMetricInput {
  @encodedName("application/json", "metric_name")
  @minLength(1)
  metricName: string;

  @encodedName("application/json", "start_time")
  startTime: utcDateTime;

  @encodedName("application/json", "end_time")
  endTime: utcDateTime;

  @doc("Bucket width in integer milliseconds.")
  @encodedName("application/json", "step_ms")
  @minValue(1)
  @maxValue(86400000)
  stepMs?: int64 = 60000;

  aggregation?: MetricAggregation = MetricAggregation.avg;

  @doc("Attribute keys to split the result by.")
  @encodedName("application/json", "group_by")
  @maxItems(16)
  groupBy?: string[];

  @doc("Attribute matchers a series must all satisfy; serialized to `attr` and `attr_prefix`.")
  @maxItems(32)
  matchers?: MetricAttributeMatcher[];

  @encodedName("application/json", "series_limit")
  @minValue(1)
  @maxValue(500)
  seriesLimit?: int32 = 50;
}

@doc("Structured output for query_metric: the collector's range-query result.")
model QueryMetricOutput {
  ...MetricQueryResult;

  @doc("Set when the call failed.")
  error?: ToolError;
}

// -----------------------------------------------------------------------------
// Write tools (scope qyl:write; delete needs qyl:delete)
// -----------------------------------------------------------------------------

@doc("Input for create_annotation.")
model CreateAnnotationInput {
  ...AnnotationCreateRequest;
}

@doc("Input for update_annotation.")
model UpdateAnnotationInput {
  id: ResourceId;

  @doc("The annotation's current `etag`, sent as If-Match.")
  etag: ETag;

  ...AnnotationUpdateRequest;
}

@doc("Structured output for create_annotation and update_annotation.")
model AnnotationOutput {
  annotation?: Annotation;

  @doc("Set when the call failed.")
  error?: ToolError;
}

@doc("Input for create_saved_query.")
model CreateSavedQueryInput {
  ...SavedQueryCreateRequest;
}

@doc("Input for update_saved_query.")
model UpdateSavedQueryInput {
  id: ResourceId;

  @doc("The saved query's current `etag`, sent as If-Match.")
  etag: ETag;

  ...SavedQueryUpdateRequest;
}

@doc("Structured output for create_saved_query and update_saved_query.")
model SavedQueryOutput {
  @encodedName("application/json", "saved_query")
  savedQuery?: SavedQuery;

  @doc("Set when the call failed.")
  error?: ToolError;
}

@doc("Input for list_saved_queries.")
model ListSavedQueriesInput {
  signal?: SavedQuerySignal;

  @minValue(1)
  @maxValue(100)
  limit?: int32 = 20;

  cursor?: Cursor;
}

@doc("Structured output for list_saved_queries.")
model ListSavedQueriesOutput {
  @encodedName("application/json", "saved_queries")
  savedQueries: SavedQuery[];

  ...ToolPage;

  @doc("Set when the call failed.")
  error?: ToolError;
}

@doc("Input for run_saved_query.")
model RunSavedQueryInput {
  id: ResourceId;
  ...SavedQueryRunRequest;
}

@doc("Structured output for run_saved_query.")
model RunSavedQueryOutput {
  result?: SavedQueryRunResult;
  mode?: McpDataMode;

  @doc("Set when the call failed.")
  error?: ToolError;
}

@doc("The user-created resource kinds the delete tool accepts.")
enum DeletableKind {
  annotation: "annotation",
  savedQuery: "saved_query",
}

@doc("Input for the delete tool. Telemetry is never deletable.")
model DeleteInput {
  kind: DeletableKind;
  id: ResourceId;

  @doc("The resource's current `etag`, sent as If-Match.")
  etag: ETag;
}

@doc("Structured output for the delete tool.")
model DeleteOutput {
  deleted: boolean;

  @doc("Set when the call failed.")
  error?: ToolError;
}
