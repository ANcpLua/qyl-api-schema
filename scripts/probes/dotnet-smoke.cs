// Runtime probe for the published NuGet package, copied verbatim to Program.cs
// in a clean console project by scripts/verify-consumers.mjs. It is not part of
// any solution here: built in-repo it would reference the local emitter output
// instead of the restored Qyl.Api.Contracts package and prove nothing.
//
// It asserts wire shape, not just type shape — the Contains checks below read
// serialized JSON, so a rename that keeps C# compiling still fails here.
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text;
using ModelContextProtocol;
using ModelContextProtocol.Protocol;
using Qyl.Api.Contracts;
using Qyl.Api.Contracts.Common.Errors;
using System.Linq;
using Qyl.Api.Contracts.Health;
using Qyl.Api.Contracts.Mcp.Tools;
using Qyl.Api.Contracts.OTel.Enums;
using Qyl.Api.Contracts.OTel.Logs;
using Qyl.Api.Contracts.OTel.Metrics;
using Qyl.Api.Contracts.Runner;
using Qyl.Api.Contracts.Workbench;
#pragma warning disable MCPEXP001
using Qyl.Api.Contracts.Common;
using OTelAttribute = Qyl.Api.Contracts.Common.Attribute;
using OTelResource = Qyl.Api.Contracts.OTel.Resource.Resource;

var health = JsonSerializer.Serialize(HealthStatus.Healthy);
var lifecycle = JsonSerializer.Serialize(RunnerResourceLifecycle.Ready);
var kind = JsonSerializer.Serialize(RunnerResourceKind.Command);

var eventLog = new LogRecord
{
    TimeUnixNano = 2,
    ObservedTimeUnixNano = 3,
    SeverityNumber = SeverityNumber.Info,
    SeverityText = "NOTICE",
    Flags = uint.MaxValue,
    InstrumentationScope = new InstrumentationScope
    {
        ScopeName = "custom.instrumentation",
        ScopeVersion = "main/7b3e019",
        SchemaUrl = "https://opentelemetry.io/schemas/1.44.0",
        DroppedAttributesCount = 3,
    },
    Body = new AttributeValue.StringValue("evaluation completed"),
    EventName = "gen_ai.evaluation.result",
    Resource = new OTelResource { ServiceName = "evaluator" },
};
var eventLogWire = JsonSerializer.Serialize(eventLog);
var eventLogRoundTrip = JsonSerializer.Deserialize<LogRecord>(eventLogWire);

var emptyAttribute = new OTelAttribute { Key = "empty", Value = null };
var intAttribute = new OTelAttribute
{
    Key = "int",
    Value = new AttributeValue.ObjectValue(new AttributeIntValue { Value = long.MaxValue }),
};
var doubleAttribute = new OTelAttribute
{
    Key = "double",
    Value = new AttributeValue.ObjectValue(new AttributeDoubleValue { Value = double.PositiveInfinity }),
};
var kvlistAttribute = new OTelAttribute
{
    Key = "kvlist",
    Value = new AttributeValue.ObjectValue(new AttributeKeyValueListValue
    {
        Values = new Dictionary<string, AttributeValue?>
        {
            ["empty"] = null,
            ["nested"] = new AttributeValue.ObjectValue(new AttributeIntValue { Value = 1 }),
            ["flag"] = new AttributeValue.BoolValue(true),
            ["items"] = new AttributeValue.ArrayValue([new AttributeValue.StringValue("a"), null]),
        },
    }),
};

// One identity in every language: the same literal the npm probe asserts.
var identityFixture = new AttributeValue.ObjectValue(new AttributeKeyValueListValue
{
    Values = new Dictionary<string, AttributeValue?>
    {
        ["n"] = new AttributeValue.ObjectValue(new AttributeIntValue { Value = long.MaxValue }),
        ["f"] = new AttributeValue.ObjectValue(new AttributeDoubleValue { Value = double.NaN }),
        ["g"] = new AttributeValue.ObjectValue(new AttributeDoubleValue { Value = 1e21 }),
        ["h"] = new AttributeValue.ObjectValue(new AttributeDoubleValue { Value = 0.5 }),
        ["b"] = new AttributeValue.ObjectValue(new AttributeBytesValue { Base64 = new byte[] { 1 } }),
        ["items"] = new AttributeValue.ArrayValue([new AttributeValue.StringValue("x"), new AttributeValue.BoolValue(true), null]),
        ["s"] = new AttributeValue.StringValue("line\n\"q\""),
    },
});
const string identityCanonical = "{\"type\":\"kvlist\",\"values\":{\"b\":{\"base64\":\"AQ==\",\"type\":\"bytes\"},\"f\":{\"type\":\"double\",\"value\":\"NaN\"},\"g\":{\"type\":\"double\",\"value\":1e+21},\"h\":{\"type\":\"double\",\"value\":0.5},\"items\":[\"x\",true,null],\"n\":{\"type\":\"int\",\"value\":\"9223372036854775807\"},\"s\":\"line\\n\\\"q\\\"\"}}";
var identityAgreesAcrossLanguages = identityFixture.ToStableString() == identityCanonical
    && AttributeValue.StableString(null) == "null";

