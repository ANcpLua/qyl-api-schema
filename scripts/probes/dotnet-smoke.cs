// Runtime probe for the published NuGet package, copied verbatim to Program.cs
// in a clean console project by scripts/verify-consumers.mjs. It is not part of
// any solution here: built in-repo it would reference the local emitter output
// instead of the restored Qyl.Api.Contracts package and prove nothing.
//
// It asserts wire shape, not just type shape — the Contains checks below read
// serialized JSON, so a rename that keeps C# compiling still fails here.
using System.Text.Json;
using System.Text;
using ModelContextProtocol;
using ModelContextProtocol.Protocol;
using Qyl.Api.Contracts;
using Qyl.Api.Contracts.Common.Errors;
using Qyl.Api.Contracts.Diagnostics;
using System.Linq;
using Qyl.Api.Contracts.Health;
using Qyl.Api.Contracts.Mcp.Tools;
using Qyl.Api.Contracts.OTel.Enums;
using Qyl.Api.Contracts.OTel.Logs;
using Qyl.Api.Contracts.Runner;
using Qyl.Api.Contracts.Workbench;
using Qyl.Api.Contracts.Workflow;
#pragma warning disable MCPEXP001
using Qyl.Api.Contracts.Common;
using OTelAttribute = Qyl.Api.Contracts.Common.Attribute;
using OTelResource = Qyl.Api.Contracts.OTel.Resource.Resource;

var health = JsonSerializer.Serialize(HealthStatus.Healthy);
var lifecycle = JsonSerializer.Serialize(RunnerResourceLifecycle.Ready);
var kind = JsonSerializer.Serialize(RunnerResourceKind.Stdio);

var eventLog = new LogRecord
{
    TimeUnixNano = 2,
    ObservedTimeUnixNano = 3,
    SeverityNumber = SeverityNumber.Info,
    Body = new LogBodyString { StringValue = "evaluation completed" },
    EventName = "gen_ai.evaluation.result",
    Resource = new OTelResource { ServiceName = "evaluator" },
};
var eventLogWire = JsonSerializer.Serialize(eventLog);

var emptyAttribute = new OTelAttribute { Key = "empty", Value = null };
var intAttribute = new OTelAttribute
{
    Key = "int",
    Value = new AttributeIntValue { Type = "int", Value = long.MaxValue },
};
var doubleAttribute = new OTelAttribute
{
    Key = "double",
    Value = new AttributeDoubleValue { Type = "double", Value = double.PositiveInfinity },
};
var kvlistAttribute = new OTelAttribute
{
    Key = "kvlist",
    Value = new AttributeKeyValueListValue
    {
        Type = "kvlist",
        Values = new Dictionary<string, object?>
        {
            ["empty"] = null,
            ["nested"] = new AttributeIntValue { Type = "int", Value = 1 },
        },
    },
};

var entityRef = new EntityRef
{
    SchemaUrl = "https://opentelemetry.io/schemas/1.43.0",
    Type = "service",
    IdKeys = ["service.instance.id"],
    DescriptionKeys = ["service.version"],
};

var resource = new OTelResource
{
    ServiceName = "orders",
    Attributes = [emptyAttribute, intAttribute, doubleAttribute, kvlistAttribute],
    EntityRefs = [entityRef],
};
var resourceWire = JsonSerializer.Serialize(resource);
var resourceRoundTrip = JsonSerializer.Deserialize<OTelResource>(resourceWire);

var state = new RunnerResourceState
{
    Name = "demo",
    Lifecycle = RunnerResourceLifecycle.Ready,
    Timestamp = DateTimeOffset.UnixEpoch,
    Kind = RunnerResourceKind.Stdio,
};

WorkbenchServerConfiguration serverConfiguration = new WorkbenchStdioServerConfiguration
{
    Command = "node",
    Arguments = ["server.mjs"],
    Environment =
    [
        new WorkbenchEnvironmentSecretReference
        {
            Name = "API_TOKEN",
            Secret = new WorkbenchSecretReference
            {
                Source = "environment",
                EnvironmentVariable = "QYL_MCP_API_TOKEN",
            },
        },
    ],
};

WorkbenchTestAssertion assertion = new WorkbenchStatusAssertion
{
    Id = "status",
    Expected = [WorkbenchExecutionStatus.Succeeded],
};

