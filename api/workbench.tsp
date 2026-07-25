import "@typespec/events";
import "@typespec/http";
import "@typespec/sse";

import "../common/errors.tsp";
import "../models/workbench.tsp";

using TypeSpec.Events;
using TypeSpec.Http;
using TypeSpec.SSE;

using Qyl.Api.Contracts.Common.Errors;
using Qyl.Api.Contracts.Workbench;

namespace TypeSpec.Http {
  @doc("HttpOnly local workbench session cookie. The cookie value is never exposed by a product DTO.")
  model WorkbenchSessionCookieAuth
    is ApiKeyAuth<ApiKeyLocation.cookie, "qyl-workbench-session">;
}

namespace Qyl.Api.Contracts.Workbench {
  @events
  union WorkbenchProtocolEvents {
    message: WorkbenchProtocolEvent,
  }

  @events
  union WorkbenchExecutionUpdateEvents {
    message: WorkbenchExecutionRecord,
  }

  @route("/workbench/session")
  @tag("Workbench session")
  interface WorkbenchSessionApi {
    @doc("Read local session and workspace identity metadata. The session cookie value is never returned.")
    @useAuth(WorkbenchSessionCookieAuth)
    @get
    get():
      | WorkbenchSession
      | UnauthorizedError
      | ForbiddenError
      | ServiceUnavailableError
      | InternalServerError;

    @doc("Bootstrap a loopback-only local session. The runtime sets qyl-workbench-session with HttpOnly and SameSite attributes, adds Secure when served over HTTPS, and never returns its value.")
    @post
    bootstrap():
      | WorkbenchSessionBootstrapResponse
      | UnauthorizedError
      | ForbiddenError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;
  }

  @route("/workbench/workspaces")
  @tag("Workbench workspaces")
  @useAuth(WorkbenchSessionCookieAuth)
  interface WorkbenchWorkspacesApi {
    @get
    list():
      | WorkbenchWorkspaceListResponse
      | UnauthorizedError
      | ForbiddenError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    create(@body request: WorkbenchWorkspaceCreateRequest):
      | WorkbenchWorkspace
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{workspace_id}")
    get(@path("workspace_id") workspaceId: WorkbenchWorkspaceId):
      | WorkbenchWorkspace
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @patch
    @route("/{workspace_id}")
    update(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @body request: WorkbenchWorkspaceUpdateRequest,
    ):
      | WorkbenchWorkspace
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @delete
    @route("/{workspace_id}")
    delete(@path("workspace_id") workspaceId: WorkbenchWorkspaceId):
      | WorkbenchDeleted
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{workspace_id}/preferences")
    getPreferences(@path("workspace_id") workspaceId: WorkbenchWorkspaceId):
      | WorkbenchWorkspacePreferences
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @put
    @route("/{workspace_id}/preferences")
    updatePreferences(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @body request: WorkbenchWorkspacePreferencesUpdateRequest,
    ):
      | WorkbenchWorkspacePreferences
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;
  }

  @route("/workbench/workspaces/{workspace_id}/servers")
  @tag("Workbench MCP servers")
  @useAuth(WorkbenchSessionCookieAuth)
  interface WorkbenchServersApi {
    @get
    list(@path("workspace_id") workspaceId: WorkbenchWorkspaceId):
      | WorkbenchServerListResponse
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    create(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @body request: WorkbenchServerCreateRequest,
    ):
      | WorkbenchServer
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{server_id}")
    get(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
    ):
      | WorkbenchServer
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @patch
    @route("/{server_id}")
    update(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
      @body request: WorkbenchServerUpdateRequest,
    ):
      | WorkbenchServer
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @delete
    @route("/{server_id}")
    delete(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
    ):
      | WorkbenchDeleted
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{server_id}/connect")
    connect(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
    ):
      | WorkbenchServerActionAccepted
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{server_id}/disconnect")
    disconnect(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
    ):
      | WorkbenchServerActionAccepted
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{server_id}/reconnect")
    reconnect(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
    ):
      | WorkbenchServerActionAccepted
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{server_id}/discovery")
    discovery(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
    ):
      | WorkbenchDiscoverySnapshot
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{server_id}/discovery/refresh")
    refreshDiscovery(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
    ):
      | WorkbenchDiscoverySnapshot
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{server_id}/protocol")
    protocolEvents(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
      @query cursor?: string,

      @query
      @minValue(1)
      @maxValue(1000)
      limit?: int32 = 200,
    ):
      | WorkbenchProtocolEventPage
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{server_id}/protocol/stream")
    streamProtocolEvents(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
      @header("Last-Event-ID") lastEventId?: string,
    ):
      | SSEStream<WorkbenchProtocolEvents>
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;
  }

