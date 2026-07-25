import "@typespec/http";
import "@typespec/openapi3";

import "../common/types.tsp";
import "../otel/logs.tsp";
import "../otel/span.tsp";

using TypeSpec.Http;
using TypeSpec.OpenAPI;
using Qyl.Api.Contracts.Common;
using Qyl.Api.Contracts.OTel.Logs;
using Qyl.Api.Contracts.OTel.Traces;

namespace Qyl.Api.Contracts.Workbench;

@doc("""
  Opaque identifier for one authenticated local workbench session.

  Deliberately not Qyl.Api.Contracts.Common.SessionId, and not joinable with it.
  A workbench session is a loopback browser session owned by the local runner: it
  begins at cookie bootstrap, ends at logout or expiry, and never leaves the
  machine. A Common.SessionId is an OTel telemetry session observed in ingested
  spans, owned by the instrumented application, with its own lifetime and its own
  continuity chain. The two have no common issuer, so equal values would be
  coincidence. Correlate a workbench execution to telemetry through
  WorkbenchTelemetryCorrelation.traceIds, never by comparing session identifiers.
  """)
@minLength(1)
@maxLength(128)
scalar WorkbenchSessionId extends string;

@doc("Opaque identifier for one MCP workbench workspace.")
@minLength(1)
@maxLength(128)
scalar WorkbenchWorkspaceId extends string;

@doc("Opaque identifier for one configured MCP server.")
@minLength(1)
@maxLength(128)
scalar WorkbenchServerId extends string;

@doc("Opaque identifier for one asynchronous MCP tool execution.")
@minLength(1)
@maxLength(128)
scalar WorkbenchExecutionId extends string;

@doc("Opaque identifier for one reusable MCP test case.")
@minLength(1)
@maxLength(128)
scalar WorkbenchTestCaseId extends string;

@doc("Opaque identifier for one reusable MCP test suite.")
@minLength(1)
@maxLength(128)
scalar WorkbenchSuiteId extends string;

@doc("Opaque identifier for one MCP evaluation run.")
@minLength(1)
@maxLength(128)
scalar WorkbenchEvaluationRunId extends string;

@doc("Opaque identifier for one generated evaluation export.")
@minLength(1)
@maxLength(128)
scalar WorkbenchEvaluationExportId extends string;

@doc("Authenticated local principal metadata. No credential or session token is represented here.")
model WorkbenchPrincipalIdentity {
  id: string;
  @encodedName("application/json", "display_name")
  displayName?: string;
  local: true;
}

@doc("Metadata for the authenticated local workbench session. The HttpOnly session cookie is never returned in this model.")
model WorkbenchSession {
  id: WorkbenchSessionId;
  principal: WorkbenchPrincipalIdentity;
  @encodedName("application/json", "workspace_ids")
  workspaceIds: WorkbenchWorkspaceId[];
  @encodedName("application/json", "active_workspace_id")
  activeWorkspaceId?: WorkbenchWorkspaceId;
  @encodedName("application/json", "created_at")
  createdAt: utcDateTime;
  @encodedName("application/json", "expires_at")
  expiresAt?: utcDateTime;
}

@doc("Loopback session bootstrap response. The cookie value is carried only in Set-Cookie and never in the JSON body.")
model WorkbenchSessionBootstrapResponse extends WorkbenchSession {
  @doc("qyl-workbench-session cookie with HttpOnly, SameSite, Path, and expiry attributes; Secure is also present when served over HTTPS.")
  @header("Set-Cookie")
  setCookie: string;
}

@doc("One isolated MCP workbench workspace owned by the authenticated local principal.")
model WorkbenchWorkspace {
  id: WorkbenchWorkspaceId;
  @encodedName("application/json", "owner_id")
  ownerId: string;
  name: string;
  description?: string;
  @encodedName("application/json", "created_at")
  createdAt: utcDateTime;
  @encodedName("application/json", "updated_at")
  updatedAt: utcDateTime;
}

@doc("Request to create an isolated MCP workbench workspace.")
model WorkbenchWorkspaceCreateRequest {
  @minLength(1)
  @maxLength(120)
  name: string;

  @maxLength(2000)
  description?: string;
}

@doc("Request to update mutable MCP workbench workspace metadata.")
model WorkbenchWorkspaceUpdateRequest {
  @minLength(1)
  @maxLength(120)
  name?: string;

  @maxLength(2000)
  description?: string;
}

@doc("Workspaces visible to the authenticated local session.")
model WorkbenchWorkspaceListResponse {
  workspaces: WorkbenchWorkspace[];
}

@doc("Preferred tool-argument editor for one authenticated workspace.")
enum WorkbenchToolInputMode {
  form: "form",
  json: "json",
}

