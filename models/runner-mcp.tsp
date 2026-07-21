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

namespace Qyl.Api.Contracts.Runner.Mcp;

@doc("Opaque identifier for one authenticated local runner session.")
@minLength(1)
@maxLength(128)
scalar RunnerMcpSessionId extends string;

@doc("Opaque identifier for one MCP workbench workspace.")
@minLength(1)
@maxLength(128)
scalar RunnerMcpWorkspaceId extends string;

@doc("Opaque identifier for one configured MCP server.")
@minLength(1)
@maxLength(128)
scalar RunnerMcpServerId extends string;

@doc("Opaque identifier for one asynchronous MCP tool execution.")
@minLength(1)
@maxLength(128)
scalar RunnerMcpExecutionId extends string;

@doc("Opaque identifier for one reusable MCP test case.")
@minLength(1)
@maxLength(128)
scalar RunnerMcpTestCaseId extends string;

@doc("Opaque identifier for one reusable MCP test suite.")
@minLength(1)
@maxLength(128)
scalar RunnerMcpSuiteId extends string;

@doc("Opaque identifier for one MCP evaluation run.")
@minLength(1)
@maxLength(128)
scalar RunnerMcpEvaluationRunId extends string;

@doc("Opaque identifier for one generated evaluation export.")
@minLength(1)
@maxLength(128)
scalar RunnerMcpEvaluationExportId extends string;

@doc("Authenticated local principal metadata. No credential or session token is represented here.")
model RunnerMcpPrincipalIdentity {
  id: string;
  displayName?: string;
  local: true;
}

@doc("Metadata for the authenticated local workbench session. The HttpOnly session cookie is never returned in this model.")
model RunnerMcpWorkbenchSession {
  id: RunnerMcpSessionId;
  principal: RunnerMcpPrincipalIdentity;
  workspaceIds: RunnerMcpWorkspaceId[];
  activeWorkspaceId?: RunnerMcpWorkspaceId;
  createdAt: utcDateTime;
  expiresAt?: utcDateTime;
}

@doc("Loopback session bootstrap response. The cookie value is carried only in Set-Cookie and never in the JSON body.")
model RunnerMcpSessionBootstrapResponse extends RunnerMcpWorkbenchSession {
  @doc("qyl-mcp-session cookie with HttpOnly, SameSite, Path, and expiry attributes; Secure is also present when served over HTTPS.")
  @header("Set-Cookie")
  setCookie: string;
}

@doc("One isolated MCP workbench workspace owned by the authenticated local principal.")
model RunnerMcpWorkspace {
  id: RunnerMcpWorkspaceId;
  ownerId: string;
  name: string;
  description?: string;
  createdAt: utcDateTime;
  updatedAt: utcDateTime;
}

@doc("Request to create an isolated MCP workbench workspace.")
model RunnerMcpWorkspaceCreateRequest {
  @minLength(1)
  @maxLength(120)
  name: string;

  @maxLength(2000)
  description?: string;
}

@doc("Request to update mutable MCP workbench workspace metadata.")
model RunnerMcpWorkspaceUpdateRequest {
  @minLength(1)
  @maxLength(120)
  name?: string;

  @maxLength(2000)
  description?: string;
}

@doc("Workspaces visible to the authenticated local session.")
model RunnerMcpWorkspaceListResponse {
  workspaces: RunnerMcpWorkspace[];
}

@doc("Preferred tool-argument editor for one authenticated workspace.")
enum RunnerMcpToolInputMode {
  form: "form",
  json: "json",
}

@doc("Saved presentation preferences isolated to one authenticated MCP workspace.")
model RunnerMcpWorkspacePreferences {
  workspaceId: RunnerMcpWorkspaceId;
  selectedServerId?: RunnerMcpServerId;

  @maxLength(1024)
  selectedToolName?: string;

  inputMode: RunnerMcpToolInputMode;

  @maxLength(128)
  activePanel?: string;

  compactMode: boolean;
  updatedAt: utcDateTime;
}

