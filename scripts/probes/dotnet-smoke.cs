// Runtime probe for the published NuGet package, copied verbatim to Program.cs
// in a clean console project by scripts/verify-consumers.mjs. It is not part of
// any solution here: built in-repo it would reference the local emitter output
// instead of the restored Qyl.Api.Contracts package and prove nothing.
//
// It asserts wire shape, not just type shape — the Contains checks below read
// serialized JSON, so a rename that keeps C# compiling still fails here.
using System.Text.Json;
using ModelContextProtocol;
using ModelContextProtocol.Protocol;
using Qyl.Api.Contracts.Common.Errors;
using System.Linq;
using Qyl.Api.Contracts.Health;
using Qyl.Api.Contracts.Mcp.Tools;
using Qyl.Api.Contracts.OTel.Enums;
using Qyl.Api.Contracts.OTel.Logs;
using Qyl.Api.Contracts.Runner;
using Qyl.Api.Contracts.Workbench;
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

Console.WriteLine($"dotnet consumer probe passed {checks.Length} checks");
return 0;
