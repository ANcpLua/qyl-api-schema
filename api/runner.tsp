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

    @post
    @route("/{resource}/restart")
    restart(
      @path resource: string,
    ): RunnerActionAccepted | NotFoundError | ConflictError | InternalServerError;

    @post
    @route("/{resource}/stop")
    stop(
      @path resource: string,
    ): RunnerActionAccepted | NotFoundError | ConflictError | InternalServerError;
  }

  @route("/runner/mcp/{resource}")
  @tag("Runner MCP")
  interface RunnerMcpApi {
    @get
    @route("/tools")
    listTools(
      @path resource: string,
    ): RunnerMcpToolsResponse
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | InternalServerError;

    @post
    @route("/tools/call")
    callTool(
      @path resource: string,
      @body request: RunnerMcpToolCallRequest,
    ): RunnerMcpToolCallResponse
      | ValidationError
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | InternalServerError;

    @post
    @route("/resources/read")
    readResource(
      @path resource: string,
      @body request: RunnerMcpResourceReadRequest,
    ): RunnerMcpResourceReadResponse
      | ValidationError
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | InternalServerError;
  }
}