@doc("Saved presentation preferences isolated to one authenticated MCP workspace.")
model WorkbenchWorkspacePreferences {
  @encodedName("application/json", "workspace_id")
  workspaceId: WorkbenchWorkspaceId;
  @encodedName("application/json", "selected_server_id")
  selectedServerId?: WorkbenchServerId;

  @maxLength(1024)
  @encodedName("application/json", "selected_tool_name")
  selectedToolName?: string;

  @encodedName("application/json", "input_mode")
  inputMode: WorkbenchToolInputMode;

  @maxLength(128)
  @encodedName("application/json", "active_panel")
  activePanel?: string;

  @encodedName("application/json", "compact_mode")
  compactMode: boolean;
  @encodedName("application/json", "updated_at")
  updatedAt: utcDateTime;
}

@doc("Request to replace saved presentation preferences for one authenticated MCP workspace.")
model WorkbenchWorkspacePreferencesUpdateRequest {
  @encodedName("application/json", "selected_server_id")
  selectedServerId?: WorkbenchServerId;

  @maxLength(1024)
  @encodedName("application/json", "selected_tool_name")
  selectedToolName?: string;

  @encodedName("application/json", "input_mode")
  inputMode?: WorkbenchToolInputMode;

  @maxLength(128)
  @encodedName("application/json", "active_panel")
  activePanel?: string;

  @encodedName("application/json", "compact_mode")
  compactMode?: boolean;
}

@doc("Supported MCP server transport owned by the local workbench.")
enum WorkbenchTransportKind {
  stdio: "stdio",
  streamableHttp: "streamable_http",
  builtin: "builtin",
}

@doc("Reference to a secret resolved from the workbench environment. The environment value is never part of this contract.")
model WorkbenchSecretReference {
  source: "environment";

  @pattern("^[A-Za-z_][A-Za-z0-9_]*$")
  @encodedName("application/json", "environment_variable")
  environmentVariable: string;
}

@doc("Environment variable whose value is resolved from a secret reference at connection time.")
model WorkbenchEnvironmentSecretReference {
  @pattern("^[A-Za-z_][A-Za-z0-9_]*$")
  name: string;

  secret: WorkbenchSecretReference;
}

@doc("HTTP header whose value is resolved from a secret reference at connection time.")
model WorkbenchHeaderSecretReference {
  @minLength(1)
  name: string;

  secret: WorkbenchSecretReference;

  @doc("Optional HTTP authentication scheme applied to the resolved secret. Omit for a raw header value.")
  scheme?: WorkbenchHeaderSecretScheme;
}

@doc("HTTP authentication scheme applied to an environment-resolved header secret.")
enum WorkbenchHeaderSecretScheme {
  bearer: "bearer",
  basic: "basic",
}

@doc("Sanitized local stdio transport configuration. Arguments must not contain secrets.")
model WorkbenchStdioServerConfiguration {
  transport: "stdio";

  @minLength(1)
  command: string;

  arguments?: string[];
  @encodedName("application/json", "working_directory")
  workingDirectory?: string;
  environment?: WorkbenchEnvironmentSecretReference[];
}

@doc("Sanitized MCP Streamable HTTP transport configuration.")
model WorkbenchStreamableHttpServerConfiguration {
  transport: "streamable_http";
  endpoint: url;
  headers?: WorkbenchHeaderSecretReference[];
}

@doc("Sanitized built-in MCP server configuration.")
model WorkbenchBuiltinServerConfiguration {
  transport: "builtin";

  @minLength(1)
  name: string;
}

@doc("Exactly one sanitized MCP server transport configuration.")
@oneOf
union WorkbenchServerConfiguration {
  stdio: WorkbenchStdioServerConfiguration,
  streamableHttp: WorkbenchStreamableHttpServerConfiguration,
  builtin: WorkbenchBuiltinServerConfiguration,
}

@doc("Connection lifecycle for one configured MCP server.")
enum WorkbenchConnectionStatus {
  disconnected: "disconnected",
  connecting: "connecting",
  connected: "connected",
  disconnecting: "disconnecting",
  reconnecting: "reconnecting",
  failed: "failed",
}

@doc("Stable category for a workbench, transport, protocol, or tool execution error.")
enum WorkbenchErrorCategory {
  authentication: "authentication",
  transport: "transport",
  protocol: "protocol",
  serialization: "serialization",
  schemaValidation: "schema_validation",
  toolError: "tool_error",
  timeout: "timeout",
  cancelled: "cancelled",
  internal: "internal",
}

@doc("Typed, sanitized failure captured by the MCP workbench.")
model WorkbenchError {
  category: WorkbenchErrorCategory;
  code: string;
  message: string;
  @encodedName("application/json", "occurred_at")
  occurredAt: utcDateTime;
  retryable: boolean;

  @doc("Sanitized implementation details with credentials and secret values removed.")
  details?: unknown;
}