WorkbenchEvaluationExportPayload exportPayload = new WorkbenchEvaluationReportExportPayload
{
    Markdown = "# Evaluation",
    ExportedAt = DateTimeOffset.UnixEpoch,
};

var sdkRequest = new CallToolRequestParams
{
    Name = "inspect",
    Arguments = new Dictionary<string, JsonElement>
    {
        ["trace_id"] = JsonSerializer.Deserialize<JsonElement>("\"abc\""),
    },
};

var executionRequest = new WorkbenchExecutionRequest
{
    ToolName = sdkRequest.Name,
    Arguments = sdkRequest.Arguments,
    TimeoutMs = 30000,
    IdempotencyKey = "smoke-key",
};

var toolInput = new FetchTelemetryInput { View = FetchTelemetryView.Traces };

// The .NET face of the contract-revision handshake: the package carries the
// revision it was generated from, and the health surface carries the peer's
// under the wire name a client reads it by.
var healthReport = new HealthReport
{
    Status = HealthStatus.Healthy,
    TotalDurationMs = 0,
    Entries = new Dictionary<string, HealthCheckEntry>(),
    ContractRevision = ContractRevision.Value,
};
var healthReportWire = JsonSerializer.Serialize(healthReport);

var workflowEvent = new WorkflowJournalEvent
{
    EventId = new WorkflowEventId("evt-0001"),
    SourceSequence = 7,
    Timestamp = new DateTimeOffset(2026, 7, 28, 12, 34, 56, TimeSpan.Zero),
    Kind = WorkflowJournalEventKind.AgentSpawned,
    ThreadId = "thr-1",
    AttemptId = new WorkflowAttemptId("attempt-1"),
    AgentId = new WorkflowAgentId("agent-child"),
    ParentAgentId = new WorkflowAgentId("agent-root"),
    ContentRefs = [new WorkflowContentRef($"sha256:{new string('a', 64)}")],
    RunId = new WorkflowRunId("run-1"),
    ClientId = "qyl-codex",
    JournalSequence = 11,
};
var workflowFixtureWire = JsonSerializer.Serialize(workflowEvent);

var inspectWorkflowEventsInput = new InspectWorkflowEventsInput
{
    RunId = workflowEvent.RunId,
    AfterSequence = workflowEvent.JournalSequence,
    Limit = 250,
    ContentRef = workflowEvent.ContentRefs?[0],
};
var inspectWorkflowEventsOutput = new InspectWorkflowEventsOutput
{
    Page = new WorkflowEventPage
    {
        Events = [workflowEvent],
        NextSequence = 12,
        HighWaterMark = 12,
        CursorGap = false,
    },
    Content = new WorkflowContent
    {
        ContentRef = workflowEvent.ContentRefs![0],
        ContentType = "application/json",
        Encoding = WorkflowContentEncoding.Utf8,
        Content = "{}",
        SizeBytes = 2,
    },
    Mode = McpDataMode.Live,
};
var inspectWorkflowEventsInputWire = JsonSerializer.Serialize(inspectWorkflowEventsInput);
var inspectWorkflowEventsOutputWire = JsonSerializer.Serialize(inspectWorkflowEventsOutput);

