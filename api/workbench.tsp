import "@typespec/events";
import "@typespec/http";
import "@typespec/sse";

import "../common/errors.tsp";
import "../common/pagination.tsp";
import "../models/workbench.tsp";

using TypeSpec.Events;
using TypeSpec.Http;
using TypeSpec.SSE;

using Qyl.Api.Contracts.Common.Errors;
using Qyl.Api.Contracts.Common.Pagination;
using Qyl.Api.Contracts.Workbench;

namespace TypeSpec.Http {
  @doc("HttpOnly local workbench session cookie. The cookie value is never exposed by a product DTO.")
  model WorkbenchSessionCookieAuth
    is ApiKeyAuth<ApiKeyLocation.cookie, "qyl-workbench-session">;
}

namespace Qyl.Api.Contracts.Workbench {
  // Problem bodies carry no headers (common/errors.tsp). The workbench answers
  // a missing or invalid session cookie with a challenge naming its scheme, so
  // its 401 declares the header here, on the workbench operations.
  @doc("The local workbench session cookie is missing or invalid (401). `WWW-Authenticate` names the `Cookie` scheme.")
  @error
  model WorkbenchUnauthorizedResponse {
    @doc("Authentication challenge. The workbench sends `Cookie`.")
    @header("WWW-Authenticate")
    wwwAuthenticate: string;

    @bodyRoot problem: UnauthorizedError;
  }

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
      | WorkbenchUnauthorizedResponse
      | ForbiddenError
      | ServiceUnavailableError
      | InternalServerError;

    @doc("Bootstrap a loopback-only local session. The runtime sets qyl-workbench-session with HttpOnly and SameSite attributes, adds Secure when served over HTTPS, and never returns its value.")
    @post
    bootstrap():
      | WorkbenchSessionBootstrapResponse
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
      | ForbiddenError
      | ServiceUnavailableError
      | InternalServerError;

    @post
    create(@body request: WorkbenchWorkspaceCreateRequest):
      | WorkbenchWorkspace
      | ValidationError
      | WorkbenchUnauthorizedResponse
      | ForbiddenError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{workspace_id}")
    get(@path("workspace_id") workspaceId: WorkbenchWorkspaceId):
      | WorkbenchWorkspace
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @delete
    @route("/{workspace_id}")
    delete(@path("workspace_id") workspaceId: WorkbenchWorkspaceId):
      | WorkbenchDeleted
      | WorkbenchUnauthorizedResponse
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;

    @get
    @route("/{workspace_id}/preferences")
    getPreferences(@path("workspace_id") workspaceId: WorkbenchWorkspaceId):
      | WorkbenchWorkspacePreferences
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | BadGatewayError
      | ServiceUnavailableError
      | InternalServerError;

    @list
    @get
    @route("/{server_id}/protocol")
    protocolEvents(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
      ...CursorPageQuery,
    ):
      | WorkbenchProtocolEventPage
      | ValidationError
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;

    @list
    @get
    list(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @path("server_id") serverId: WorkbenchServerId,
      @query status?: WorkbenchExecutionStatus,
      ...CursorPageQuery,
    ):
      | WorkbenchExecutionPage
      | ValidationError
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
      | ForbiddenError
      | NotFoundError
      | ServiceUnavailableError
      | InternalServerError;
  }

  @route("/workbench/workspaces/{workspace_id}/test-cases")
  @tag("Workbench MCP test cases")
  @useAuth(WorkbenchSessionCookieAuth)
  interface WorkbenchTestCasesApi {
    @list
    @get
    list(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @query("server_id") serverId?: WorkbenchServerId,
      @query("tool_name") toolName?: string,
      ...CursorPageQuery,
    ):
      | WorkbenchTestCasePage
      | ValidationError
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
    @list
    @get
    list(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      ...CursorPageQuery,
    ):
      | WorkbenchTestSuitePage
      | ValidationError
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
    @list
    @get
    list(
      @path("workspace_id") workspaceId: WorkbenchWorkspaceId,
      @query status?: WorkbenchEvaluationRunStatus,
      ...CursorPageQuery,
    ):
      | WorkbenchEvaluationRunPage
      | ValidationError
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
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
      | WorkbenchUnauthorizedResponse
      | ForbiddenError
      | NotFoundError
      | ConflictError
      | ServiceUnavailableError
      | InternalServerError;
  }
}