@doc("SDK-validated MCP initialize result projected through a Qyl-owned connection snapshot.")
model WorkbenchInitializationSnapshot {
  @encodedName("application/json", "initialized_at")
  initializedAt: utcDateTime;
  @encodedName("application/json", "protocol_version")
  protocolVersion: string;

  @doc("Opaque SDK server-info entity.")
  @encodedName("application/json", "server_identity")
  serverIdentity: unknown;

  @doc("Opaque SDK server-capabilities entity.")
  capabilities: unknown;

  instructions?: string;

  @doc("Opaque SDK session information when the transport exposes it.")
  @encodedName("application/json", "session_info")
  sessionInfo?: unknown;

  @doc("Complete opaque SDK initialize result.")
  result: unknown;
}

@doc("Current connection state and most recent initialization evidence for one MCP server.")
model WorkbenchConnectionSnapshot {
  status: WorkbenchConnectionStatus;
  @encodedName("application/json", "changed_at")
  changedAt: utcDateTime;
  @encodedName("application/json", "connected_at")
  connectedAt?: utcDateTime;
  @encodedName("application/json", "disconnected_at")
  disconnectedAt?: utcDateTime;
  initialization?: WorkbenchInitializationSnapshot;
  @encodedName("application/json", "recent_error")
  recentError?: WorkbenchError;
}

@doc("Persisted sanitized MCP server configuration and current runtime connection state.")
model WorkbenchServer {
  id: WorkbenchServerId;
  @encodedName("application/json", "workspace_id")
  workspaceId: WorkbenchWorkspaceId;
  name: string;
  description?: string;
  configuration: WorkbenchServerConfiguration;
  connection: WorkbenchConnectionSnapshot;
  @encodedName("application/json", "created_at")
  createdAt: utcDateTime;
  @encodedName("application/json", "updated_at")
  updatedAt: utcDateTime;
}

@doc("Request to add an MCP server configuration to a workspace.")
model WorkbenchServerCreateRequest {
  @minLength(1)
  @maxLength(120)
  name: string;

  @maxLength(2000)
  description?: string;

  configuration: WorkbenchServerConfiguration;
  @encodedName("application/json", "auto_connect")
  autoConnect?: boolean = false;
}

@doc("Request to replace mutable MCP server metadata or its complete sanitized transport configuration.")
model WorkbenchServerUpdateRequest {
  @minLength(1)
  @maxLength(120)
  name?: string;

  @maxLength(2000)
  description?: string;

  configuration?: WorkbenchServerConfiguration;
}

@doc("Configured MCP servers in one authenticated workspace.")
model WorkbenchServerListResponse {
  servers: WorkbenchServer[];
}

@doc("An MCP server connection action was accepted and continues asynchronously.")
model WorkbenchServerActionAccepted {
  @statusCode statusCode: 202;
  server: WorkbenchServer;
}

@doc("One discovered MCP entity collection. Every item remains the SDK-validated opaque entity.")
model WorkbenchDiscoveryCollection {
  items: unknown[];

  @minValue(0)
  count: int32;

  complete: boolean;
  cursor?: string;
  @encodedName("application/json", "next_cursor")
  nextCursor?: string;
  @encodedName("application/json", "discovered_at")
  discoveredAt: utcDateTime;
}

@doc("Complete MCP capability discovery evidence for one server.")
model WorkbenchDiscoverySnapshot {
  @encodedName("application/json", "server_id")
  serverId: WorkbenchServerId;
  @encodedName("application/json", "started_at")
  startedAt: utcDateTime;
  @encodedName("application/json", "completed_at")
  completedAt: utcDateTime;
  tools: WorkbenchDiscoveryCollection;
  resources: WorkbenchDiscoveryCollection;
  @encodedName("application/json", "resource_templates")
  resourceTemplates: WorkbenchDiscoveryCollection;
  prompts: WorkbenchDiscoveryCollection;
}

@doc("Direction of a captured MCP protocol or transport event.")
enum WorkbenchProtocolDirection {
  clientToServer: "client_to_server",
  serverToClient: "server_to_client",
  local: "local",
}

@doc("Kind of captured MCP protocol or transport event.")
enum WorkbenchProtocolEventKind {
  request: "request",
  response: "response",
  notification: "notification",
  error: "error",
  transport: "transport",
}

@doc("Chronological diagnostic event carrying only a redacted opaque SDK message or local transport payload.")
model WorkbenchProtocolEvent {
  id: string;
  @encodedName("application/json", "server_id")
  serverId: WorkbenchServerId;
  direction: WorkbenchProtocolDirection;
  kind: WorkbenchProtocolEventKind;
  method?: string;

  @doc("Opaque JSON-RPC request identifier, which may be a string or number.")
  @encodedName("application/json", "request_id")
  requestId?: unknown;

  timestamp: utcDateTime;
  @encodedName("application/json", "duration_ms")
  durationMs?: DurationMs;

  @doc("Opaque SDK message or transport payload after credential and secret redaction.")
  payload?: unknown;

  @encodedName("application/json", "redaction_applied")
  redactionApplied: true;
  @encodedName("application/json", "execution_id")
  executionId?: WorkbenchExecutionId;
  @encodedName("application/json", "trace_id")
  traceId?: TraceId;
}