  @route("/workbench/workspaces/{workspace_id}/servers/{server_id}/executions")
  @tag("Workbench MCP executions")
  @useAuth(WorkbenchSessionCookieAuth)
  interface WorkbenchExecutionsApi {
    @get
    @route("/stream")
    streamUpdates(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
      @query("execution_id") executionId?: WorkbenchExecutionId,
      @header("Last-Event-ID") lastEventId?: string,
    ):
      | SSEStream<WorkbenchExecutionUpdateEvents>
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    list(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
      @query status?: WorkbenchExecutionStatus,
      @query cursor?: string,

      @query
      @minValue(1)
      @maxValue(1000)
      limit?: int32 = 100,
    ):
      | WorkbenchExecutionPage
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    start(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
      @body request: WorkbenchExecutionRequest,
    ):
      | WorkbenchExecutionAccepted
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{execution_id}")
    get(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
      @path("execution_id") executionId: WorkbenchExecutionId,
    ):
      | WorkbenchExecutionRecord
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{execution_id}/cancel")
    cancel(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
      @path("execution_id") executionId: WorkbenchExecutionId,
      @body request: WorkbenchExecutionCancelRequest,
    ):
      | WorkbenchExecutionAccepted
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{execution_id}/telemetry")
    telemetry(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
      @path("execution_id") executionId: WorkbenchExecutionId,
    ):
      | WorkbenchExecutionTelemetryResponse
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;
  }

  @route("/workbench/workspaces/{workspace_id}/test-cases")
  @tag("Workbench MCP test cases")
  @useAuth(WorkbenchSessionCookieAuth)
  interface WorkbenchTestCasesApi {
    @get
    list(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @query("server_id") serverId?: WorkbenchServerId,
      @query("tool_name") toolName?: string,
      @query cursor?: string,

      @query
      @minValue(1)
      @maxValue(1000)
      limit?: int32 = 100,
    ):
      | WorkbenchTestCasePage
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    create(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @body request: WorkbenchTestCaseCreateRequest,
    ):
      | WorkbenchTestCase
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{test_case_id}")
    get(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("test_case_id") testCaseId: WorkbenchTestCaseId,
    ):
      | WorkbenchTestCase
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @patch
    @route("/{test_case_id}")
    update(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("test_case_id") testCaseId: WorkbenchTestCaseId,
      @body request: WorkbenchTestCaseUpdateRequest,
    ):
      | WorkbenchTestCase
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @delete
    @route("/{test_case_id}")
    delete(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("test_case_id") testCaseId: WorkbenchTestCaseId,
    ):
      | WorkbenchDeleted
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{test_case_id}/run")
    run(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("test_case_id") testCaseId: WorkbenchTestCaseId,
      @body request: WorkbenchTestCaseRunRequest,
    ):
      | WorkbenchEvaluationRunAccepted
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;
  }

  @route("/workbench/workspaces/{workspace_id}/suites")
  @tag("Workbench MCP suites")
  @useAuth(WorkbenchSessionCookieAuth)
  interface WorkbenchSuitesApi {
    @get
    list(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @query cursor?: string,

      @query
      @minValue(1)
      @maxValue(1000)
      limit?: int32 = 100,
    ):
      | WorkbenchTestSuitePage
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    create(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @body request: WorkbenchTestSuiteCreateRequest,
    ):
      | WorkbenchTestSuite
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{suite_id}")
    get(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("suite_id") suiteId: WorkbenchSuiteId,
    ):
      | WorkbenchTestSuite
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @patch
    @route("/{suite_id}")
    update(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("suite_id") suiteId: WorkbenchSuiteId,
      @body request: WorkbenchTestSuiteUpdateRequest,
    ):
      | WorkbenchTestSuite
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @delete
    @route("/{suite_id}")
    delete(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("suite_id") suiteId: WorkbenchSuiteId,
    ):
      | WorkbenchDeleted
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{suite_id}/run")
    run(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("suite_id") suiteId: WorkbenchSuiteId,
      @body request: WorkbenchSuiteRunRequest,
    ):
      | WorkbenchEvaluationRunAccepted
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;
  }

  @route("/workbench/workspaces/{workspace_id}/evaluation-runs")
  @tag("Workbench MCP evaluations")
  @useAuth(WorkbenchSessionCookieAuth)
  interface WorkbenchEvaluationRunsApi {
    @get
    list(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @query status?: WorkbenchEvaluationRunStatus,
      @query cursor?: string,

      @query
      @minValue(1)
      @maxValue(1000)
      limit?: int32 = 100,
    ):
      | WorkbenchEvaluationRunPage
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{evaluation_run_id}")
    get(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("evaluation_run_id") evaluationRunId: WorkbenchEvaluationRunId,
    ):
      | WorkbenchEvaluationRun
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/compare")
    compare(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @body request: WorkbenchEvaluationComparisonRequest,
    ):
      | WorkbenchEvaluationRunComparison
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    @route("/{evaluation_run_id}/export")
    export(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("evaluation_run_id") evaluationRunId: WorkbenchEvaluationRunId,
      @body request: WorkbenchEvaluationExportRequest,
    ):
      | WorkbenchEvaluationExportAccepted
      | ValidationError
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{evaluation_run_id}/exports/{export_id}")
    getExport(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("evaluation_run_id") evaluationRunId: WorkbenchEvaluationRunId,
      @path("export_id") exportId: WorkbenchEvaluationExportId,
    ):
      | WorkbenchEvaluationExport
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{evaluation_run_id}/exports/{export_id}/content")
    getExportContent(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("evaluation_run_id") evaluationRunId: WorkbenchEvaluationRunId,
      @path("export_id") exportId: WorkbenchEvaluationExportId,
    ):
      | WorkbenchEvaluationExportArtifact
      | UnauthorizedError
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;
  }
}
