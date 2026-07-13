import "@typespec/events";
import "@typespec/http";
import "@typespec/sse";

import "../common/errors.tsp";
import "../models/runner.tsp";
import "../models/runner-mcp.tsp";

using TypeSpec.Events;
using TypeSpec.Http;
using TypeSpec.SSE;

using Qyl.Api.Contracts.Common.Errors;
using Qyl.Api.Contracts.Runner.Mcp;

namespace Qyl.Api.Contracts.Runner {
  @events
  union RunnerResourceEvents {
    RunnerResourceState,
  }

  @events
  union RunnerLogEvents {
    RunnerLogLine,
  }

  @route("/runner/resources")
  @tag("Runner resources")
  interface RunnerResourcesApi {
    @get
    snapshot(): RunnerResourceState[] | InternalServerError;

    @get
    @route("/stream")
    stream(): SSEStream<RunnerResourceEvents> | InternalServerError;

    @get
    @route("/{resource}/logs")
    logs(
      @path resource: string,
    ): RunnerLogLine[] | NotFoundError | InternalServerError;

    @get
    @route("/{resource}/logs/stream")
    streamLogs(
      @path resource: string,
    ): SSEStream<RunnerLogEvents> | NotFoundError | InternalServerError;
  }

  @route("/runner/mcp/{resource}/tools")
  @tag("Runner MCP")
  interface RunnerMcpApi {
    @get
    listTools(
      @path resource: string,
    ): RunnerMcpToolsResponse
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | InternalServerError;

    @post
    @route("/call")
    callTool(
      @path resource: string,
      @body request: RunnerMcpToolCallRequest,
    ): RunnerMcpToolCallResponse
      | ValidationError
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | InternalServerError;
  }
}