@doc("Cursor page of chronological MCP protocol diagnostic events.")
model WorkbenchProtocolEventPage {
  events: WorkbenchProtocolEvent[];
  @encodedName("application/json", "next_cursor")
  nextCursor?: string;
}

@doc("How consequential the workbench considers an MCP tool invocation.")
enum WorkbenchExecutionEffect {
  readOnly: "read_only",
  consequential: "consequential",
  `unknown`: "unknown",
}

@doc("Client acknowledgement supplied when requesting a consequential MCP tool invocation.")
model WorkbenchExecutionConfirmationRequest {
  acknowledged: true;
  acknowledgement: string;
}

@doc("Server-timestamped confirmation evidence persisted for a consequential MCP tool invocation.")
model WorkbenchExecutionConfirmationEvidence {
  acknowledged: true;
  acknowledgement: string;
  @encodedName("application/json", "confirmed_at")
  confirmedAt: utcDateTime;
}

@doc("Request to asynchronously invoke one discovered MCP tool.")
model WorkbenchExecutionRequest {
  @minLength(1)
  @encodedName("application/json", "tool_name")
  toolName: string;

  @doc("Opaque tool arguments validated against the SDK tool schema before execution.")
  arguments?: unknown;

  @minValue(1)
  @maxValue(3600000)
  @encodedName("application/json", "timeout_ms")
  timeoutMs: int32 = 30000;

  confirmation?: WorkbenchExecutionConfirmationRequest;

  @minLength(8)
  @maxLength(256)
  @encodedName("application/json", "idempotency_key")
  idempotencyKey: string;
}

@doc("Asynchronous MCP execution lifecycle.")
enum WorkbenchExecutionStatus {
  queued: "queued",
  running: "running",
  cancelling: "cancelling",
  succeeded: "succeeded",
  failed: "failed",
  cancelled: "cancelled",
  timedOut: "timed_out",
}

@doc("Token usage reported or derived for one MCP execution when available.")
model WorkbenchExecutionTokenUsage {
  @encodedName("application/json", "input_tokens")
  inputTokens?: TokenCount;
  @encodedName("application/json", "output_tokens")
  outputTokens?: TokenCount;
  @encodedName("application/json", "total_tokens")
  totalTokens?: TokenCount;
  estimated: boolean;
}

@doc("USD cost reported or estimated for one MCP execution when available.")
model WorkbenchExecutionCost {
  @encodedName("application/json", "amount_usd")
  amountUsd: CostUsd;
  estimated: boolean;
  source?: string;
}

@doc("Qyl observability identifiers correlating workbench, MCP, and downstream activity.")
model WorkbenchTelemetryCorrelation {
  @encodedName("application/json", "execution_id")
  executionId?: WorkbenchExecutionId;
  @encodedName("application/json", "evaluation_run_id")
  evaluationRunId?: WorkbenchEvaluationRunId;
  @encodedName("application/json", "test_case_id")
  testCaseId?: WorkbenchTestCaseId;
  @encodedName("application/json", "trace_ids")
  traceIds: TraceId[];
  @encodedName("application/json", "span_ids")
  spanIds: SpanId[];
}

@doc("Persisted asynchronous execution evidence. SDK tool results remain opaque.")
model WorkbenchExecutionRecord {
  id: WorkbenchExecutionId;
  @encodedName("application/json", "workspace_id")
  workspaceId: WorkbenchWorkspaceId;
  @encodedName("application/json", "server_id")
  serverId: WorkbenchServerId;
  request: WorkbenchExecutionRequest;

  @doc("Server-derived effect from the SDK-validated discovered Tool and its annotations.")
  effect: WorkbenchExecutionEffect;

  confirmation?: WorkbenchExecutionConfirmationEvidence;
  status: WorkbenchExecutionStatus;
  @encodedName("application/json", "created_at")
  createdAt: utcDateTime;
  @encodedName("application/json", "started_at")
  startedAt?: utcDateTime;
  @encodedName("application/json", "completed_at")
  completedAt?: utcDateTime;
  @encodedName("application/json", "duration_ms")
  durationMs?: DurationMs;

  @minValue(0)
  @encodedName("application/json", "attempt_count")
  attemptCount: int32;

  @minValue(0)
  @encodedName("application/json", "retry_count")
  retryCount: int32;

  @encodedName("application/json", "cancel_requested_at")
  cancelRequestedAt?: utcDateTime;
  @encodedName("application/json", "cancelled_at")
  cancelledAt?: utcDateTime;

  @doc("Complete opaque SDK tool-call result after output sanitization.")
  result?: unknown;

  error?: WorkbenchError;
  @encodedName("application/json", "token_usage")
  tokenUsage?: WorkbenchExecutionTokenUsage;
  cost?: WorkbenchExecutionCost;
  telemetry?: WorkbenchTelemetryCorrelation;
}

