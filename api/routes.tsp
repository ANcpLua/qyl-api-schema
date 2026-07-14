import "@typespec/http";
import "@typespec/openapi";

import "../common/types.tsp";
import "../common/errors.tsp";
import "../common/pagination.tsp";
import "../otel/span.tsp";
import "../otel/logs.tsp";
import "../otel/profiles.tsp";
import "../models/session.tsp";
import "../models/health.tsp";
import "../models/cost-etl-audit.tsp";

using TypeSpec.Http;
using TypeSpec.OpenAPI;

using Qyl.Api.Contracts.Common;
using Qyl.Api.Contracts.Common.Errors;
using Qyl.Api.Contracts.Common.Pagination;
using Qyl.Api.Contracts.OTel.Traces;
using Qyl.Api.Contracts.OTel.Logs;
using Qyl.Api.Contracts.OTel.Enums;
using Qyl.Api.Contracts.OTel.Profiles;
using Qyl.Api.Contracts.Domains.Observe.Session;
using Qyl.Api.Contracts.Health;
using Qyl.Api.Contracts.Cost;

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
    @query @minValue(1) @maxValue(1000) limit?: int32 = 100,
    @query cursor?: string,
  ): CursorPage<Trace> | ValidationError | UnauthorizedError | InternalServerError;

  @get
  @route("/{traceId}")
  get(
    ...ProjectScopeHeader,
    @path traceId: TraceId,
  ): Trace | NotFoundError | UnauthorizedError | InternalServerError;

  @get
  @route("/{traceId}/spans")
  getSpans(
    ...ProjectScopeHeader,
    @path traceId: TraceId,
  ): CursorPage<Span> | NotFoundError | UnauthorizedError | InternalServerError;
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
    @query sessionId?: SessionId,
    @query serviceName?: string,
    @query level?: string,
    @query severityMin?: SeverityNumber,
    @query traceId?: TraceId,
    @query startTime?: utcDateTime,
    @query endTime?: utcDateTime,
    @query query?: string,
    @query @minValue(1) @maxValue(10000) limit?: int32 = 100,
  ): CursorPage<LogRecord> | ValidationError | UnauthorizedError | InternalServerError;
}

// -----------------------------------------------------------------------------
// Profiles (OpenTelemetry development signal)
// -----------------------------------------------------------------------------

@route("/api/v1/profiles")
@tag("Profiles")
@useAuth(QylApiKeyHeaderAuth)
interface ProfilesApi {
  @get
  list(
    ...ProjectScopeHeader,
    @query sessionId?: SessionId,
    @query traceId?: TraceId,
    @query serviceName?: string,
    @query sampleType?: string,
    @query @minValue(1) @maxValue(1000) limit?: int32 = 100,
  ): Profile[] | ValidationError | UnauthorizedError | InternalServerError;

  @get
  @route("/{profileId}")
  get(
    ...ProjectScopeHeader,
    @path profileId: string,
  ): Profile | NotFoundError | UnauthorizedError | InternalServerError;

  @get
  @route("/by-trace/{traceId}")
  getByTrace(
    ...ProjectScopeHeader,
    @path traceId: TraceId,
    @query @minValue(1) @maxValue(1000) limit?: int32 = 100,
  ): Profile[] | ValidationError | UnauthorizedError | InternalServerError;

  @get
  @route("/by-span/{spanId}")
  getBySpan(
    ...ProjectScopeHeader,
    @path spanId: SpanId,
    @query @minValue(1) @maxValue(1000) limit?: int32 = 100,
  ): Profile[] | ValidationError | UnauthorizedError | InternalServerError;
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
    @query isActive?: boolean,
    @query startTime?: utcDateTime,
    @query endTime?: utcDateTime,
    @query @minValue(1) @maxValue(1000) limit?: int32 = 100,
    @query cursor?: string,
  ): CursorPage<SessionEntity> | ValidationError | UnauthorizedError | InternalServerError;

  @get
  @route("/{sessionId}")
  get(
    ...ProjectScopeHeader,
    @path sessionId: SessionId,
  ): SessionEntity | NotFoundError | UnauthorizedError | InternalServerError;

  @get
  @route("/{sessionId}/traces")
  getTraces(
    ...ProjectScopeHeader,
    @path sessionId: SessionId,
  ): CursorPage<Trace> | NotFoundError | UnauthorizedError | InternalServerError;

  @get
  @route("/stats")
  getStats(
    ...ProjectScopeHeader,
    @query startTime?: utcDateTime,
    @query endTime?: utcDateTime,
  ): SessionStats | ValidationError | UnauthorizedError | InternalServerError;
}

// -----------------------------------------------------------------------------
// GenAI cost and ETL audit
// -----------------------------------------------------------------------------

@route("/api/v1/cost/etl-audit")
@tag("GenAI cost")
@useAuth(QylApiKeyHeaderAuth)
interface GenAiEtlAuditApi {
  @get
  report(
    ...ProjectScopeHeader,
    @query startTime?: utcDateTime,
    @query endTime?: utcDateTime,
    @query @minValue(1) @maxValue(100) limit?: int32 = 25,
  ): GenAiEtlAuditReport | ValidationError | UnauthorizedError | InternalServerError;

  @post
  @route("/evaluate")
  evaluate(
    ...ProjectScopeHeader,
    @query startTime?: utcDateTime,
    @query endTime?: utcDateTime,
    @body request: GenAiEtlAuditEvaluationRequest,
  ): GenAiEtlAuditEvaluationResponse | ValidationError | UnauthorizedError | InternalServerError;
}

// -----------------------------------------------------------------------------
// Health
// -----------------------------------------------------------------------------

@tag("Health")
interface HealthApi {
  @get
  @route("/alive")
  @operationId("health_alive")
  alive(): {
    @statusCode statusCode: 200;
    @body body: HealthReport;
  } | {
    @statusCode statusCode: 503;
    @body body: HealthReport;
  };

  @get
  @route("/health")
  @operationId("health_ready")
  ready(): {
    @statusCode statusCode: 200;
    @body body: HealthReport;
  } | {
    @statusCode statusCode: 503;
    @body body: HealthReport;
  };
}
