import "./workflow.tsp";

using Qyl.Api.Contracts.Workflow;

namespace Qyl.Api.Contracts.Diagnostics;

@doc("The versioned extension discriminator for a protected agent diagnostic snapshot.")
enum AgentDiagnosticExtensionId {
  snapshot: "qyl.agent.diagnostic.snapshot",
}

@doc("Wire-format version of an agent diagnostic snapshot. Version 1 is the only accepted format.")
@minValue(1)
@maxValue(1)
scalar AgentDiagnosticFormatVersion extends int32;

@doc("Stable machine identifier of one diagnostic snapshot. This identifier is a value and must never be promoted to a telemetry key.")
@pattern("^[A-Za-z0-9_][A-Za-z0-9._:/\\[\\]-]{0,127}$")
@minLength(1)
@maxLength(128)
scalar AgentDiagnosticSnapshotId extends string;

@doc("Stable machine identifier of the probe that captured a diagnostic snapshot. This identifier is a value and must never be promoted to a telemetry key.")
@pattern("^[A-Za-z0-9_][A-Za-z0-9._:/\\[\\]-]{0,127}$")
@minLength(1)
@maxLength(128)
scalar AgentDiagnosticProbeId extends string;

@doc("Stable machine identifier of one diagnostic check. This identifier is a value and must never be promoted to a telemetry key.")
@pattern("^[A-Za-z0-9_][A-Za-z0-9._:/\\[\\]-]{0,127}$")
@minLength(1)
@maxLength(128)
scalar AgentDiagnosticCheckId extends string;

@doc("Stable machine name of one dynamically captured variable. Names are data values, never telemetry attribute keys, event names, or span names.")
@pattern("^[A-Za-z0-9_][A-Za-z0-9._:/\\[\\]-]{0,127}$")
@minLength(1)
@maxLength(128)
scalar AgentDiagnosticVariableName extends string;

@doc("Execution boundary at which the state frame was captured.")
enum AgentDiagnosticPhase {
  input: "input",
  output: "output",
  error: "error",
  checkpoint: "checkpoint",
}

@doc("Machine-computed aggregate result of a diagnostic snapshot. unknown reports one or more unknown check outcomes. not_evaluated is reserved for a snapshot whose checks array is empty.")
enum AgentDiagnosticOutcome {
  pass: "pass",
  fail: "fail",
  unknownResult: "unknown",
  notEvaluated: "not_evaluated",
}

@doc("Machine-computed result of one diagnostic check. For exists, an absent or null actual variable produces fail. For every other operator, missing required operands produce unknown; incompatible operand types also produce unknown. not_evaluated is deliberately not a check outcome.")
enum AgentDiagnosticCheckOutcome {
  pass: "pass",
  fail: "fail",
  unknownResult: "unknown",
}

@doc("Declared JSON-level type of a diagnostic variable.")
enum AgentDiagnosticValueType {
  null: "null",
  boolean: "boolean",
  integer: "integer",
  number: "number",
  string: "string",
  json: "json",
}

@doc("Data-handling classification assigned before a diagnostic variable is captured.")
enum AgentDiagnosticClassification {
  public: "public",
  internal: "internal",
  sensitive: "sensitive",
  secret: "secret",
}

@doc("How a diagnostic variable was represented in protected snapshot content.")
enum AgentDiagnosticCapture {
  value: "value",
  redacted: "redacted",
  omitted: "omitted",
}

@doc("Closed operation evaluated by a diagnostic check. Checks are structural and never carry expression strings.")
enum AgentDiagnosticOperator {
  equal: "equal",
  notEqual: "not_equal",
  exists: "exists",
  typeIs: "type_is",
  contains: "contains",
  lessThan: "less_than",
  greaterThan: "greater_than",
}

@doc("Common identity and policy fields for one dynamic diagnostic variable.")
model AgentDiagnosticVariableBase {
  name: AgentDiagnosticVariableName;
  type: AgentDiagnosticValueType;
  classification: AgentDiagnosticClassification;
}

@doc("A variable whose typed JSON value is present in protected snapshot content. The value is required and must match type: null is JSON null; boolean is a JSON boolean; integer is a signed 64-bit JSON integer; number is a finite JSON number; string is a JSON string; json is a JSON object or array. The protected content boundary, not this model, controls access to all captured values.")
model CapturedAgentDiagnosticVariable extends AgentDiagnosticVariableBase {
  capture: "value";
  value: unknown | null;
}