@doc("An MCP execution was accepted and continues asynchronously.")
model WorkbenchExecutionAccepted {
  @statusCode statusCode: 202;
  execution: WorkbenchExecutionRecord;
}

@doc("Request to cancel an asynchronous MCP execution where the transport permits cancellation.")
model WorkbenchExecutionCancelRequest {
  @maxLength(1000)
  reason?: string;

  @minLength(8)
  @maxLength(256)
  @encodedName("application/json", "idempotency_key")
  idempotencyKey: string;
}

@doc("Cursor page of MCP execution records.")
model WorkbenchExecutionPage {
  executions: WorkbenchExecutionRecord[];
  @encodedName("application/json", "next_cursor")
  nextCursor?: string;
}

@doc("Whether correlated Qyl observability evidence was available.")
enum WorkbenchTelemetryAvailability {
  available: "available",
  partial: "partial",
  unavailable: "unavailable",
}

@doc("Availability and retained item count for one correlated Qyl telemetry signal.")
model WorkbenchTelemetrySignalAvailability {
  status: WorkbenchTelemetryAvailability;
  @encodedName("application/json", "unavailable_reason")
  unavailableReason?: string;

  @minValue(0)
  @encodedName("application/json", "item_count")
  itemCount: int32;
}

@doc("Per-signal availability for correlated workbench observability evidence.")
model WorkbenchTelemetrySignalSummary {
  traces: WorkbenchTelemetrySignalAvailability;
  logs: WorkbenchTelemetrySignalAvailability;
  exceptions: WorkbenchTelemetrySignalAvailability;
  @encodedName("application/json", "tool_call_events")
  toolCallEvents: WorkbenchTelemetrySignalAvailability;
}

@doc("Correlated Qyl observability evidence for one MCP execution. Signals unsupported by the connected Qyl read API are explicitly unavailable.")
model WorkbenchExecutionTelemetryResponse {
  signals: WorkbenchTelemetrySignalSummary;
  correlation: WorkbenchTelemetryCorrelation;
  traces: Trace[];
  logs: LogRecord[];
  @encodedName("application/json", "queried_at")
  queriedAt: utcDateTime;

  @doc("Confirms that workbench telemetry querying is excluded from workbench export instrumentation.")
  @encodedName("application/json", "self_export_suppressed")
  selfExportSuppressed: true;
}

@doc("Assertion outcome reported by an evaluation.")
enum WorkbenchAssertionStatus {
  passed: "passed",
  failed: "failed",
  error: "error",
  skipped: "skipped",
}

@doc("Execution-status assertion for an MCP test case.")
model WorkbenchStatusAssertion {
  id: string;
  kind: "status";

  @minItems(1)
  expected: WorkbenchExecutionStatus[];
}

@doc("Exact JSON value assertion at an optional JSON Pointer path.")
model WorkbenchExactAssertion {
  id: string;
  kind: "exact";
  path?: string;
  expected: unknown;
}

@doc("Partial JSON object or array containment assertion at an optional JSON Pointer path.")
model WorkbenchPartialAssertion {
  id: string;
  kind: "partial";
  path?: string;
  expected: unknown;
}

@doc("JSON Schema assertion at an optional JSON Pointer path.")
model WorkbenchSchemaAssertion {
  id: string;
  kind: "schema";
  path?: string;
  schema: unknown;
}

@doc("Regular-expression assertion at an optional JSON Pointer path.")
model WorkbenchPatternAssertion {
  id: string;
  kind: "pattern";
  path?: string;
  pattern: string;
  flags?: string;
}

@doc("Maximum execution latency assertion.")
model WorkbenchLatencyAssertion {
  id: string;
  kind: "latency";

  @minValue(0)
  @encodedName("application/json", "max_duration_ms")
  maxDurationMs: float64;
}

@doc("Exactly one supported MCP evaluation assertion.")
@oneOf
union WorkbenchTestAssertion {
  status: WorkbenchStatusAssertion,
  exact: WorkbenchExactAssertion,
  partial: WorkbenchPartialAssertion,
  schema: WorkbenchSchemaAssertion,
  pattern: WorkbenchPatternAssertion,
  latency: WorkbenchLatencyAssertion,
}

@doc("Reusable tool invocation and assertions persisted in one workspace.")
model WorkbenchTestCase {
  id: WorkbenchTestCaseId;
  @encodedName("application/json", "workspace_id")
  workspaceId: WorkbenchWorkspaceId;
  @encodedName("application/json", "server_id")
  serverId: WorkbenchServerId;
  name: string;
  description?: string;
  @encodedName("application/json", "tool_name")
  toolName: string;
  arguments?: unknown;

  @minValue(1)
  @maxValue(3600000)
  @encodedName("application/json", "timeout_ms")
  timeoutMs: int32;

  assertions: WorkbenchTestAssertion[];
  tags: string[];
  @encodedName("application/json", "created_at")
  createdAt: utcDateTime;
  @encodedName("application/json", "updated_at")
  updatedAt: utcDateTime;
}

