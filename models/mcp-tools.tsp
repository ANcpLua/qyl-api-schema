import "../common/types.tsp";
import "../otel/logs.tsp";
import "../otel/span.tsp";
import "./session.tsp";

using Qyl.Api.Contracts.Common;
using Qyl.Api.Contracts.Domains.Observe.Session;
using Qyl.Api.Contracts.OTel.Logs;
using Qyl.Api.Contracts.OTel.Traces;

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