AgentDiagnosticVariable diagnosticVariable = new CapturedAgentDiagnosticVariable
{
    Name = new AgentDiagnosticVariableName("planner.candidates[0].score"),
    Type = AgentDiagnosticValueType.Number,
    Classification = AgentDiagnosticClassification.Internal,
    Value = 0.875,
};
var diagnosticSnapshot = new AgentDiagnosticSnapshot
{
    ExtensionId = AgentDiagnosticExtensionId.Snapshot,
    FormatVersion = 1,
    SnapshotId = new AgentDiagnosticSnapshotId("snapshot:planner:0001"),
    CaptureNonce = "0123456789abcdef0123456789abcdef",
    ProbeId = new AgentDiagnosticProbeId("planner.selection"),
    Phase = AgentDiagnosticPhase.Checkpoint,
    Variables = [diagnosticVariable],
    Checks =
    [
        new AgentDiagnosticCheckResult
        {
            CheckId = new AgentDiagnosticCheckId("planner.minimum_score"),
            Operator = AgentDiagnosticOperator.GreaterThan,
            Actual = new AgentDiagnosticVariableName("planner.candidates[0].score"),
            Expected = new AgentDiagnosticVariableName("planner.minimum_score"),
            Outcome = AgentDiagnosticCheckOutcome.Pass,
        },
    ],
    Outcome = AgentDiagnosticOutcome.Pass,
};
var diagnosticSnapshotWire = JsonSerializer.Serialize(diagnosticSnapshot);
var diagnosticSnapshotRoundTrip = JsonSerializer.Deserialize<AgentDiagnosticSnapshot>(diagnosticSnapshotWire);
var diagnosticSummary = new AgentDiagnosticSnapshotSummary
{
    ExtensionId = AgentDiagnosticExtensionId.Snapshot,
    FormatVersion = 1,
    SnapshotId = diagnosticSnapshot.SnapshotId,
    ProbeId = diagnosticSnapshot.ProbeId,
    Phase = diagnosticSnapshot.Phase,
    Outcome = diagnosticSnapshot.Outcome,
    VariableCount = 1,
    CheckCount = 1,
    FailedCheckCount = 0,
    ContentRef = new WorkflowContentRef($"sha256:{new string('b', 64)}"),
};
var diagnosticSummaryWire = JsonSerializer.Serialize(diagnosticSummary);

var serverConfigurationWire = JsonSerializer.Serialize(serverConfiguration);
var serverConfigurationRoundTrip = JsonSerializer.Deserialize<WorkbenchServerConfiguration>(serverConfigurationWire);
var assertionWire = JsonSerializer.Serialize(assertion);
var assertionRoundTrip = JsonSerializer.Deserialize<WorkbenchTestAssertion>(assertionWire);
var exportPayloadWire = JsonSerializer.Serialize(exportPayload);
var exportPayloadRoundTrip = JsonSerializer.Deserialize<WorkbenchEvaluationExportPayload>(exportPayloadWire);
var executionRequestWire = JsonSerializer.Serialize(executionRequest);

var otlpFidelityValid = resourceRoundTrip is not null
    && resourceRoundTrip.Attributes is { Count: 4 }
    && resourceRoundTrip.Attributes[0].Value is null
    && resourceRoundTrip.EntityRefs?[0] is { Type: "service", IdKeys.Count: 1 }
    && resourceWire.Contains("\"type\":\"int\",\"value\":\"9223372036854775807\"")
    && resourceWire.Contains("\"type\":\"double\",\"value\":\"Infinity\"")
    && resourceWire.Contains("\"type\":\"kvlist\"");

var contractTypes = typeof(FetchTelemetryInput).Assembly.GetTypes();
var removedSignalContractsAbsent = !contractTypes.Any(type =>
    type.Namespace?.StartsWith("Qyl.Api.Contracts.OTel.Metrics") == true
    || type.Namespace?.StartsWith("Qyl.Api.Contracts.OTel.Profiles") == true
    || type.Name is "MetricType" or "AggregationTemporality" or "DataPointFlags"
        or "InstrumentKind" or "OriginalPayloadFormat" or "ProfileFrameType");