@doc("Request to create a reusable MCP test case.")
model WorkbenchTestCaseCreateRequest {
  @encodedName("application/json", "server_id")
  serverId: WorkbenchServerId;

  @minLength(1)
  @maxLength(160)
  name: string;

  @maxLength(4000)
  description?: string;

  @minLength(1)
  @encodedName("application/json", "tool_name")
  toolName: string;

  arguments?: unknown;

  @minValue(1)
  @maxValue(3600000)
  @encodedName("application/json", "timeout_ms")
  timeoutMs: int32 = 30000;

  @minItems(1)
  assertions: WorkbenchTestAssertion[];

  tags?: string[];
}

@doc("Request to update mutable MCP test-case fields.")
model WorkbenchTestCaseUpdateRequest {
  @encodedName("application/json", "server_id")
  serverId?: WorkbenchServerId;

  @minLength(1)
  @maxLength(160)
  name?: string;

  @maxLength(4000)
  description?: string;

  @minLength(1)
  @encodedName("application/json", "tool_name")
  toolName?: string;

  arguments?: unknown;

  @minValue(1)
  @maxValue(3600000)
  @encodedName("application/json", "timeout_ms")
  timeoutMs?: int32;

  @minItems(1)
  assertions?: WorkbenchTestAssertion[];

  tags?: string[];
}

@doc("Cursor page of reusable MCP test cases.")
model WorkbenchTestCasePage {
  @encodedName("application/json", "test_cases")
  testCases: WorkbenchTestCase[];
  @encodedName("application/json", "next_cursor")
  nextCursor?: string;
}

@doc("Reusable ordered group of MCP test cases.")
model WorkbenchTestSuite {
  id: WorkbenchSuiteId;
  @encodedName("application/json", "workspace_id")
  workspaceId: WorkbenchWorkspaceId;
  name: string;
  description?: string;

  @minItems(1)
  @encodedName("application/json", "test_case_ids")
  testCaseIds: WorkbenchTestCaseId[];

  tags: string[];
  @encodedName("application/json", "created_at")
  createdAt: utcDateTime;
  @encodedName("application/json", "updated_at")
  updatedAt: utcDateTime;
}

@doc("Request to create a reusable MCP test suite.")
model WorkbenchTestSuiteCreateRequest {
  @minLength(1)
  @maxLength(160)
  name: string;

  @maxLength(4000)
  description?: string;

  @minItems(1)
  @encodedName("application/json", "test_case_ids")
  testCaseIds: WorkbenchTestCaseId[];

  tags?: string[];
}

@doc("Request to update mutable MCP test-suite fields.")
model WorkbenchTestSuiteUpdateRequest {
  @minLength(1)
  @maxLength(160)
  name?: string;

  @maxLength(4000)
  description?: string;

  @minItems(1)
  @encodedName("application/json", "test_case_ids")
  testCaseIds?: WorkbenchTestCaseId[];

  tags?: string[];
}

@doc("Cursor page of reusable MCP test suites.")
model WorkbenchTestSuitePage {
  suites: WorkbenchTestSuite[];
  @encodedName("application/json", "next_cursor")
  nextCursor?: string;
}

@doc("Request to execute one test case or suite asynchronously.")
model WorkbenchEvaluationRunRequest {
  @minLength(8)
  @maxLength(256)
  @encodedName("application/json", "idempotency_key")
  idempotencyKey: string;

  confirmation?: WorkbenchExecutionConfirmationRequest;

  @minValue(1)
  @maxValue(50)
  concurrency?: int32 = 1;

  @encodedName("application/json", "fail_fast")
  failFast?: boolean = false;
}

@doc("Request to run one persisted MCP test case asynchronously.")
model WorkbenchTestCaseRunRequest extends WorkbenchEvaluationRunRequest {}

@doc("Request to run a complete suite or an explicit subset of its persisted test cases asynchronously.")
model WorkbenchSuiteRunRequest extends WorkbenchEvaluationRunRequest {
  @minItems(1)
  @encodedName("application/json", "selected_test_case_ids")
  selectedTestCaseIds?: WorkbenchTestCaseId[];
}

@doc("Lifecycle for an MCP evaluation run.")
enum WorkbenchEvaluationRunStatus {
  queued: "queued",
  running: "running",
  completed: "completed",
  failed: "failed",
  cancelled: "cancelled",
}

@doc("Outcome for one test case within an evaluation run.")
enum WorkbenchEvaluationResultStatus {
  passed: "passed",
  failed: "failed",
  error: "error",
  skipped: "skipped",
}