var entityRef = new EntityRef
{
    SchemaUrl = "https://opentelemetry.io/schemas/1.44.0",
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
    Kind = RunnerResourceKind.Command,
    AllocatedPort = 4318,
    Endpoint = new Uri("http://127.0.0.1:4318"),
    LastError = "Process exited (code 1)",
};
var stateWire = JsonSerializer.SerializeToElement(state);
var runnerStateWireShape = stateWire.EnumerateObject().Select(property => property.Name)
    .Order(StringComparer.Ordinal).SequenceEqual(new[]
    {
        "allocated_port", "endpoint", "kind", "last_error", "lifecycle", "name", "timestamp",
    });
var runnerKindsMatchProcesses = Enum.GetNames<RunnerResourceKind>()
    .SequenceEqual(new[] { "Collector", "Project", "Command" });
var obsoleteRunnerKindRejected = true;
foreach (var obsoleteKind in new[] { "stdio", "http", "inproc" })
{
    try
    {
        JsonSerializer.Deserialize<RunnerResourceKind>($"\"{obsoleteKind}\"");
        obsoleteRunnerKindRejected = false;
    }
    catch (JsonException)
    {
        // Removed wire values must fail instead of masquerading as processes.
    }
}

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

FetchTelemetryInput toolInput = new FetchTelemetryTracesInput { Limit = 10 };
var toolInputWire = JsonSerializer.Serialize(toolInput);

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

// A problem names its type by URI and by code; the generated enums must reach
// the wire as those exact strings, which is what a server writes and a client
// branches on.
var notFound = new NotFoundError
{
    Type = ProblemType.NotFound,
    Code = ProblemCode.NotFound,
    Title = "Not Found",
    Status = 404,
    ResourceType = "trace",
};
var notFoundWire = JsonSerializer.Serialize(notFound);
var notFoundRoundTrip = JsonSerializer.Deserialize<NotFoundError>(notFoundWire);

// Compare a real runner response with the npm consumer's exact wire fixture.
var runnerLog = new RunnerLogLine
{
    Resource = "worker",
    Stream = RunnerLogStream.Stderr,
    Line = "startup failed",
};
var runnerLogFixtureWire = JsonSerializer.Serialize(runnerLog);

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
    && resourceRoundTrip.Attributes[1].Value is AttributeValue.ObjectValue { Value: AttributeIntValue { Value: long.MaxValue } }
    && resourceRoundTrip.Attributes[3].Value is AttributeValue.ObjectValue { Value: AttributeKeyValueListValue { Values.Count: 4 } }
    && resourceRoundTrip.EntityRefs?[0] is { Type: "service", IdKeys.Count: 1 }
    && resourceWire.Contains("\"type\":\"int\",\"value\":\"9223372036854775807\"")
    && resourceWire.Contains("\"type\":\"double\",\"value\":\"Infinity\"")
    && resourceWire.Contains("\"type\":\"kvlist\"");

var contractTypes = typeof(FetchTelemetryInput).Assembly.GetTypes();
// The named enums mirrored raw OTLP wire vocabulary no route ever exposed;
// OTel.Metrics now models qyl's own storage and query vocabulary and must ship.
var removedSignalContractsAbsent = !contractTypes.Any(type =>
    type.Namespace?.StartsWith("Qyl.Api.Contracts.OTel.Profiles") == true
    || type.Name is "MetricType" or "AggregationTemporality" or "DataPointFlags"
        or "InstrumentKind" or "OriginalPayloadFormat" or "ProfileFrameType");
var metricContractsPresent = new[] { "MetricDescriptor", "MetricSeries", "MetricQueryResult" }
    .All(name => contractTypes.Any(type =>
        type.Namespace == "Qyl.Api.Contracts.OTel.Metrics" && type.Name == name));

