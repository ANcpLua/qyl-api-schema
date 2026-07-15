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

namespace TypeSpec.Http {
  @doc("HttpOnly local runner session cookie. The cookie value is never exposed by a product DTO.")
  model RunnerMcpSessionCookieAuth
    is ApiKeyAuth<ApiKeyLocation.cookie, "qyl-mcp-session">;
}

namespace Qyl.Api.Contracts.Runner {
  @events
  union RunnerResourceEvents {
    message: RunnerResourceState,
  }

  @events
  union RunnerLogEvents {
    message: RunnerLogLine,
  }

  @events
  union RunnerMcpProtocolEvents {
    message: RunnerMcpProtocolEvent,
  }

  @events
  union RunnerMcpExecutionUpdateEvents {
    message: RunnerMcpExecutionRecord,
  }

  @route("/runner/session")
  @tag("Runner session")
  interface RunnerSessionApi {
    @doc("Read local session and workspace identity metadata. The session cookie value is never returned.")
    @useAuth(RunnerMcpSessionCookieAuth)
    @get
    get():
      | RunnerMcpWorkbenchSession
      | UnauthorizedError
      | ForbiddenError
      | ServiceUnavailableError
      | InternalServerError;

    @doc("Bootstrap a loopback-only local session. The runtime sets qyl-mcp-session with HttpOnly and SameSite attributes, adds Secure when served over HTTPS, and never returns its value.")
    @post
    bootstrap():
      | RunnerMcpSessionBootstrapResponse
      | UnauthorizedError
      | ForbiddenError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;
  }

  @route("/runner/resources")
  @tag("Runner resources")
  @useAuth(RunnerMcpSessionCookieAuth)
  interface RunnerResourcesApi {
    @get snapshot():
      | RunnerResourceState[]
      | UnauthorizedError
      | ForbiddenError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/stream")
    stream():
      | SSEStream<RunnerResourceEvents>
      | UnauthorizedError
      | ForbiddenError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{resource}/logs")
    logs(@path resource: string):
      | RunnerLogLine[]
      | UnauthorizedError
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
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{resource}/restart")
    restart(@path resource: string):
      | RunnerActionAccepted
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{resource}/stop")
    stop(@path resource: string):
      | RunnerActionAccepted
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;
  }

  @route("/runner/mcp/{resource}")
  @tag("Runner MCP")
  interface RunnerMcpApi {
    @doc("Returns the MCP SDK-owned tools/list result without redefining its protocol body.")
    @get
    @route("/tools")
    listTools(@path resource: string):
      | unknown
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | ServiceUnavailableError
      | InternalServerError;

    @doc("Accepts and returns MCP SDK-owned tools/call bodies without redefining the protocol DTOs.")
    @post
    @route("/tools/call")
    callTool(
      @path resource: string,
      @body request: unknown,
    ):
      | unknown
      | ValidationError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | ServiceUnavailableError
      | InternalServerError;

    @doc("Accepts and returns MCP SDK-owned resources/read bodies without redefining the protocol DTOs.")
    @post
    @route("/resources/read")
    readResource(
      @path resource: string,
      @body request: unknown,
    ):
      | unknown
      | ValidationError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | ServiceUnavailableError
      | InternalServerError;
  }

  @route("/runner/workspaces")
  @tag("Runner workspaces")
  @useAuth(RunnerMcpSessionCookieAuth)
  interface RunnerWorkspacesApi {
    @get
    list():
      | RunnerMcpWorkspaceListResponse
      | UnauthorizedError
      | ForbiddenError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    create(@body request: RunnerMcpWorkspaceCreateRequest):
      | RunnerMcpWorkspace
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{workspaceId}")
    get(@path workspaceId: RunnerMcpWorkspaceId):
      | RunnerMcpWorkspace
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @patch
    @route("/{workspaceId}")
    update(
      @path workspaceId: RunnerMcpWorkspaceId,
      @body request: RunnerMcpWorkspaceUpdateRequest,
    ):
      | RunnerMcpWorkspace
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @delete
    @route("/{workspaceId}")
    delete(@path workspaceId: RunnerMcpWorkspaceId):
      | RunnerMcpDeleted
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{workspaceId}/preferences")
    getPreferences(@path workspaceId: RunnerMcpWorkspaceId):
      | RunnerMcpWorkspacePreferences
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @put
    @route("/{workspaceId}/preferences")
    updatePreferences(
      @path workspaceId: RunnerMcpWorkspaceId,
      @body request: RunnerMcpWorkspacePreferencesUpdateRequest,
    ):
      | RunnerMcpWorkspacePreferences
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;
  }

