import "@typespec/events";
import "@typespec/http";
import "@typespec/sse";

import "./routes.tsp";
import "../common/errors.tsp";
import "../otel/logs.tsp";

using TypeSpec.Events;
using TypeSpec.Http;
using TypeSpec.SSE;

using Qyl.Api.Contracts.Common.Errors;
using Qyl.Api.Contracts.OTel.Logs;

namespace Qyl.Api.Contracts.Streaming;

@doc("One log delivered by the collector's live stream.")
model LogStreamEvent {
  type: "log";
  data: LogRecord;
  timestamp: utcDateTime;
}

@doc("Keep-alive event emitted while no new log is available.")
model HeartbeatEvent {
  type: "heartbeat";
  timestamp: utcDateTime;
}

@events
union LogEvents {
  log: LogStreamEvent,
  heartbeat: HeartbeatEvent,
}

@route("/api/v1/stream")
@tag("Streaming")
interface StreamingApi {
  @get
  @route("/logs")
  @useAuth(Qyl.Api.Contracts.QylApiKeyHeaderAuth)
  streamLogs(
    ...Qyl.Api.Contracts.ProjectScopeHeader,
    @query serviceName?: string,
    @query @minValue(1) @maxValue(24) minSeverity?: int32,
    @query query?: string,
  ): SSEStream<LogEvents> | ValidationError | UnauthorizedError | InternalServerError;
}
