import "@typespec/http";
import "@typespec/openapi";

import "../common/types.tsp";
import "../common/errors.tsp";
import "../common/pagination.tsp";
import "../otel/span.tsp";
import "../otel/logs.tsp";
import "../models/session.tsp";
import "../models/health.tsp";
import "../models/metrics.tsp";

using TypeSpec.Http;
using TypeSpec.OpenAPI;

using Qyl.Api.Contracts.Common;
using Qyl.Api.Contracts.Common.Errors;
using Qyl.Api.Contracts.Common.Pagination;
using Qyl.Api.Contracts.OTel.Traces;
using Qyl.Api.Contracts.OTel.Logs;
using Qyl.Api.Contracts.OTel.Metrics;
using Qyl.Api.Contracts.OTel.Enums;
using Qyl.Api.Contracts.Domains.Observe.Session;
using Qyl.Api.Contracts.Health;

@service(#{ title: "qyl API" })
namespace Qyl.Api.Contracts;

alias QylApiKeyHeaderAuth = ApiKeyAuth<ApiKeyLocation.header, "x-otlp-api-key">;

@doc("Optional project scope applied to collector query operations.")
model ProjectScopeHeader {
  @header("X-Qyl-Project")
  projectId?: string;
}

// -----------------------------------------------------------------------------
// Traces
// -----------------------------------------------------------------------------

@route("/api/v1/traces")
@tag("Traces")
@useAuth(QylApiKeyHeaderAuth)
interface TracesApi {
  @get
  list(
    ...ProjectScopeHeader,

    @query
    @minValue(1)
    @maxValue(1000)
    limit?: int32 = 100,

    @query cursor?: string,
  ):
    | CursorPage<Trace>
    | ValidationError
    | UnauthorizedError
    | InternalServerError;

  @get
  @route("/{trace_id}")
  get(...ProjectScopeHeader, @path("trace_id") traceId: TraceId):
    | Trace
    | NotFoundError
    | UnauthorizedError
    | InternalServerError;

  @get
  @route("/{trace_id}/spans")
  getSpans(...ProjectScopeHeader, @path("trace_id") traceId: TraceId):
    | CursorPage<Span>
    | NotFoundError
    | UnauthorizedError
    | InternalServerError;
}

// -----------------------------------------------------------------------------
// Logs
// -----------------------------------------------------------------------------

@route("/api/v1/logs")
@tag("Logs")
@useAuth(QylApiKeyHeaderAuth)
interface LogsApi {
  @get
  list(
    ...ProjectScopeHeader,
    @query("session_id") sessionId?: SessionId,
    @query("service_name") serviceName?: string,
    @query level?: string,
    @query("severity_min") severityMin?: SeverityNumber,
    @query("trace_id") traceId?: TraceId,
    @query("start_time") startTime?: utcDateTime,
    @query("end_time") endTime?: utcDateTime,
    @query query?: string,

    @query
    @minValue(1)
    @maxValue(10000)
    limit?: int32 = 100,
  ):
    | CursorPage<LogRecord>
    | ValidationError
    | UnauthorizedError
    | InternalServerError;
}

// -----------------------------------------------------------------------------
// Metrics
//
// Modelled on the Grafana/Prometheus range query — metric, label matchers,
// range, step — because the primary consumer is a coding agent over MCP. The
// collector aggregates server-side and returns buckets; raw points are never
// served, so a payload stays small no matter how dense the underlying stream.
// -----------------------------------------------------------------------------

@route("/api/v1/metrics")
@tag("Metrics")
@useAuth(QylApiKeyHeaderAuth)
interface MetricsApi {
  @doc("List the metric names recorded for a project.")
  @get
  list(
    ...ProjectScopeHeader,

    @doc("Return only names starting with this prefix.")
    @query("name_prefix")
    namePrefix?: string,

    @query
    @minValue(1)
    @maxValue(1000)
    limit?: int32 = 200,
  ):
    | CursorPage<MetricDescriptor>
    | ValidationError
    | UnauthorizedError
    | InternalServerError;

  @doc("List the distinct attribute streams recorded under one metric name.")
  @get
  @route("/{metric_name}/series")
  listSeries(
    ...ProjectScopeHeader,
    @path("metric_name") metricName: string,

    @doc("""
      Exact attribute match, repeatable, as `key=value`. A series must match
      every matcher given.
      """)
    @query(#{ explode: true })
    attr?: string[],

    @doc("Attribute prefix match, repeatable, as `key=prefix`.")
    @query(#{ name: "attr_prefix", explode: true })
    attrPrefix?: string[],

    @query
    @minValue(1)
    @maxValue(1000)
    limit?: int32 = 200,
  ):
    | CursorPage<MetricSeries>
    | ValidationError
    | NotFoundError
    | UnauthorizedError
    | InternalServerError;

  @doc("""
    Aggregate one metric over a time range into buckets of `step_ms`.
    Percentile aggregations require a histogram kind.
    """)
  @get
  @route("/{metric_name}/query")
  query(
    ...ProjectScopeHeader,
    @path("metric_name") metricName: string,

    @query("start_time") startTime: utcDateTime,
    @query("end_time") endTime: utcDateTime,

    @doc("Bucket width in milliseconds. One bucket spanning the range collapses the query to a single value.")
    @query("step_ms")
    @minValue(1)
    @maxValue(86400000)
    stepMs?: int64 = 60000,

    @query aggregation?: MetricAggregation = MetricAggregation.avg,

    @doc("Attribute keys to split the result by, repeatable. Omitted, every matching series collapses into one stream.")
    @query(#{ name: "group_by", explode: true })
    groupBy?: string[],

    @doc("Exact attribute match, repeatable, as `key=value`.")
    @query(#{ explode: true })
    attr?: string[],

    @doc("Attribute prefix match, repeatable, as `key=prefix`.")
    @query(#{ name: "attr_prefix", explode: true })
    attrPrefix?: string[],

    @doc("Maximum result streams. A grouping that exceeds this is truncated, not refused.")
    @query("series_limit")
    @minValue(1)
    @maxValue(500)
    seriesLimit?: int32 = 50,
  ):
    | MetricQueryResult
    | ValidationError
    | NotFoundError
    | UnauthorizedError
    | InternalServerError;
}

// -----------------------------------------------------------------------------
// Sessions
// -----------------------------------------------------------------------------

@route("/api/v1/sessions")
@tag("Sessions")
@useAuth(QylApiKeyHeaderAuth)
interface SessionsApi {
  @get
  list(
    ...ProjectScopeHeader,
    @query("is_active") isActive?: boolean,
    @query("start_time") startTime?: utcDateTime,
    @query("end_time") endTime?: utcDateTime,

    @query
    @minValue(1)
    @maxValue(1000)
    limit?: int32 = 100,

    @query cursor?: string,
  ):
    | CursorPage<SessionEntity>
    | ValidationError
    | UnauthorizedError
    | InternalServerError;

  @get
  @route("/{session_id}")
  get(...ProjectScopeHeader, @path("session_id") sessionId: SessionId):
    | SessionEntity
    | NotFoundError
    | UnauthorizedError
    | InternalServerError;

  @get
  @route("/{session_id}/traces")
  getTraces(...ProjectScopeHeader, @path("session_id") sessionId: SessionId):
    | CursorPage<Trace>
    | NotFoundError
    | UnauthorizedError
    | InternalServerError;

  @get
  @route("/stats")
  getStats(
    ...ProjectScopeHeader,
    @query("start_time") startTime?: utcDateTime,
    @query("end_time") endTime?: utcDateTime,
  ): SessionStats | ValidationError | UnauthorizedError | InternalServerError;
}

// -----------------------------------------------------------------------------
// Health
// -----------------------------------------------------------------------------

@tag("Health")
interface HealthApi {
  @get
  @route("/alive")
  @operationId("health_alive")
  alive():
    | {
        @statusCode statusCode: 200;
        @body body: HealthReport;
      }
    | {
        @statusCode statusCode: 503;
        @body body: HealthReport;
      };

  @get
  @route("/health")
  @operationId("health_ready")
  ready():
    | {
        @statusCode statusCode: 200;
        @body body: HealthReport;
      }
    | {
        @statusCode statusCode: 503;
        @body body: HealthReport;
      };
}