// These are restored-package runtime checks. The reused Common numeric models
// must implement both discriminated unions, and nullable original data must
// remain typed instead of degrading to JsonElement/object in the C# emitter.
var integerPoint = JsonSerializer.Deserialize<MetricPoint>("""
    {"observation_id":"int","has_conflict":false,"series_id":"s","time_unix_nano":"100",
     "attributes":[],"flags":4294967295,"resource_dropped_attributes_count":2,"scope_dropped_attributes_count":3,
     "data":{"type":"number","value":{"type":"int","value":"9007199254740993"}},
     "exemplars":[
       {"time_unix_nano":"98","value":{"type":"int","value":"9223372036854775807"},"filtered_attributes":[]},
       {"time_unix_nano":"99","value":{"type":"double","value":"Infinity"},"filtered_attributes":[]}]}
    """)!;
var integerPointWire = JsonSerializer.Serialize(integerPoint);
var integerPointAgain = JsonSerializer.Deserialize<MetricPoint>(integerPointWire)!;
var nativePoint = JsonSerializer.Deserialize<MetricPoint>("""
    {"observation_id":"native","has_conflict":false,"series_id":"s","time_unix_nano":"101","attributes":[],
     "data":{"type":"exponential_histogram","count":"18446744073709551615","sum":"NaN","scale":-3,
       "zero_count":"4","zero_threshold":0.01,"positive":{"offset":-2,"bucket_counts":["5","18446744073709551606"]},
       "negative":{"offset":7,"bucket_counts":["0"]}}}
    """)!;
var nativeAgain = JsonSerializer.Deserialize<MetricPoint>(JsonSerializer.Serialize(nativePoint))!;
var histogramPoint = JsonSerializer.Deserialize<MetricPoint>("""
    {"observation_id":"explicit","has_conflict":true,"series_id":"s","time_unix_nano":"102","attributes":[],
     "data":{"type":"histogram","count":"2","min":"-Infinity","max":"Infinity",
       "explicit_bounds":["-Infinity",0,"Infinity"],"bucket_counts":["0","1","1","0"]}}
    """)!;
var histogramAgain = JsonSerializer.Deserialize<MetricPoint>(JsonSerializer.Serialize(histogramPoint))!;
var summaryPoint = JsonSerializer.Deserialize<MetricPoint>("""
    {"observation_id":"summary","has_conflict":false,"series_id":"s","time_unix_nano":"103","attributes":[],
     "data":{"type":"summary","count":"2","sum":3,"quantile_values":[{"quantile":0.5,"value":1.5}]}}
    """)!;
var summaryAgain = JsonSerializer.Deserialize<MetricPoint>(JsonSerializer.Serialize(summaryPoint))!;
var historicalPoint = JsonSerializer.Deserialize<MetricPoint>("""
    {"observation_id":"historical","has_conflict":false,"series_id":"s","time_unix_nano":"104","attributes":[],
     "data":null,"historical_exemplar_trace_ids":["0123456789abcdef0123456789abcdef"],
     "projection":{"value":9007199254740992,"count":"18446744073709551615","sum":4,"min":1,"max":3}}
    """)!;
var historicalWire = JsonSerializer.Serialize(historicalPoint, new JsonSerializerOptions
{
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
});
var historicalAgain = JsonSerializer.Deserialize<MetricPoint>(historicalWire)!;
var unknownLog = JsonSerializer.Deserialize<LogRecord>("""
    {"severity_number":9,"body":"historical","resource":{"service_name":"legacy"}}
    """)!;
var unknownLogWire = JsonSerializer.SerializeToElement(unknownLog);