@doc("A variable observed by the probe whose value was replaced by policy. A value field is forbidden.")
model RedactedAgentDiagnosticVariable extends AgentDiagnosticVariableBase {
  capture: "redacted";
}

@doc("A variable whose value was unavailable or deliberately not captured. A value field is forbidden.")
model OmittedAgentDiagnosticVariable extends AgentDiagnosticVariableBase {
  capture: "omitted";
}

@doc("One dynamically named variable in a protected diagnostic snapshot. Capture is the discriminator and makes value presence unambiguous.")
union AgentDiagnosticVariable {
  value: CapturedAgentDiagnosticVariable,
  redacted: RedactedAgentDiagnosticVariable,
  omitted: OmittedAgentDiagnosticVariable,
}

@doc("One structural, machine-computed check result. actual and expected reference variable names only. For equal, not_equal, contains, less_than, and greater_than, expected is required and expected_type is omitted. For exists, both are omitted and an absent or null actual variable produces fail. For type_is, expected is omitted and expected_type is required. For operators other than exists, missing required operands produce unknown; incompatible operand types also produce unknown. not_evaluated is reserved for the snapshot aggregate when checks is empty and is not emitted for an individual check.")
model AgentDiagnosticCheckResult {
  @encodedName("application/json", "check_id")
  checkId: AgentDiagnosticCheckId;

  operator: AgentDiagnosticOperator;
  actual: AgentDiagnosticVariableName;
  expected?: AgentDiagnosticVariableName;

  @encodedName("application/json", "expected_type")
  expectedType?: AgentDiagnosticValueType;

  outcome: AgentDiagnosticCheckOutcome;
}

@doc("Version 1 protected JSON state frame captured for an artificial-intelligence agent. extension_id and format_version are its schema identity. capture_nonce is fresh entropy and is not a stable identifier. Variables and checks are bounded, dynamic names remain values, and no human-oriented message or expression text is part of the contract. Overall outcome is not_evaluated only when checks is empty. For a non-empty checks array it is fail if any check fails, otherwise unknown if any check is unknown, otherwise pass.")
model AgentDiagnosticSnapshot {
  @encodedName("application/json", "extension_id")
  extensionId: AgentDiagnosticExtensionId;

  @encodedName("application/json", "format_version")
  formatVersion: AgentDiagnosticFormatVersion;

  @encodedName("application/json", "snapshot_id")
  snapshotId: AgentDiagnosticSnapshotId;

  @doc("Fresh 128-bit random nonce encoded as exactly 32 lowercase hexadecimal characters. It prevents equality inference across otherwise identical protected captures and must not be used as an identity key.")
  @encodedName("application/json", "capture_nonce")
  @pattern("^[0-9a-f]{32}$")
  @minLength(32)
  @maxLength(32)
  captureNonce: string;

  @encodedName("application/json", "probe_id")
  probeId: AgentDiagnosticProbeId;

  phase: AgentDiagnosticPhase;

  @maxItems(64)
  variables: AgentDiagnosticVariable[];

  @maxItems(64)
  checks: AgentDiagnosticCheckResult[];

  outcome: AgentDiagnosticOutcome;
}

@doc("Value-free event-data projection for a protected agent diagnostic snapshot. Encode this shape in WorkflowEventAppend.data on the existing content_captured event kind. content_ref must also occur in that event's content_refs and identifies UTF-8 JSON conforming to AgentDiagnosticSnapshot. Counts are computed from the referenced snapshot; failed_check_count counts checks whose outcome is fail. No variable names, values, human messages, expressions, nonce, or classifications may appear in this summary.")
model AgentDiagnosticSnapshotSummary {
  @encodedName("application/json", "extension_id")
  extensionId: AgentDiagnosticExtensionId;

  @encodedName("application/json", "format_version")
  formatVersion: AgentDiagnosticFormatVersion;

  @encodedName("application/json", "snapshot_id")
  snapshotId: AgentDiagnosticSnapshotId;

  @encodedName("application/json", "probe_id")
  probeId: AgentDiagnosticProbeId;

  phase: AgentDiagnosticPhase;
  outcome: AgentDiagnosticOutcome;

  @encodedName("application/json", "variable_count")
  @minValue(0)
  @maxValue(64)
  variableCount: int32;

  @encodedName("application/json", "check_count")
  @minValue(0)
  @maxValue(64)
  checkCount: int32;

  @encodedName("application/json", "failed_check_count")
  @minValue(0)
  @maxValue(64)
  failedCheckCount: int32;

  @encodedName("application/json", "content_ref")
  contentRef: WorkflowContentRef;
}