  @route("/runner/workspaces/{workspaceId}/servers")
  @tag("Runner MCP servers")
  @useAuth(RunnerMcpSessionCookieAuth)
  interface RunnerMcpServersApi {
    @get
    list(@path workspaceId: RunnerMcpWorkspaceId):
      | RunnerMcpServerListResponse
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    create(
      @path workspaceId: RunnerMcpWorkspaceId,
      @body request: RunnerMcpServerCreateRequest,
    ):
      | RunnerMcpServer
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{serverId}")
    get(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path serverId: RunnerMcpServerId,
    ):
      | RunnerMcpServer
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @patch
    @route("/{serverId}")
    update(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path serverId: RunnerMcpServerId,
      @body request: RunnerMcpServerUpdateRequest,
    ):
      | RunnerMcpServer
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @delete
    @route("/{serverId}")
    delete(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path serverId: RunnerMcpServerId,
    ):
      | RunnerMcpDeleted
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{serverId}/connect")
    connect(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path serverId: RunnerMcpServerId,
    ):
      | RunnerMcpServerActionAccepted
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{serverId}/disconnect")
    disconnect(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path serverId: RunnerMcpServerId,
    ):
      | RunnerMcpServerActionAccepted
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{serverId}/reconnect")
    reconnect(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path serverId: RunnerMcpServerId,
    ):
      | RunnerMcpServerActionAccepted
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{serverId}/discovery")
    discovery(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path serverId: RunnerMcpServerId,
    ):
      | RunnerMcpDiscoverySnapshot
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{serverId}/discovery/refresh")
    refreshDiscovery(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path serverId: RunnerMcpServerId,
    ):
      | RunnerMcpDiscoverySnapshot
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{serverId}/protocol")
    protocolEvents(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path serverId: RunnerMcpServerId,
      @query cursor?: string,

      @query
      @minValue(1)
      @maxValue(1000)
      limit?: int32 = 200,
    ):
      | RunnerMcpProtocolEventPage
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{serverId}/protocol/stream")
    streamProtocolEvents(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path serverId: RunnerMcpServerId,
      @header("Last-Event-ID") lastEventId?: string,
    ):
      | SSEStream<RunnerMcpProtocolEvents>
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;
  }

  @route("/runner/workspaces/{workspaceId}/servers/{serverId}/executions")
  @tag("Runner MCP executions")
  @useAuth(RunnerMcpSessionCookieAuth)
  interface RunnerMcpExecutionsApi {
    @get
    @route("/stream")
    streamUpdates(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path serverId: RunnerMcpServerId,
      @query executionId?: RunnerMcpExecutionId,
      @header("Last-Event-ID") lastEventId?: string,
    ):
      | SSEStream<RunnerMcpExecutionUpdateEvents>
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    list(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path serverId: RunnerMcpServerId,
      @query status?: RunnerMcpExecutionStatus,
      @query cursor?: string,

      @query
      @minValue(1)
      @maxValue(1000)
      limit?: int32 = 100,
    ):
      | RunnerMcpExecutionPage
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    start(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path serverId: RunnerMcpServerId,
      @body request: RunnerMcpExecutionRequest,
    ):
      | RunnerMcpExecutionAccepted
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{executionId}")
    get(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path serverId: RunnerMcpServerId,
      @path executionId: RunnerMcpExecutionId,
    ):
      | RunnerMcpExecutionRecord
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{executionId}/cancel")
    cancel(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path serverId: RunnerMcpServerId,
      @path executionId: RunnerMcpExecutionId,
      @body request: RunnerMcpExecutionCancelRequest,
    ):
      | RunnerMcpExecutionAccepted
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{executionId}/telemetry")
    telemetry(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path serverId: RunnerMcpServerId,
      @path executionId: RunnerMcpExecutionId,
    ):
      | RunnerMcpExecutionTelemetryResponse
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;
  }

