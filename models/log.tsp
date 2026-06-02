// =============================================================================
// ANcpLua v2.0 - Log Semantic Conventions (OTel v1.40)
// =============================================================================
// Log record attributes and log-specific semantic conventions.
// =============================================================================

import "../common/types.tsp";
import "../otel/enums.tsp";

using Qyl.Api.Contracts.Common;
using Qyl.Api.Contracts.OTel.Enums;

namespace Qyl.Api.Contracts.Domains.Observe.Log;

// =============================================================================
// Log Attributes
// =============================================================================

@doc("Log record attributes")
model LogAttributes {
  @doc("Log record unique identifier")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Log.RecordUid)
  recordUid?: string;

  @doc("Original log file name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Log.FileName)
  fileName?: string;

  @doc("Full path to log file")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Log.FilePath)
  filePath?: string;

  @doc("Original log file name resolved")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Log.FileNameResolved)
  fileNameResolved?: string;

  @doc("Full path to log file resolved")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Log.FilePathResolved)
  filePathResolved?: string;

  @doc("Log iostream (stdout/stderr)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Log.Iostream)
  iostream?: LogIostream;
}

@doc("Log IO streams")
enum LogIostream {
  @doc("Standard output")
  stdout: "stdout",

  @doc("Standard error")
  stderr: "stderr",
}

// =============================================================================
// Event Attributes
// =============================================================================

@doc("Event domain for event.name categorization")
enum EventDomain {
  @doc("Browser events")
  browser: "browser",

  @doc("Device events")
  device: "device",

  @doc("Kubernetes events")
  k8s: "k8s",

  @doc("User events")
  user: "user",

  @doc("Session events")
  session: "session",

  @doc("Application events")
  app: "app",

  @doc("Feature flag events")
  featureFlag: "feature_flag",

  @doc("Deployment events")
  deployment: "deployment",

  @doc("CI/CD events")
  cicd: "cicd",
}

@doc("Log event attributes")
model EventAttributes {
  @doc("Event name (with domain prefix)")
  @encodedName("application/json", "event.name")
  name: string;

  @doc("Event domain")
  @encodedName("application/json", "event.domain")
  domain?: EventDomain;
}

// =============================================================================
// Log Severity Mapping
// =============================================================================

@doc("Log severity text to number mapping")
model SeverityMapping {
  @doc("Severity text")
  text: string;

  @doc("Severity number (1-24)")
  number: SeverityNumber;
}

// =============================================================================
// Log Query Models
// =============================================================================

@doc("Log search query")
model LogQuery {
  @doc("Free text search")
  query?: string;

  @doc("Severity filter")
  @encodedName("application/json", "severity_min")
  severityMin?: SeverityNumber;

  @doc("Service name filter")
  @encodedName("application/json", "service_name")
  serviceName?: string;

  @doc("Trace ID filter")
  @encodedName("application/json", "trace_id")
  traceId?: TraceId;

  @doc("Span ID filter")
  @encodedName("application/json", "span_id")
  spanId?: SpanId;

  @doc("Time range start")
  @encodedName("application/json", "time_start")
  timeStart?: utcDateTime;

  @doc("Time range end")
  @encodedName("application/json", "time_end")
  timeEnd?: utcDateTime;

  @doc("Attribute filters")
  @encodedName("application/json", "attribute_filters")
  attributeFilters?: AttributeFilter[];

  @doc("Limit")
  @minValue(1)
  @maxValue(10000)
  limit?: int32;

  @doc("Order by")
  @encodedName("application/json", "order_by")
  orderBy?: LogOrderBy;
}

@doc("Attribute filter")
model AttributeFilter {
  @doc("Attribute key")
  key: string;

  @doc("Filter operator")
  operator: FilterOperator;

  @doc("Filter value")
  value: string;
}

@doc("Filter operators")
enum FilterOperator {
  @doc("Equals")
  eq: "eq",

  @doc("Not equals")
  neq: "neq",

  @doc("Contains")
  contains: "contains",

  @doc("Starts with")
  startsWith: "starts_with",

  @doc("Ends with")
  endsWith: "ends_with",

  @doc("Regex match")
  regex: "regex",

  @doc("Greater than")
  gt: "gt",

  @doc("Greater than or equal")
  gte: "gte",

  @doc("Less than")
  lt: "lt",

  @doc("Less than or equal")
  lte: "lte",

  @doc("In list")
  in: "in",

  @doc("Not in list")
  notIn: "not_in",

  @doc("Exists")
  exists: "exists",

  @doc("Does not exist")
  notExists: "not_exists",
}

@doc("Log ordering options")
enum LogOrderBy {
  @doc("Timestamp ascending")
  timestampAsc: "timestamp_asc",

  @doc("Timestamp descending")
  timestampDesc: "timestamp_desc",

  @doc("Severity ascending")
  severityAsc: "severity_asc",

  @doc("Severity descending")
  severityDesc: "severity_desc",
}