@doc("Outcome of one assertion with sanitized actual evidence when useful.")
model WorkbenchAssertionResult {
  @encodedName("application/json", "assertion_id")
  assertionId: string;
  kind: string;
  status: WorkbenchAssertionStatus;
  message?: string;
  actual?: unknown;
}

@doc("Immutable reusable-test definition captured when an evaluation run starts.")
model WorkbenchEvaluationTestCaseSnapshot {
  id: WorkbenchTestCaseId;
  @encodedName("application/json", "server_id")
  serverId: WorkbenchServerId;
  name: string;
  description?: string;
  @encodedName("application/json", "tool_name")
  toolName: string;
  arguments?: unknown;
  @encodedName("application/json", "timeout_ms")
  timeoutMs: int32;
  assertions: WorkbenchTestAssertion[];
  tags: string[];
}

@doc("Immutable suite definition captured when an evaluation run starts.")
model WorkbenchEvaluationSuiteSnapshot {
  id: WorkbenchSuiteId;
  name: string;
  description?: string;
  @encodedName("application/json", "test_case_ids")
  testCaseIds: WorkbenchTestCaseId[];
  tags: string[];
}

@doc("One test-case result retained by an MCP evaluation run.")
model WorkbenchEvaluationTestResult {
  @encodedName("application/json", "test_case")
  testCase: WorkbenchEvaluationTestCaseSnapshot;
  @encodedName("application/json", "execution_id")
  executionId?: WorkbenchExecutionId;
  status: WorkbenchEvaluationResultStatus;
  @encodedName("application/json", "started_at")
  startedAt?: utcDateTime;
  @encodedName("application/json", "completed_at")
  completedAt?: utcDateTime;
  @encodedName("application/json", "duration_ms")
  durationMs?: DurationMs;
  assertions: WorkbenchAssertionResult[];
  error?: WorkbenchError;
}

@doc("Aggregate correctness, reliability, latency, usage, and cost for an MCP evaluation run.")
model WorkbenchEvaluationSummary {
  @minValue(0)
  total: int32;

  @minValue(0)
  passed: int32;

  @minValue(0)
  failed: int32;

  @minValue(0)
  errors: int32;

  @minValue(0)
  skipped: int32;

  @encodedName("application/json", "success_rate")
  successRate: Ratio;
  reliability: Ratio;
  @encodedName("application/json", "mean_duration_ms")
  meanDurationMs?: DurationMs;
  @encodedName("application/json", "p50_duration_ms")
  p50DurationMs?: DurationMs;
  @encodedName("application/json", "p95_duration_ms")
  p95DurationMs?: DurationMs;
  @encodedName("application/json", "p99_duration_ms")
  p99DurationMs?: DurationMs;
  @encodedName("application/json", "token_usage")
  tokenUsage?: WorkbenchExecutionTokenUsage;
  cost?: WorkbenchExecutionCost;
}

@doc("Asynchronous MCP evaluation run with retained per-test evidence.")
model WorkbenchEvaluationRun {
  id: WorkbenchEvaluationRunId;
  @encodedName("application/json", "workspace_id")
  workspaceId: WorkbenchWorkspaceId;
  suite?: WorkbenchEvaluationSuiteSnapshot;
  @encodedName("application/json", "test_cases")
  testCases: WorkbenchEvaluationTestCaseSnapshot[];
  status: WorkbenchEvaluationRunStatus;
  @encodedName("application/json", "created_at")
  createdAt: utcDateTime;
  @encodedName("application/json", "started_at")
  startedAt?: utcDateTime;
  @encodedName("application/json", "completed_at")
  completedAt?: utcDateTime;
  results: WorkbenchEvaluationTestResult[];
  summary?: WorkbenchEvaluationSummary;
  confirmation?: WorkbenchExecutionConfirmationEvidence;
  telemetry?: WorkbenchTelemetryCorrelation;
  error?: WorkbenchError;
}

@doc("An MCP evaluation run was accepted and continues asynchronously.")
model WorkbenchEvaluationRunAccepted {
  @statusCode statusCode: 202;
  run: WorkbenchEvaluationRun;
}

@doc("Cursor page of MCP evaluation runs.")
model WorkbenchEvaluationRunPage {
  runs: WorkbenchEvaluationRun[];
  @encodedName("application/json", "next_cursor")
  nextCursor?: string;
}

@doc("Request to compare a baseline MCP evaluation run with a candidate run.")
model WorkbenchEvaluationComparisonRequest {
  @encodedName("application/json", "baseline_run_id")
  baselineRunId: WorkbenchEvaluationRunId;
  @encodedName("application/json", "candidate_run_id")
  candidateRunId: WorkbenchEvaluationRunId;
}

@doc("Regression classification for one test case across two evaluation runs.")
enum WorkbenchRegressionStatus {
  improved: "improved",
  regressed: "regressed",
  unchanged: "unchanged",
  added: "added",
  removed: "removed",
}