  @route("/runner/workspaces/{workspaceId}/test-cases")
  @tag("Runner MCP test cases")
  @useAuth(RunnerMcpSessionCookieAuth)
  interface RunnerMcpTestCasesApi {
    @get
    list(
      @path workspaceId: RunnerMcpWorkspaceId,
      @query serverId?: RunnerMcpServerId,
      @query toolName?: string,
      @query cursor?: string,

      @query
      @minValue(1)
      @maxValue(1000)
      limit?: int32 = 100,
    ):
      | RunnerMcpTestCasePage
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    create(
      @path workspaceId: RunnerMcpWorkspaceId,
      @body request: RunnerMcpTestCaseCreateRequest,
    ):
      | RunnerMcpTestCase
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{testCaseId}")
    get(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path testCaseId: RunnerMcpTestCaseId,
    ):
      | RunnerMcpTestCase
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @patch
    @route("/{testCaseId}")
    update(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path testCaseId: RunnerMcpTestCaseId,
      @body request: RunnerMcpTestCaseUpdateRequest,
    ):
      | RunnerMcpTestCase
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @delete
    @route("/{testCaseId}")
    delete(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path testCaseId: RunnerMcpTestCaseId,
    ):
      | RunnerMcpDeleted
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{testCaseId}/run")
    run(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path testCaseId: RunnerMcpTestCaseId,
      @body request: RunnerMcpTestCaseRunRequest,
    ):
      | RunnerMcpEvaluationRunAccepted
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;
  }

  @route("/runner/workspaces/{workspaceId}/suites")
  @tag("Runner MCP suites")
  @useAuth(RunnerMcpSessionCookieAuth)
  interface RunnerMcpSuitesApi {
    @get
    list(
      @path workspaceId: RunnerMcpWorkspaceId,
      @query cursor?: string,

      @query
      @minValue(1)
      @maxValue(1000)
      limit?: int32 = 100,
    ):
      | RunnerMcpTestSuitePage
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    create(
      @path workspaceId: RunnerMcpWorkspaceId,
      @body request: RunnerMcpTestSuiteCreateRequest,
    ):
      | RunnerMcpTestSuite
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{suiteId}")
    get(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path suiteId: RunnerMcpSuiteId,
    ):
      | RunnerMcpTestSuite
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @patch
    @route("/{suiteId}")
    update(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path suiteId: RunnerMcpSuiteId,
      @body request: RunnerMcpTestSuiteUpdateRequest,
    ):
      | RunnerMcpTestSuite
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @delete
    @route("/{suiteId}")
    delete(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path suiteId: RunnerMcpSuiteId,
    ):
      | RunnerMcpDeleted
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{suiteId}/run")
    run(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path suiteId: RunnerMcpSuiteId,
      @body request: RunnerMcpSuiteRunRequest,
    ):
      | RunnerMcpEvaluationRunAccepted
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;
  }

  @route("/runner/workspaces/{workspaceId}/evaluation-runs")
  @tag("Runner MCP evaluations")
  @useAuth(RunnerMcpSessionCookieAuth)
  interface RunnerMcpEvaluationRunsApi {
    @get
    list(
      @path workspaceId: RunnerMcpWorkspaceId,
      @query status?: RunnerMcpEvaluationRunStatus,
      @query cursor?: string,

      @query
      @minValue(1)
      @maxValue(1000)
      limit?: int32 = 100,
    ):
      | RunnerMcpEvaluationRunPage
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{evaluationRunId}")
    get(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path evaluationRunId: RunnerMcpEvaluationRunId,
    ):
      | RunnerMcpEvaluationRun
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/compare")
    compare(
      @path workspaceId: RunnerMcpWorkspaceId,
      @body request: RunnerMcpEvaluationComparisonRequest,
    ):
      | RunnerMcpEvaluationRunComparison
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{evaluationRunId}/export")
    export(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path evaluationRunId: RunnerMcpEvaluationRunId,
      @body request: RunnerMcpEvaluationExportRequest,
    ):
      | RunnerMcpEvaluationExportAccepted
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{evaluationRunId}/exports/{exportId}")
    getExport(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path evaluationRunId: RunnerMcpEvaluationRunId,
      @path exportId: RunnerMcpEvaluationExportId,
    ):
      | RunnerMcpEvaluationExport
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{evaluationRunId}/exports/{exportId}/content")
    getExportContent(
      @path workspaceId: RunnerMcpWorkspaceId,
      @path evaluationRunId: RunnerMcpEvaluationRunId,
      @path exportId: RunnerMcpEvaluationExportId,
    ):
      | RunnerMcpEvaluationExportArtifact
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;
  }
}