// =============================================================================
// Log Aggregation
// =============================================================================

@doc("Log aggregation request")
model LogAggregation {
  @doc("Group by fields")
  @encodedName("application/json", "group_by")
  groupBy: string[];

  @doc("Aggregation function")
  function: AggregationFunction;

  @doc("Field to aggregate (for non-count)")
  field?: string;

  @doc("Time bucket (for time series)")
  @encodedName("application/json", "time_bucket")
  timeBucket?: TimeBucket;

  @doc("Top N results")
  @encodedName("application/json", "top_n")
  topN?: int32;
}

@doc("Aggregation functions")
enum AggregationFunction {
  @doc("Count")
  count: "count",

  @doc("Sum")
  sum: "sum",

  @doc("Average")
  avg: "avg",

  @doc("Minimum")
  min: "min",

  @doc("Maximum")
  max: "max",

  @doc("Percentile 50")
  p50: "p50",

  @doc("Percentile 90")
  p90: "p90",

  @doc("Percentile 95")
  p95: "p95",

  @doc("Percentile 99")
  p99: "p99",

  @doc("Count distinct")
  countDistinct: "count_distinct",
}

@doc("Time bucket sizes")
enum TimeBucket {
  @doc("1 second")
  s1: "1s",

  @doc("10 seconds")
  s10: "10s",

  @doc("30 seconds")
  s30: "30s",

  @doc("1 minute")
  m1: "1m",

  @doc("5 minutes")
  m5: "5m",

  @doc("15 minutes")
  m15: "15m",

  @doc("30 minutes")
  m30: "30m",

  @doc("1 hour")
  h1: "1h",

  @doc("6 hours")
  h6: "6h",

  @doc("12 hours")
  h12: "12h",

  @doc("1 day")
  d1: "1d",

  @doc("1 week")
  w1: "1w",
}

// =============================================================================
// Log Statistics
// =============================================================================

@doc("Log statistics")
model LogStats {
  @doc("Total log count")
  @encodedName("application/json", "total_count")
  totalCount: Count;

  @doc("Logs by severity")
  @encodedName("application/json", "by_severity")
  bySeverity: LogSeverityStats[];

  @doc("Logs by service")
  @encodedName("application/json", "by_service")
  byService?: LogServiceStats[];

  @doc("Log rate per second")
  @encodedName("application/json", "rate_per_second")
  ratePerSecond: float64;

  @doc("Error rate")
  @encodedName("application/json", "error_rate")
  errorRate: Ratio;
}

@doc("Log stats by severity")
model LogSeverityStats {
  @doc("Severity number")
  severity: SeverityNumber;

  @doc("Severity text")
  @encodedName("application/json", "severity_text")
  severityText: string;

  @doc("Count")
  count: Count;

  @doc("Percentage of total")
  percentage: Percentage;
}

@doc("Log stats by service")
model LogServiceStats {
  @doc("Service name")
  @encodedName("application/json", "service_name")
  serviceName: string;

  @doc("Total count")
  count: Count;

  @doc("Error count")
  @encodedName("application/json", "error_count")
  errorCount: Count;

  @doc("Rate per second")
  @encodedName("application/json", "rate_per_second")
  ratePerSecond: float64;
}

// =============================================================================
// Log Patterns
// =============================================================================

@doc("Detected log pattern")
model LogPattern {
  @doc("Pattern ID")
  @encodedName("application/json", "pattern_id")
  patternId: string;

  @doc("Pattern template")
  template: string;

  @doc("Sample log message")
  sample: string;

  @doc("Occurrence count")
  count: Count;

  @doc("First seen")
  @encodedName("application/json", "first_seen")
  firstSeen: utcDateTime;

  @doc("Last seen")
  @encodedName("application/json", "last_seen")
  lastSeen: utcDateTime;

  @doc("Trend")
  trend: LogPatternTrend;

  @doc("Severity distribution")
  @encodedName("application/json", "severity_distribution")
  severityDistribution?: LogSeverityStats[];
}

@doc("Log pattern trend")
enum LogPatternTrend {
  @doc("Increasing")
  increasing: "increasing",

  @doc("Decreasing")
  decreasing: "decreasing",

  @doc("Stable")
  stable: "stable",

  @doc("New pattern")
  new: "new",

  @doc("Anomalous spike")
  spike: "spike",
}

// =============================================================================
// Structured Log Format
// =============================================================================

@doc("Structured log format detection")
enum StructuredLogFormat {
  @doc("JSON format")
  json: "json",

  @doc("Logfmt format")
  logfmt: "logfmt",

  @doc("Apache Common Log Format")
  clf: "clf",

  @doc("Apache Combined Log Format")
  combined: "combined",

  @doc("Syslog format")
  syslog: "syslog",

  @doc("W3C Extended Log Format")
  w3c: "w3c",

  @doc("CSV format")
  csv: "csv",

  @doc("Unstructured/plaintext")
  plaintext: "plaintext",
}
