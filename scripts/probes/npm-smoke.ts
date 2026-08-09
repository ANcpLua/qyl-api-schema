// Type-level probe for the published npm package, copied verbatim into a clean
// consumer project by scripts/verify-consumers.mjs and checked there with
// `tsc --noEmit --strict`. It is excluded from every in-repo tsconfig on
// purpose: compiled here it would resolve to generated/ts-types rather than the
// installed package.
//
// There are no runtime assertions in this file. Everything it proves, it proves
// by compiling — including the @ts-expect-error, which fails the build if the
// contract ever starts accepting a bare number as an attribute value.
import { CONTRACT_REVISION } from "@ancplua/qyl-api-schema/types";
import type {
    Attribute,
    AttributeValue,
    AgentDiagnosticCheckId,
    AgentDiagnosticSnapshot,
    AgentDiagnosticSnapshotId,
    AgentDiagnosticSnapshotSummary,
    AgentDiagnosticVariable,
    AgentDiagnosticVariableName,
    AgentDiagnosticProbeId,
    CiLogOutput,
    EntityRef,
    HealthReport,
    LogRecord,
    Resource,
    SessionId,
    WorkflowJournalEvent,
    WorkflowAgentId,
    WorkflowAttemptId,
    WorkflowContentRef,
    WorkflowEventId,
    WorkflowJournalPosition,
    WorkflowRunId,
} from "@ancplua/qyl-api-schema/types";

const eventLog: LogRecord = {
    time_unix_nano: "2",
    observed_time_unix_nano: "3",
    severity_number: 9,
    body: { string_value: "evaluation completed" },
    event_name: "gen_ai.evaluation.result",
    resource: { service_name: "evaluator" },
};

const emptyAttribute: Attribute = { key: "empty", value: null };

const intAttribute: Attribute = {
    key: "int",
    value: { type: "int", value: "9223372036854775807" },
};

const doubleAttribute: Attribute = {
    key: "double",
    value: { type: "double", value: "Infinity" },
};

const kvlistAttribute: Attribute = {
    key: "kvlist",
    value: {
        type: "kvlist",
        values: { empty: null, nested: [intAttribute.value, doubleAttribute.value] },
    },
};

const entityRef: EntityRef = {
    schema_url: "https://opentelemetry.io/schemas/1.43.0",
    type: "service",
    id_keys: ["service.instance.id"],
    description_keys: ["service.version"],
};

const resource: Resource = {
    service_name: "orders",
    attributes: [emptyAttribute, intAttribute, doubleAttribute, kvlistAttribute],
    entity_refs: [entityRef],
};

// @ts-expect-error Attribute integers require the tagged lossless representation.
const invalidAttribute: AttributeValue = 1;

// Compiling this is the whole assertion: the revision is a required member of
// the health surface under its snake_case wire name, and the package exports the
// value a client compares against it.
const healthReport: HealthReport = {
    status: "healthy",
    total_duration_ms: 0,
    entries: {},
    contract_revision: CONTRACT_REVISION,
};

const ciLog: CiLogOutput = {
    // A CI run id is the session identity, so it keeps that scalar rather than
    // becoming a second spelling of it.
    run_id: "nuget-publish-42" as SessionId,
    phases: [{ leg: "macos-latest", phase: "pack", status: "error", duration_ms: 12 }],
    mode: "live",
};

const workflowEvent: WorkflowJournalEvent = {
    event_id: "evt-0001" as WorkflowEventId,
    source_sequence: "7",
    timestamp: "2026-07-28T12:34:56+00:00",
    kind: "agent_spawned",
    thread_id: "thr-1",
    attempt_id: "attempt-1" as WorkflowAttemptId,
    agent_id: "agent-child" as WorkflowAgentId,
    parent_agent_id: "agent-root" as WorkflowAgentId,
    content_refs: [`sha256:${"a".repeat(64)}` as WorkflowContentRef],
    run_id: "run-1" as WorkflowRunId,
    client_id: "qyl-codex",
    journal_sequence: "11" as WorkflowJournalPosition,
};

const diagnosticVariable: AgentDiagnosticVariable = {
    name: "planner.candidates[0].score" as AgentDiagnosticVariableName,
    type: "number",
    classification: "internal",
    capture: "value",
    value: 0.875,
};

const diagnosticSnapshot: AgentDiagnosticSnapshot = {
    extension_id: "qyl.agent.diagnostic.snapshot",
    format_version: 1,
    snapshot_id: "snapshot:planner:0001" as AgentDiagnosticSnapshotId,
    capture_nonce: "0123456789abcdef0123456789abcdef",
    probe_id: "planner.selection" as AgentDiagnosticProbeId,
    phase: "checkpoint",
    variables: [diagnosticVariable],
    checks: [{
        check_id: "planner.minimum_score" as AgentDiagnosticCheckId,
        operator: "greater_than",
        actual: "planner.candidates[0].score" as AgentDiagnosticVariableName,
        expected: "planner.minimum_score" as AgentDiagnosticVariableName,
        outcome: "pass",
    }],
    outcome: "pass",
};

const diagnosticSummary: AgentDiagnosticSnapshotSummary = {
    extension_id: "qyl.agent.diagnostic.snapshot",
    format_version: 1,
    snapshot_id: diagnosticSnapshot.snapshot_id,
    probe_id: diagnosticSnapshot.probe_id,
    phase: diagnosticSnapshot.phase,
    outcome: diagnosticSnapshot.outcome,
    variable_count: 1,
    check_count: 1,
    failed_check_count: 0,
    content_ref: `sha256:${"b".repeat(64)}` as WorkflowContentRef,
};

const invalidRedactedDiagnosticVariable: AgentDiagnosticVariable = {
    name: "tool.authorization" as AgentDiagnosticVariableName,
    type: "string",
    classification: "secret",
    capture: "redacted",
    // @ts-expect-error Redacted variables are structurally forbidden from carrying values.
    value: "must-not-leak",
};

void [
    eventLog,
    emptyAttribute,
    intAttribute,
    doubleAttribute,
    kvlistAttribute,
    entityRef,
    resource,
    invalidAttribute,
    healthReport,
    ciLog,
    workflowEvent,
    diagnosticSnapshot,
    diagnosticSummary,
    invalidRedactedDiagnosticVariable,
];