// Each entry is reported by name when it fails. A single OR-chained exit code
// tells a release operator that something is wrong and nothing about what.
var checks = new (string Name, bool Ok)[]
{
    ("problemDetailsMediaType", ProblemDetailsMediaType.Value == "application/problem+json"),
    ("eventLogWireEventName", eventLogWire.Contains("\"event_name\":\"gen_ai.evaluation.result\"")),
    ("otlpFidelityValid", otlpFidelityValid),
    ("removedSignalContractsAbsent", removedSignalContractsAbsent),
    ("fetchTelemetryInputNamespace", typeof(FetchTelemetryInput).Namespace == "Qyl.Api.Contracts.Mcp.Tools"),
    ("costSurfaceAbsent", !contractTypes.Any(type =>
        type.Namespace is not null && type.Namespace.StartsWith("Qyl.Api.Contracts.Cost"))),
    ("healthStatusHealthy", health == "\"healthy\""),
    ("runnerResourceLifecycleReady", lifecycle == "\"ready\""),
    ("runnerResourceKindStdio", kind == "\"stdio\""),
    ("runnerResourceStateKind", state.Kind == RunnerResourceKind.Stdio),
    ("fetchTelemetryViewTraces", toolInput.View == FetchTelemetryView.Traces),
    ("serverConfigurationRoundTrip", serverConfigurationRoundTrip is WorkbenchStdioServerConfiguration),
    ("assertionRoundTrip", assertionRoundTrip is WorkbenchStatusAssertion),
    ("exportPayloadRoundTrip", exportPayloadRoundTrip is WorkbenchEvaluationReportExportPayload),
    ("serverConfigurationWireTransport", serverConfigurationWire.Contains("\"transport\":\"stdio\"")),
    ("serverConfigurationWireSecret",
        serverConfigurationWire.Contains("\"environment_variable\":\"QYL_MCP_API_TOKEN\"")),
    ("assertionWireKind", assertionWire.Contains("\"kind\":\"status\"")),
    ("exportPayloadWireFormat", exportPayloadWire.Contains("\"format\":\"report\"")),
    ("executionRequestToolName", executionRequest.ToolName == "inspect"),
    ("executionRequestTimeoutMs", executionRequest.TimeoutMs == 30000),
    ("executionRequestWireTraceId", executionRequestWire.Contains("\"trace_id\":\"abc\"")),
    ("contractRevisionEmitted", System.Text.RegularExpressions.Regex.IsMatch(
        ContractRevision.Value, "^sha256:[a-f0-9]{16}$")),
    ("healthReportWireContractRevision",
        healthReportWire.Contains($"\"contract_revision\":\"{ContractRevision.Value}\"")),
    ("ciLogOutputPresent", contractTypes.Any(type => type.Name == "CiLogOutput"
        && type.Namespace == "Qyl.Api.Contracts.Mcp.Tools")),
    ("workflowGraphPresent", contractTypes.Any(type => type.Name == "WorkflowGraphSnapshot"
        && type.Namespace == "Qyl.Api.Contracts.Workflow")),
    ("diagnosticCaptureEnumAbsent", !contractTypes.Any(type => type.Name == "AgentDiagnosticCapture"
        && type.Namespace == "Qyl.Api.Contracts.Diagnostics")),
    ("inspectWorkflowEventsInputShape", string.Join(",", typeof(InspectWorkflowEventsInput)
        .GetProperties().Select(property => property.Name).Order()) == "AfterSequence,ContentRef,Limit,RunId"),
    ("inspectWorkflowEventsOutputShape", string.Join(",", typeof(InspectWorkflowEventsOutput)
        .GetProperties().Select(property => property.Name).Order()) == "Content,Mode,Page"),
    ("inspectWorkflowEventsWire", inspectWorkflowEventsInputWire.Contains("\"after_sequence\":\"11\"")
        && inspectWorkflowEventsInputWire.Contains("\"content_ref\":\"sha256:")
        && !inspectWorkflowEventsInputWire.Contains("wait_ms")
        && !inspectWorkflowEventsOutputWire.Contains("graph")),
    ("diagnosticSnapshotRoundTrip", diagnosticSnapshotRoundTrip?.Variables[0]
        is CapturedAgentDiagnosticVariable),
    ("diagnosticSnapshotWire", diagnosticSnapshotWire.Contains(
        "\"extension_id\":\"qyl.agent.diagnostic.snapshot\"")
        && diagnosticSnapshotWire.Contains("\"capture\":\"value\"")),
    ("diagnosticSummaryValueFree", diagnosticSummaryWire.Contains("\"variable_count\":1")
        && !diagnosticSummaryWire.Contains("\"variables\"")),
};

var failed = checks.Where(check => !check.Ok).Select(check => check.Name).ToArray();
if (failed.Length > 0)
{
    Console.Error.WriteLine($"dotnet consumer probe failed {failed.Length}/{checks.Length} checks:");
    foreach (var name in failed)
    {
        Console.Error.WriteLine($"  - {name}");
    }
    return 1;
}

Console.WriteLine($"contract-revision={ContractRevision.Value}");
Console.WriteLine($"workflow-fixture={Convert.ToBase64String(Encoding.UTF8.GetBytes(workflowFixtureWire))}");
Console.WriteLine($"dotnet consumer probe passed {checks.Length} checks");
return 0;
