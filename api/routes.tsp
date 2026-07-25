import "@typespec/http";
import "@typespec/openapi";

import "../common/types.tsp";
import "../common/errors.tsp";
import "../common/pagination.tsp";
import "../otel/span.tsp";
import "../otel/logs.tsp";
import "../models/session.tsp";
import "../models/health.tsp";

using TypeSpec.Http;
using TypeSpec.OpenAPI;

using Qyl.Api.Contracts.Common;
using Qyl.Api.Contracts.Common.Errors;
using Qyl.Api.Contracts.Common.Pagination;
using Qyl.Api.Contracts.OTel.Traces;
using Qyl.Api.Contracts.OTel.Logs;
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