// Each entry is reported by name when it fails. A single OR-chained exit code
// tells a release operator that something is wrong and nothing about what.
var checks = new (string Name, bool Ok)[]
{
    ("problemDetailsMediaType", ProblemDetailsMediaType.Value == "application/problem+json"),
    ("problemTypeUriWire", notFoundWire.Contains("\"type\":\"https://qyl.at/problems/not-found\"")),
    ("problemCodeWire", notFoundWire.Contains("\"code\":\"not_found\"")),
    ("problemRoundTrip", notFoundRoundTrip is { Type: ProblemType.NotFound, Code: ProblemCode.NotFound }),
    ("eventLogWireEventName", eventLogWire.Contains("\"event_name\":\"gen_ai.evaluation.result\"")),
    ("producerLogMetadataRoundTrip", eventLogRoundTrip is
        { SeverityText: "NOTICE", Flags: uint.MaxValue, InstrumentationScope:
            { ScopeVersion: "main/7b3e019", SchemaUrl: "https://opentelemetry.io/schemas/1.44.0", DroppedAttributesCount: 3 } }),
    ("otlpFidelityValid", otlpFidelityValid),
    ("identityAgreesAcrossLanguages", identityAgreesAcrossLanguages),
    ("removedSignalContractsAbsent", removedSignalContractsAbsent),
    ("metricContractsPresent", metricContractsPresent),
    ("metricExactSignedInteger", integerPointAgain.Data is MetricNumberPointData
        { Value: AttributeIntValue { Value: 9007199254740993L } }
        && integerPointWire.Contains("\"value\":\"9007199254740993\"")),
    ("metricOrderedExemplars", integerPointAgain.Exemplars is { Count: 2 } exemplars
        && exemplars[0] is { TimeUnixNano: 98, Value: AttributeIntValue { Value: long.MaxValue } }
        && exemplars[1] is { TimeUnixNano: 99, Value: AttributeDoubleValue { Value: double.PositiveInfinity } }),
    ("metricObservationMetadata", integerPointAgain is
        { Flags: uint.MaxValue, ResourceDroppedAttributesCount: 2, ScopeDroppedAttributesCount: 3 }),
    ("nativeExponentialHistogram", nativeAgain.Data is MetricExponentialHistogramPointData
        { Count: ulong.MaxValue, Scale: -3, ZeroCount: 4, ZeroThreshold: 0.01, Sum: double.NaN,
            Positive: { Offset: -2, BucketCounts.Count: 2 } positive, Negative.Offset: 7 }
        && positive.BucketCounts[0] == 5 && positive.BucketCounts[1] == 18446744073709551606UL),
    ("histogramNonFiniteBounds", histogramAgain.Data is MetricHistogramPointData
        { ExplicitBounds.Count: 3, BucketCounts.Count: 4, Min: double.NegativeInfinity, Max: double.PositiveInfinity } histogram
        && double.IsNegativeInfinity(histogram.ExplicitBounds[0]) && histogram.ExplicitBounds[1] == 0
        && double.IsPositiveInfinity(histogram.ExplicitBounds[2]) && histogram.BucketCounts[1] == 1),
    ("summaryOriginalQuantiles", summaryAgain.Data is MetricSummaryPointData
        { Count: 2, Sum: 3, QuantileValues.Count: 1 } summary
        && summary.QuantileValues[0] is { Quantile: 0.5, Value: 1.5 }),
    ("historicalOriginalRemainsUnknown", historicalAgain is { Data: null, Flags: null, Exemplars: null,
            Projection: { Count: ulong.MaxValue, Sum: 4, Min: 1, Max: 3 }, HistoricalExemplarTraceIds.Count: 1 }
        && historicalWire.Contains("\"data\":null")),
    ("unknownLogTimesRemainAbsent", unknownLog.TimeUnixNano is null && unknownLog.ObservedTimeUnixNano is null
        && !unknownLogWire.TryGetProperty("time_unix_nano", out _)
        && !unknownLogWire.TryGetProperty("observed_time_unix_nano", out _)),
    ("fetchTelemetryInputNamespace", typeof(FetchTelemetryInput).Namespace == "Qyl.Api.Contracts.Mcp.Tools"),
    ("costSurfaceAbsent", !contractTypes.Any(type =>
        type.Namespace is not null && type.Namespace.StartsWith("Qyl.Api.Contracts.Cost"))),
    ("healthStatusHealthy", health == "\"healthy\""),
    ("runnerResourceLifecycleReady", lifecycle == "\"ready\""),
    ("runnerResourceKindCommand", kind == "\"command\""),
    ("runnerKindsMatchProcesses", runnerKindsMatchProcesses),
    ("runnerStateWireShape", runnerStateWireShape),
    ("obsoleteRunnerKindRejected", obsoleteRunnerKindRejected),
    ("runnerResourceStateRoundTrip", JsonSerializer.Deserialize<RunnerResourceState>(stateWire)
        is { Name: "demo", Lifecycle: RunnerResourceLifecycle.Ready, Kind: RunnerResourceKind.Command,
            AllocatedPort: 4318, LastError: "Process exited (code 1)" } restoredState
        && restoredState.Timestamp == DateTimeOffset.UnixEpoch
        && restoredState.Endpoint == new Uri("http://127.0.0.1:4318")),
    ("fetchTelemetryViewTraces", toolInputWire.Contains("\"view\":\"traces\"")
        && JsonSerializer.Deserialize<FetchTelemetryInput>(toolInputWire) is FetchTelemetryTracesInput),
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
Console.WriteLine($"runner-log-fixture={Convert.ToBase64String(Encoding.UTF8.GetBytes(runnerLogFixtureWire))}");
Console.WriteLine($"dotnet consumer probe passed {checks.Length} checks");
return 0;