@doc("Request to replace saved presentation preferences for one authenticated MCP workspace.")
model RunnerMcpWorkspacePreferencesUpdateRequest {
  selectedServerId?: RunnerMcpServerId;

  @maxLength(1024)
  selectedToolName?: string;

  inputMode?: RunnerMcpToolInputMode;

  @maxLength(128)
  activePanel?: string;

  compactMode?: boolean;
}

@doc("Supported MCP server transport owned by the local runner.")
enum RunnerMcpTransportKind {
  stdio: "stdio",
  streamableHttp: "streamable_http",
  sse: "sse",
  inproc: "inproc",
  builtin: "builtin",
}

@doc("Reference to a secret resolved from the runner environment. The environment value is never part of this contract.")
model RunnerMcpSecretReference {
  source: "environment";

  @pattern("^[A-Za-z_][A-Za-z0-9_]*$")
  environmentVariable: string;
}

@doc("Environment variable whose value is resolved from a secret reference at connection time.")
model RunnerMcpEnvironmentSecretReference {
  @pattern("^[A-Za-z_][A-Za-z0-9_]*$")
  name: string;

  secret: RunnerMcpSecretReference;
}

@doc("HTTP header whose value is resolved from a secret reference at connection time.")
model RunnerMcpHeaderSecretReference {
  @minLength(1)
  name: string;

  secret: RunnerMcpSecretReference;

  @doc("Optional HTTP authentication scheme applied to the resolved secret. Omit for a raw header value.")
  scheme?: RunnerMcpHeaderSecretScheme;
}

@doc("HTTP authentication scheme applied to an environment-resolved header secret.")
enum RunnerMcpHeaderSecretScheme {
  bearer: "bearer",
  basic: "basic",
}

@doc("Sanitized local stdio transport configuration. Arguments must not contain secrets.")
model RunnerMcpStdioServerConfiguration {
  transport: "stdio";

  @minLength(1)
  command: string;

  arguments?: string[];
  workingDirectory?: string;
  environment?: RunnerMcpEnvironmentSecretReference[];
}

@doc("Sanitized MCP Streamable HTTP transport configuration.")
model RunnerMcpStreamableHttpServerConfiguration {
  transport: "streamable_http";
  endpoint: url;
  headers?: RunnerMcpHeaderSecretReference[];
}

@doc("Sanitized legacy MCP SSE transport configuration.")
model RunnerMcpSseServerConfiguration {
  transport: "sse";
  endpoint: url;
  headers?: RunnerMcpHeaderSecretReference[];
}

@doc("Sanitized in-process MCP server configuration.")
model RunnerMcpInProcessServerConfiguration {
  transport: "inproc";

  @minLength(1)
  implementation: string;
}

@doc("Sanitized built-in MCP server configuration.")
model RunnerMcpBuiltinServerConfiguration {
  transport: "builtin";

  @minLength(1)
  name: string;
}

@doc("Exactly one sanitized MCP server transport configuration.")
@oneOf
union RunnerMcpServerConfiguration {
  stdio: RunnerMcpStdioServerConfiguration,
  streamableHttp: RunnerMcpStreamableHttpServerConfiguration,
  sse: RunnerMcpSseServerConfiguration,
  inproc: RunnerMcpInProcessServerConfiguration,
  builtin: RunnerMcpBuiltinServerConfiguration,
}

@doc("Connection lifecycle for one configured MCP server.")
enum RunnerMcpConnectionStatus {
  disconnected: "disconnected",
  connecting: "connecting",
  connected: "connected",
  disconnecting: "disconnecting",
  reconnecting: "reconnecting",
  failed: "failed",
}

