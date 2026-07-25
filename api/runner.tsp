import "@typespec/events";
import "@typespec/http";
import "@typespec/sse";

import "../common/errors.tsp";
import "../models/runner.tsp";

using TypeSpec.Events;
using TypeSpec.Http;
using TypeSpec.SSE;

using Qyl.Api.Contracts.Common.Errors;

namespace Qyl.Api.Contracts.Runner {
  @events
  union RunnerResourceEvents {
    message: RunnerResourceState,
  }

  @events
  union RunnerLogEvents {
    message: RunnerLogLine,
  }

  @route("/runner/resources")
  @tag("Runner resources")
  interface RunnerResourcesApi {
    @get snapshot():
      | RunnerResourceState[]
      | ForbiddenError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/stream")
    stream():
      | SSEStream<RunnerResourceEvents>
      | ForbiddenError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{resource}/logs")
    logs(@path resource: string):
      | RunnerLogLine[]
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{resource}/logs/stream")
    streamLogs(
      @path resource: string,
      @header("Last-Event-ID") lastEventId?: string,
    ):
      | SSEStream<RunnerLogEvents>
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{resource}/restart")
    restart(@path resource: string):
      | RunnerActionAccepted
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{resource}/stop")
    stop(@path resource: string):
      | RunnerActionAccepted
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;
  }
}
