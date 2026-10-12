import "../common/telemetry-query.tsp";
// =============================================================================
// Saved queries: named, structured filters for traces, logs or metrics
// =============================================================================
// A saved query stores a filter, never results. `:run` evaluates it against
// the current telemetry with a window relative to the time of the run.
// Names are unique per project; a duplicate is refused with 409.
// =============================================================================

import "@typespec/http";
import "@typespec/openapi";
import "../common/types.tsp";
import "../common/pagination.tsp";
import "../common/resource.tsp";
import "../otel/enums.tsp";
import "../otel/span.tsp";
import "../otel/logs.tsp";
import "./metrics.tsp";

using TypeSpec.OpenAPI;
using Qyl.Api.Contracts.Common;
using Qyl.Api.Contracts.Common.Pagination;
using Qyl.Api.Contracts.OTel.Enums;
using Qyl.Api.Contracts.OTel.Logs;
using Qyl.Api.Contracts.OTel.Metrics;
using Qyl.Api.Contracts.OTel.Traces;

namespace Qyl.Api.Contracts.SavedQueries;

@doc("The telemetry signal a saved query reads.")
enum SavedQuerySignal {
  traces: "traces",
  logs: "logs",
  metrics: "metrics",
}

@doc("Look-back window shared by every saved-query filter.")
model SavedQueryWindow {
  @doc("Window ending at the time of the run, in minutes. Omitted, the run's own `start_time`/`end_time` or the last 60 minutes apply.")
  @encodedName("application/json", "lookback_minutes")
  @minValue(1)
  @maxValue(43200)
  lookbackMinutes?: int32;
}

@doc("A saved filter over traces.")
model SavedTraceQueryFilter {
  @maxItems(32)
  matchers?: TelemetryMatcher[];

  signal: "traces";
  ...SavedQueryWindow;

  @encodedName("application/json", "service_name")
  @minLength(1)
  @maxLength(256)
  serviceName?: string;

  @doc("Keep only traces with at least one error span.")
  @encodedName("application/json", "errors_only")
  errorsOnly?: boolean;
}

@doc("A saved filter over log records.")
model SavedLogQueryFilter {
  @maxItems(32)
  matchers?: TelemetryMatcher[];

  signal: "logs";
  ...SavedQueryWindow;

  @encodedName("application/json", "service_name")
  @minLength(1)
  @maxLength(256)
  serviceName?: string;

  @encodedName("application/json", "severity_min")
  severityMin?: SeverityNumber;

  @encodedName("application/json", "session_id")
  sessionId?: SessionId;

  @encodedName("application/json", "trace_id")
  traceId?: TraceId;

  @doc("Substring searched in the log body.")
  @minLength(1)
  @maxLength(1024)
  query?: string;
}

@doc("A saved metric range query.")
model SavedMetricQueryFilter {
  signal: "metrics";
  ...SavedQueryWindow;

  @encodedName("application/json", "metric_name")
  @minLength(1)
  @maxLength(256)
  metricName: string;

  aggregation?: MetricAggregation = MetricAggregation.avg;

  @doc("Bucket width in integer milliseconds.")
  @encodedName("application/json", "step_ms")
  @minValue(1)
  @maxValue(86400000)
  stepMs?: int64 = 60000;

  @doc("Attribute keys to split the result by.")
  @encodedName("application/json", "group_by")
  @maxItems(16)
  groupBy?: string[];

  @doc("Attribute matchers a series must all satisfy.")
  @maxItems(32)
  matchers?: MetricAttributeMatcher[];
}

@doc("Exactly one structured filter; `signal` selects which.")
@oneOf
union SavedQueryFilter {
  traces: SavedTraceQueryFilter,
  logs: SavedLogQueryFilter,
  metrics: SavedMetricQueryFilter,
}

@doc("A named filter for traces, logs or metrics, owned by one project.")
model SavedQuery extends ResourceBase {
  @doc("Unique within the project; a duplicate is refused with 409.")
  @minLength(1)
  @maxLength(200)
  name: string;

  @maxLength(2000)
  description?: string;

  filter: SavedQueryFilter;
}

@doc("Body of POST /api/v1/saved-queries: the `Lifecycle.Create` members of SavedQuery.")
model SavedQueryCreateRequest {
  @doc("Unique within the project; a duplicate is refused with 409.")
  @minLength(1)
  @maxLength(200)
  name: string;

  @maxLength(2000)
  description?: string;

  filter: SavedQueryFilter;
}

@doc("Body of PATCH /api/v1/saved-queries/{saved_query_id}: the `Lifecycle.Update` members of SavedQuery, each optional; omitted members keep their value.")
model SavedQueryUpdateRequest {
  @doc("New name, unique within the project; a duplicate is refused with 409.")
  @minLength(1)
  @maxLength(200)
  name?: string;

  @maxLength(2000)
  description?: string;

  filter?: SavedQueryFilter;
}

@doc("Optional overrides for one run of a saved query.")
model SavedQueryRunRequest {
  @doc("Overrides the saved look-back window together with `end_time`.")
  @encodedName("application/json", "start_time")
  startTime?: utcDateTime;

  @encodedName("application/json", "end_time")
  endTime?: utcDateTime;

  @doc("Page size for trace and log runs; 100 when omitted.")
  limit?: PageLimit = 100;

  @doc("`next_cursor` of a previous run of the same saved query.")
  cursor?: Cursor;
}

@doc("One page of trace summaries produced by a saved trace query, like list_traces; get_trace reads one full span tree.")
model SavedTraceQueryRun {
  signal: "traces";
  items: TraceSummary[];

  @doc("Pass back as `cursor` for the next page of the same run. Absent on the last page.")
  @encodedName("application/json", "next_cursor")
  nextCursor?: Cursor;

  @doc("Whether more items follow this page. `next_cursor` is present exactly when this is true.")
  @encodedName("application/json", "has_more")
  hasMore: boolean;
}

@doc("One page of log records produced by a saved log query.")
model SavedLogQueryRun {
  signal: "logs";
  items: LogRecord[];

  @doc("Pass back as `cursor` for the next page of the same run. Absent on the last page.")
  @encodedName("application/json", "next_cursor")
  nextCursor?: Cursor;

  @doc("Whether more items follow this page. `next_cursor` is present exactly when this is true.")
  @encodedName("application/json", "has_more")
  hasMore: boolean;
}

@doc("The range-query result produced by a saved metric query.")
model SavedMetricQueryRun {
  signal: "metrics";
  result: MetricQueryResult;
}

@doc("The result of running a saved query; `signal` matches the query's filter.")
@oneOf
union SavedQueryRunResult {
  traces: SavedTraceQueryRun,
  logs: SavedLogQueryRun,
  metrics: SavedMetricQueryRun,
}