@doc("Stable category for a workbench, transport, protocol, or tool execution error.")
enum RunnerMcpErrorCategory {
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
model RunnerMcpError {
  category: RunnerMcpErrorCategory;
  code: string;
  message: string;
  occurredAt: utcDateTime;
  retryable: boolean;

  @doc("Sanitized implementation details with credentials and secret values removed.")
  details?: unknown;
}

@doc("SDK-validated MCP initialize result projected through a Qyl-owned connection snapshot.")
model RunnerMcpInitializationSnapshot {
  initializedAt: utcDateTime;
  protocolVersion: string;

  @doc("Opaque SDK server-info entity.")
  serverIdentity: unknown;

  @doc("Opaque SDK server-capabilities entity.")
  capabilities: unknown;

  instructions?: string;

  @doc("Opaque SDK session information when the transport exposes it.")
  sessionInfo?: unknown;

  @doc("Complete opaque SDK initialize result.")
  result: unknown;
}

@doc("Current connection state and most recent initialization evidence for one MCP server.")
model RunnerMcpConnectionSnapshot {
  status: RunnerMcpConnectionStatus;
  changedAt: utcDateTime;
  connectedAt?: utcDateTime;
  disconnectedAt?: utcDateTime;
  initialization?: RunnerMcpInitializationSnapshot;
  recentError?: RunnerMcpError;
}

@doc("Persisted sanitized MCP server configuration and current runtime connection state.")
model RunnerMcpServer {
  id: RunnerMcpServerId;
  workspaceId: RunnerMcpWorkspaceId;
  name: string;
  description?: string;
  configuration: RunnerMcpServerConfiguration;
  connection: RunnerMcpConnectionSnapshot;
  createdAt: utcDateTime;
  updatedAt: utcDateTime;
}

@doc("Request to add an MCP server configuration to a workspace.")
model RunnerMcpServerCreateRequest {
  @minLength(1)
  @maxLength(120)
  name: string;

  @maxLength(2000)
  description?: string;

  configuration: RunnerMcpServerConfiguration;
  autoConnect?: boolean = false;
}

@doc("Request to replace mutable MCP server metadata or its complete sanitized transport configuration.")
model RunnerMcpServerUpdateRequest {
  @minLength(1)
  @maxLength(120)
  name?: string;

  @maxLength(2000)
  description?: string;

  configuration?: RunnerMcpServerConfiguration;
}

@doc("Configured MCP servers in one authenticated workspace.")
model RunnerMcpServerListResponse {
  servers: RunnerMcpServer[];
}

@doc("An MCP server connection action was accepted and continues asynchronously.")
model RunnerMcpServerActionAccepted {
  @statusCode statusCode: 202;
  server: RunnerMcpServer;
}

@doc("One discovered MCP entity collection. Every item remains the SDK-validated opaque entity.")
model RunnerMcpDiscoveryCollection {
  items: unknown[];

  @minValue(0)
  count: int32;

  complete: boolean;
  cursor?: string;
  nextCursor?: string;
  discoveredAt: utcDateTime;
}

@doc("Complete MCP capability discovery evidence for one server.")
model RunnerMcpDiscoverySnapshot {
  serverId: RunnerMcpServerId;
  startedAt: utcDateTime;
  completedAt: utcDateTime;
  tools: RunnerMcpDiscoveryCollection;
  resources: RunnerMcpDiscoveryCollection;
  resourceTemplates: RunnerMcpDiscoveryCollection;
  prompts: RunnerMcpDiscoveryCollection;
}

@doc("Direction of a captured MCP protocol or transport event.")
enum RunnerMcpProtocolDirection {
  clientToServer: "client_to_server",
  serverToClient: "server_to_client",
  local: "local",
}

@doc("Kind of captured MCP protocol or transport event.")
enum RunnerMcpProtocolEventKind {
  request: "request",
  response: "response",
  notification: "notification",
  error: "error",
  transport: "transport",
}

@doc("Chronological diagnostic event carrying only a redacted opaque SDK message or local transport payload.")
model RunnerMcpProtocolEvent {
  id: string;
  serverId: RunnerMcpServerId;
  direction: RunnerMcpProtocolDirection;
  kind: RunnerMcpProtocolEventKind;
  method?: string;

  @doc("Opaque JSON-RPC request identifier, which may be a string or number.")
  requestId?: unknown;

  timestamp: utcDateTime;
  durationMs?: DurationMs;

  @doc("Opaque SDK message or transport payload after credential and secret redaction.")
  payload?: unknown;

  redactionApplied: true;
  executionId?: RunnerMcpExecutionId;
  traceId?: TraceId;
}

@doc("Cursor page of chronological MCP protocol diagnostic events.")
model RunnerMcpProtocolEventPage {
  events: RunnerMcpProtocolEvent[];
  nextCursor?: string;
}

@doc("How consequential the workbench considers an MCP tool invocation.")
enum RunnerMcpExecutionEffect {
  readOnly: "read_only",
  consequential: "consequential",
  `unknown`: "unknown",
}

@doc("Client acknowledgement supplied when requesting a consequential MCP tool invocation.")
model RunnerMcpExecutionConfirmationRequest {
  acknowledged: true;
  acknowledgement: string;
}

@doc("Server-timestamped confirmation evidence persisted for a consequential MCP tool invocation.")
model RunnerMcpExecutionConfirmationEvidence {
  acknowledged: true;
  acknowledgement: string;
  confirmedAt: utcDateTime;
}

@doc("Request to asynchronously invoke one discovered MCP tool.")
model RunnerMcpExecutionRequest {
  @minLength(1)
  toolName: string;

  @doc("Opaque tool arguments validated against the SDK tool schema before execution.")
  arguments?: unknown;

  @minValue(1)
  @maxValue(3600000)
  timeoutMs: int32 = 30000;

  confirmation?: RunnerMcpExecutionConfirmationRequest;

  @minLength(8)
  @maxLength(256)
  idempotencyKey: string;
}

@doc("Asynchronous MCP execution lifecycle.")
enum RunnerMcpExecutionStatus {
  queued: "queued",
  running: "running",
  cancelling: "cancelling",
  succeeded: "succeeded",
  failed: "failed",
  cancelled: "cancelled",
  timedOut: "timed_out",
}

@doc("Token usage reported or derived for one MCP execution when available.")
model RunnerMcpExecutionTokenUsage {
  inputTokens?: TokenCount;
  outputTokens?: TokenCount;
  totalTokens?: TokenCount;
  estimated: boolean;
}

@doc("USD cost reported or estimated for one MCP execution when available.")
model RunnerMcpExecutionCost {
  amountUsd: CostUsd;
  estimated: boolean;
  source?: string;
}

@doc("Qyl observability identifiers correlating workbench, MCP, and downstream activity.")
model RunnerMcpTelemetryCorrelation {
  executionId?: RunnerMcpExecutionId;
  evaluationRunId?: RunnerMcpEvaluationRunId;
  testCaseId?: RunnerMcpTestCaseId;
  traceIds: TraceId[];
  spanIds: SpanId[];
}

@doc("Persisted asynchronous execution evidence. SDK tool results remain opaque.")
model RunnerMcpExecutionRecord {
  id: RunnerMcpExecutionId;
  workspaceId: RunnerMcpWorkspaceId;
  serverId: RunnerMcpServerId;
  request: RunnerMcpExecutionRequest;

  @doc("Server-derived effect from the SDK-validated discovered Tool and its annotations.")
  effect: RunnerMcpExecutionEffect;

  confirmation?: RunnerMcpExecutionConfirmationEvidence;
  status: RunnerMcpExecutionStatus;
  createdAt: utcDateTime;
  startedAt?: utcDateTime;
  completedAt?: utcDateTime;
  durationMs?: DurationMs;

  @minValue(0)
  attemptCount: int32;

  @minValue(0)
  retryCount: int32;

  cancelRequestedAt?: utcDateTime;
  cancelledAt?: utcDateTime;

  @doc("Complete opaque SDK tool-call result after output sanitization.")
  result?: unknown;

  error?: RunnerMcpError;
  tokenUsage?: RunnerMcpExecutionTokenUsage;
  cost?: RunnerMcpExecutionCost;
  telemetry?: RunnerMcpTelemetryCorrelation;
}

@doc("An MCP execution was accepted and continues asynchronously.")
model RunnerMcpExecutionAccepted {
  @statusCode statusCode: 202;
  execution: RunnerMcpExecutionRecord;
}

@doc("Request to cancel an asynchronous MCP execution where the transport permits cancellation.")
model RunnerMcpExecutionCancelRequest {
  @maxLength(1000)
  reason?: string;

  @minLength(8)
  @maxLength(256)
  idempotencyKey: string;
}

@doc("Cursor page of MCP execution records.")
model RunnerMcpExecutionPage {
  executions: RunnerMcpExecutionRecord[];
  nextCursor?: string;
}

@doc("Whether correlated Qyl observability evidence was available.")
enum RunnerMcpTelemetryAvailability {
  available: "available",
  partial: "partial",
  unavailable: "unavailable",
}

@doc("Availability and retained item count for one correlated Qyl telemetry signal.")
model RunnerMcpTelemetrySignalAvailability {
  status: RunnerMcpTelemetryAvailability;
  unavailableReason?: string;

  @minValue(0)
  itemCount: int32;
}

@doc("Per-signal availability for correlated workbench observability evidence.")
model RunnerMcpTelemetrySignalSummary {
  traces: RunnerMcpTelemetrySignalAvailability;
  logs: RunnerMcpTelemetrySignalAvailability;
  exceptions: RunnerMcpTelemetrySignalAvailability;
  toolCallEvents: RunnerMcpTelemetrySignalAvailability;
}

@doc("Correlated Qyl observability evidence for one MCP execution. Signals unsupported by the connected Qyl read API are explicitly unavailable.")
model RunnerMcpExecutionTelemetryResponse {
  signals: RunnerMcpTelemetrySignalSummary;
  correlation: RunnerMcpTelemetryCorrelation;
  traces: Trace[];
  logs: LogRecord[];
  queriedAt: utcDateTime;

  @doc("Confirms that workbench telemetry querying is excluded from workbench export instrumentation.")
  selfExportSuppressed: true;
}

@doc("Assertion outcome reported by an evaluation.")
enum RunnerMcpAssertionStatus {
  passed: "passed",
  failed: "failed",
  error: "error",
  skipped: "skipped",
}

@doc("Execution-status assertion for an MCP test case.")
model RunnerMcpStatusAssertion {
  id: string;
  kind: "status";

  @minItems(1)
  expected: RunnerMcpExecutionStatus[];
}

@doc("Exact JSON value assertion at an optional JSON Pointer path.")
model RunnerMcpExactAssertion {
  id: string;
  kind: "exact";
  path?: string;
  expected: unknown;
}

@doc("Partial JSON object or array containment assertion at an optional JSON Pointer path.")
model RunnerMcpPartialAssertion {
  id: string;
  kind: "partial";
  path?: string;
  expected: unknown;
}

@doc("JSON Schema assertion at an optional JSON Pointer path.")
model RunnerMcpSchemaAssertion {
  id: string;
  kind: "schema";
  path?: string;
  schema: unknown;
}

@doc("Regular-expression assertion at an optional JSON Pointer path.")
model RunnerMcpPatternAssertion {
  id: string;
  kind: "pattern";
  path?: string;
  pattern: string;
  flags?: string;
}

@doc("Maximum execution latency assertion.")
model RunnerMcpLatencyAssertion {
  id: string;
  kind: "latency";

  @minValue(0)
  maxDurationMs: float64;
}

@doc("Exactly one supported MCP evaluation assertion.")
@oneOf
union RunnerMcpTestAssertion {
  status: RunnerMcpStatusAssertion,
  exact: RunnerMcpExactAssertion,
  partial: RunnerMcpPartialAssertion,
  schema: RunnerMcpSchemaAssertion,
  pattern: RunnerMcpPatternAssertion,
  latency: RunnerMcpLatencyAssertion,
}

@doc("Reusable tool invocation and assertions persisted in one workspace.")
model RunnerMcpTestCase {
  id: RunnerMcpTestCaseId;
  workspaceId: RunnerMcpWorkspaceId;
  serverId: RunnerMcpServerId;
  name: string;
  description?: string;
  toolName: string;
  arguments?: unknown;

  @minValue(1)
  @maxValue(3600000)
  timeoutMs: int32;

  assertions: RunnerMcpTestAssertion[];
  tags: string[];
  createdAt: utcDateTime;
  updatedAt: utcDateTime;
}

@doc("Request to create a reusable MCP test case.")
model RunnerMcpTestCaseCreateRequest {
  serverId: RunnerMcpServerId;

  @minLength(1)
  @maxLength(160)
  name: string;

  @maxLength(4000)
  description?: string;

  @minLength(1)
  toolName: string;

  arguments?: unknown;

  @minValue(1)
  @maxValue(3600000)
  timeoutMs: int32 = 30000;

  @minItems(1)
  assertions: RunnerMcpTestAssertion[];

  tags?: string[];
}

@doc("Request to update mutable MCP test-case fields.")
model RunnerMcpTestCaseUpdateRequest {
  serverId?: RunnerMcpServerId;

  @minLength(1)
  @maxLength(160)
  name?: string;

  @maxLength(4000)
  description?: string;

  @minLength(1)
  toolName?: string;

  arguments?: unknown;

  @minValue(1)
  @maxValue(3600000)
  timeoutMs?: int32;

  @minItems(1)
  assertions?: RunnerMcpTestAssertion[];

  tags?: string[];
}

@doc("Cursor page of reusable MCP test cases.")
model RunnerMcpTestCasePage {
  testCases: RunnerMcpTestCase[];
  nextCursor?: string;
}

@doc("Reusable ordered group of MCP test cases.")
model RunnerMcpTestSuite {
  id: RunnerMcpSuiteId;
  workspaceId: RunnerMcpWorkspaceId;
  name: string;
  description?: string;

  @minItems(1)
  testCaseIds: RunnerMcpTestCaseId[];

  tags: string[];
  createdAt: utcDateTime;
  updatedAt: utcDateTime;
}

@doc("Request to create a reusable MCP test suite.")
model RunnerMcpTestSuiteCreateRequest {
  @minLength(1)
  @maxLength(160)
  name: string;

  @maxLength(4000)
  description?: string;

  @minItems(1)
  testCaseIds: RunnerMcpTestCaseId[];

  tags?: string[];
}

@doc("Request to update mutable MCP test-suite fields.")
model RunnerMcpTestSuiteUpdateRequest {
  @minLength(1)
  @maxLength(160)
  name?: string;

  @maxLength(4000)
  description?: string;

  @minItems(1)
  testCaseIds?: RunnerMcpTestCaseId[];

  tags?: string[];
}

@doc("Cursor page of reusable MCP test suites.")
model RunnerMcpTestSuitePage {
  suites: RunnerMcpTestSuite[];
  nextCursor?: string;
}

@doc("Request to execute one test case or suite asynchronously.")
model RunnerMcpEvaluationRunRequest {
  @minLength(8)
  @maxLength(256)
  idempotencyKey: string;

  confirmation?: RunnerMcpExecutionConfirmationRequest;

  @minValue(1)
  @maxValue(50)
  concurrency?: int32 = 1;

  failFast?: boolean = false;
}

@doc("Request to run one persisted MCP test case asynchronously.")
model RunnerMcpTestCaseRunRequest extends RunnerMcpEvaluationRunRequest {}

@doc("Request to run a complete suite or an explicit subset of its persisted test cases asynchronously.")
model RunnerMcpSuiteRunRequest extends RunnerMcpEvaluationRunRequest {
  @minItems(1)
  selectedTestCaseIds?: RunnerMcpTestCaseId[];
}

@doc("Lifecycle for an MCP evaluation run.")
enum RunnerMcpEvaluationRunStatus {
  queued: "queued",
  running: "running",
  completed: "completed",
  failed: "failed",
  cancelled: "cancelled",
}

@doc("Outcome for one test case within an evaluation run.")
enum RunnerMcpEvaluationResultStatus {
  passed: "passed",
  failed: "failed",
  error: "error",
  skipped: "skipped",
}

@doc("Outcome of one assertion with sanitized actual evidence when useful.")
model RunnerMcpAssertionResult {
  assertionId: string;
  kind: string;
  status: RunnerMcpAssertionStatus;
  message?: string;
  actual?: unknown;
}

@doc("Immutable reusable-test definition captured when an evaluation run starts.")
model RunnerMcpEvaluationTestCaseSnapshot {
  id: RunnerMcpTestCaseId;
  serverId: RunnerMcpServerId;
  name: string;
  description?: string;
  toolName: string;
  arguments?: unknown;
  timeoutMs: int32;
  assertions: RunnerMcpTestAssertion[];
  tags: string[];
}

@doc("Immutable suite definition captured when an evaluation run starts.")
model RunnerMcpEvaluationSuiteSnapshot {
  id: RunnerMcpSuiteId;
  name: string;
  description?: string;
  testCaseIds: RunnerMcpTestCaseId[];
  tags: string[];
}

@doc("One test-case result retained by an MCP evaluation run.")
model RunnerMcpEvaluationTestResult {
  testCase: RunnerMcpEvaluationTestCaseSnapshot;
  executionId?: RunnerMcpExecutionId;
  status: RunnerMcpEvaluationResultStatus;
  startedAt?: utcDateTime;
  completedAt?: utcDateTime;
  durationMs?: DurationMs;
  assertions: RunnerMcpAssertionResult[];
  error?: RunnerMcpError;
}

@doc("Aggregate correctness, reliability, latency, usage, and cost for an MCP evaluation run.")
model RunnerMcpEvaluationSummary {
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

  successRate: Ratio;
  reliability: Ratio;
  meanDurationMs?: DurationMs;
  p50DurationMs?: DurationMs;
  p95DurationMs?: DurationMs;
  p99DurationMs?: DurationMs;
  tokenUsage?: RunnerMcpExecutionTokenUsage;
  cost?: RunnerMcpExecutionCost;
}

@doc("Asynchronous MCP evaluation run with retained per-test evidence.")
model RunnerMcpEvaluationRun {
  id: RunnerMcpEvaluationRunId;
  workspaceId: RunnerMcpWorkspaceId;
  suite?: RunnerMcpEvaluationSuiteSnapshot;
  testCases: RunnerMcpEvaluationTestCaseSnapshot[];
  status: RunnerMcpEvaluationRunStatus;
  createdAt: utcDateTime;
  startedAt?: utcDateTime;
  completedAt?: utcDateTime;
  results: RunnerMcpEvaluationTestResult[];
  summary?: RunnerMcpEvaluationSummary;
  confirmation?: RunnerMcpExecutionConfirmationEvidence;
  telemetry?: RunnerMcpTelemetryCorrelation;
  error?: RunnerMcpError;
}

@doc("An MCP evaluation run was accepted and continues asynchronously.")
model RunnerMcpEvaluationRunAccepted {
  @statusCode statusCode: 202;
  run: RunnerMcpEvaluationRun;
}

@doc("Cursor page of MCP evaluation runs.")
model RunnerMcpEvaluationRunPage {
  runs: RunnerMcpEvaluationRun[];
  nextCursor?: string;
}

@doc("Request to compare a baseline MCP evaluation run with a candidate run.")
model RunnerMcpEvaluationComparisonRequest {
  baselineRunId: RunnerMcpEvaluationRunId;
  candidateRunId: RunnerMcpEvaluationRunId;
}

@doc("Regression classification for one test case across two evaluation runs.")
enum RunnerMcpRegressionStatus {
  improved: "improved",
  regressed: "regressed",
  unchanged: "unchanged",
  added: "added",
  removed: "removed",
}

@doc("Per-test comparison across a baseline and candidate MCP evaluation run.")
model RunnerMcpEvaluationTestComparison {
  testCaseId: RunnerMcpTestCaseId;
  status: RunnerMcpRegressionStatus;
  baselineStatus?: RunnerMcpEvaluationResultStatus;
  candidateStatus?: RunnerMcpEvaluationResultStatus;
  durationDeltaMs?: float64;
}

@doc("Aggregate comparison of two completed MCP evaluation runs.")
model RunnerMcpEvaluationRunComparison {
  baselineRunId: RunnerMcpEvaluationRunId;
  candidateRunId: RunnerMcpEvaluationRunId;
  baseline: RunnerMcpEvaluationSummary;
  candidate: RunnerMcpEvaluationSummary;
  successRateDelta: float64;
  reliabilityDelta: float64;
  p95DurationDeltaMs?: float64;
  tokenDelta?: int64;
  costDeltaUsd?: float64;
  tests: RunnerMcpEvaluationTestComparison[];
  comparedAt: utcDateTime;
}

@doc("Supported evaluation export representation.")
enum RunnerMcpEvaluationExportFormat {
  json: "json",
  report: "report",
}

@doc("Request to generate a machine-readable or readable evaluation export.")
model RunnerMcpEvaluationExportRequest {
  format: RunnerMcpEvaluationExportFormat;
  includeProtocolEvents?: boolean = true;
  includeTelemetry?: boolean = true;

  @minLength(8)
  @maxLength(256)
  idempotencyKey: string;
}

@doc("Lifecycle for generation of an evaluation export artifact.")
enum RunnerMcpEvaluationExportStatus {
  pending: "pending",
  ready: "ready",
  failed: "failed",
}

@doc("Metadata for one generated evaluation JSON or readable report artifact.")
model RunnerMcpEvaluationExport {
  id: RunnerMcpEvaluationExportId;
  runId: RunnerMcpEvaluationRunId;
  format: RunnerMcpEvaluationExportFormat;
  status: RunnerMcpEvaluationExportStatus;
  requestedAt: utcDateTime;
  completedAt?: utcDateTime;
  mediaType?: string;
  fileName?: string;
  byteSize?: ByteSize;
  sha256?: Sha256Hash;
  error?: RunnerMcpError;
}

@doc("Machine-readable evaluation export with retained execution, protocol, and optional telemetry evidence.")
model RunnerMcpEvaluationJsonExportPayload {
  format: "json";
  run: RunnerMcpEvaluationRun;
  protocolEvents: RunnerMcpProtocolEvent[];
  telemetry: RunnerMcpExecutionTelemetryResponse[];
  exportedAt: utcDateTime;
}

@doc("Human-readable Markdown evaluation report.")
model RunnerMcpEvaluationReportExportPayload {
  format: "report";
  markdown: string;
  exportedAt: utcDateTime;
}

@doc("Exactly one generated evaluation export representation.")
@oneOf
union RunnerMcpEvaluationExportPayload {
  json: RunnerMcpEvaluationJsonExportPayload,
  report: RunnerMcpEvaluationReportExportPayload,
}

@doc("Ready evaluation export metadata and its TypeSpec-owned content.")
model RunnerMcpEvaluationExportArtifact {
  export: RunnerMcpEvaluationExport;
  payload: RunnerMcpEvaluationExportPayload;
}

@doc("An evaluation export was accepted and continues asynchronously.")
model RunnerMcpEvaluationExportAccepted {
  @statusCode statusCode: 202;
  export: RunnerMcpEvaluationExport;
}

@doc("Successful deletion with no response body.")
model RunnerMcpDeleted {
  @statusCode statusCode: 204;
}