@doc("Per-test comparison across a baseline and candidate MCP evaluation run.")
model WorkbenchEvaluationTestComparison {
  @encodedName("application/json", "test_case_id")
  testCaseId: WorkbenchTestCaseId;
  status: WorkbenchRegressionStatus;
  @encodedName("application/json", "baseline_status")
  baselineStatus?: WorkbenchEvaluationResultStatus;
  @encodedName("application/json", "candidate_status")
  candidateStatus?: WorkbenchEvaluationResultStatus;
  @encodedName("application/json", "duration_delta_ms")
  durationDeltaMs?: float64;
}

@doc("Aggregate comparison of two completed MCP evaluation runs.")
model WorkbenchEvaluationRunComparison {
  @encodedName("application/json", "baseline_run_id")
  baselineRunId: WorkbenchEvaluationRunId;
  @encodedName("application/json", "candidate_run_id")
  candidateRunId: WorkbenchEvaluationRunId;
  baseline: WorkbenchEvaluationSummary;
  candidate: WorkbenchEvaluationSummary;
  @encodedName("application/json", "success_rate_delta")
  successRateDelta: float64;
  @encodedName("application/json", "reliability_delta")
  reliabilityDelta: float64;
  @encodedName("application/json", "p95_duration_delta_ms")
  p95DurationDeltaMs?: float64;
  @encodedName("application/json", "token_delta")
  tokenDelta?: int64;
  @encodedName("application/json", "cost_delta_usd")
  costDeltaUsd?: float64;
  tests: WorkbenchEvaluationTestComparison[];
  @encodedName("application/json", "compared_at")
  comparedAt: utcDateTime;
}

@doc("Supported evaluation export representation.")
enum WorkbenchEvaluationExportFormat {
  json: "json",
  report: "report",
}

@doc("Request to generate a machine-readable or readable evaluation export.")
model WorkbenchEvaluationExportRequest {
  format: WorkbenchEvaluationExportFormat;
  @encodedName("application/json", "include_protocol_events")
  includeProtocolEvents?: boolean = true;
  @encodedName("application/json", "include_telemetry")
  includeTelemetry?: boolean = true;

  @minLength(8)
  @maxLength(256)
  @encodedName("application/json", "idempotency_key")
  idempotencyKey: string;
}

@doc("Lifecycle for generation of an evaluation export artifact.")
enum WorkbenchEvaluationExportStatus {
  pending: "pending",
  ready: "ready",
  failed: "failed",
}

@doc("Metadata for one generated evaluation JSON or readable report artifact.")
model WorkbenchEvaluationExport {
  id: WorkbenchEvaluationExportId;
  @encodedName("application/json", "run_id")
  runId: WorkbenchEvaluationRunId;
  format: WorkbenchEvaluationExportFormat;
  status: WorkbenchEvaluationExportStatus;
  @encodedName("application/json", "requested_at")
  requestedAt: utcDateTime;
  @encodedName("application/json", "completed_at")
  completedAt?: utcDateTime;
  @encodedName("application/json", "media_type")
  mediaType?: string;
  @encodedName("application/json", "file_name")
  fileName?: string;
  @encodedName("application/json", "byte_size")
  byteSize?: ByteSize;
  sha256?: Sha256Hash;
  error?: WorkbenchError;
}

@doc("Machine-readable evaluation export with retained execution, protocol, and optional telemetry evidence.")
model WorkbenchEvaluationJsonExportPayload {
  format: "json";
  run: WorkbenchEvaluationRun;
  @encodedName("application/json", "protocol_events")
  protocolEvents: WorkbenchProtocolEvent[];
  telemetry: WorkbenchExecutionTelemetryResponse[];
  @encodedName("application/json", "exported_at")
  exportedAt: utcDateTime;
}

@doc("Human-readable Markdown evaluation report.")
model WorkbenchEvaluationReportExportPayload {
  format: "report";
  markdown: string;
  @encodedName("application/json", "exported_at")
  exportedAt: utcDateTime;
}

@doc("Exactly one generated evaluation export representation.")
@oneOf
union WorkbenchEvaluationExportPayload {
  json: WorkbenchEvaluationJsonExportPayload,
  report: WorkbenchEvaluationReportExportPayload,
}

@doc("Ready evaluation export metadata and its TypeSpec-owned content.")
model WorkbenchEvaluationExportArtifact {
  export: WorkbenchEvaluationExport;
  payload: WorkbenchEvaluationExportPayload;
}

@doc("An evaluation export was accepted and continues asynchronously.")
model WorkbenchEvaluationExportAccepted {
  @statusCode statusCode: 202;
  export: WorkbenchEvaluationExport;
}

@doc("Successful deletion with no response body.")
model WorkbenchDeleted {
  @statusCode statusCode: 204;
}
