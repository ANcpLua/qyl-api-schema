// Runtime probe for the published npm package, copied verbatim into a clean
// consumer project by scripts/verify-consumers.mjs. It is never compiled or
// executed from inside this repository: in-repo resolution would reach the
// source tree instead of the installed package and prove nothing.
//
// The package specifier is written out rather than interpolated. A rename that
// forgets this file fails here as an unresolved import, which is the intended
// outcome.
import {
    CONTRACT_REVISION,
    HealthStatusValues,
    ProblemDetailsMediaType,
    RunnerResourceKindValues,
    RunnerResourceLifecycleValues,
    RunnerLogStreamValues,
    WorkbenchEvaluationExportFormatValues,
    WorkbenchExecutionStatusValues,
    // Unused below on purpose: a named ESM import of a missing binding is a
    // link-time error, so the import itself asserts the export survives.
    // oxlint-disable-next-line no-unused-vars
    WorkbenchTransportKindValues,
} from "@ancplua/qyl-api-schema/types";
import openapi from "@ancplua/qyl-api-schema/openapi" with { type: "json" };
import schema from "@ancplua/qyl-api-schema/json-schema" with { type: "json" };
// zod is an optional peer, so this import also proves the subpath resolves and
// the published runtime loads under a consumer's own zod rather than one hoisted
// out of this repository.
import { contractDefinitionKeys, contractDefinitionNames, contractSchema, publishedContractSchema } from "@ancplua/qyl-api-schema/zod";
// The runtime subpath ships the generated matcher and the presentation policy over it.
import { attributeIdentity, attributeNumber, formatAttributeValue, matchAttributeValue } from "@ancplua/qyl-api-schema/runtime";

const workbenchRef = (name) => `#/$defs/Workbench.${name}`;

const serverConfigRefs = (schema.$defs["Workbench.WorkbenchServerConfiguration"]?.oneOf ?? [])
    .map((variant) => variant.$ref);
const exactServerConfigurationUnion = JSON.stringify(serverConfigRefs) === JSON.stringify([
    "WorkbenchStdioServerConfiguration",
    "WorkbenchStreamableHttpServerConfiguration",
    "WorkbenchBuiltinServerConfiguration",
].map(workbenchRef));

const assertionRefs = (schema.$defs["Workbench.WorkbenchTestAssertion"]?.oneOf ?? [])
    .map((variant) => variant.$ref);
const exactAssertionUnion = JSON.stringify(assertionRefs) === JSON.stringify([
    "WorkbenchStatusAssertion",
    "WorkbenchExactAssertion",
    "WorkbenchPartialAssertion",
    "WorkbenchSchemaAssertion",
    "WorkbenchPatternAssertion",
    "WorkbenchLatencyAssertion",
].map(workbenchRef));

const exportRefs = (schema.$defs["Workbench.WorkbenchEvaluationExportPayload"]?.oneOf ?? [])
    .map((variant) => variant.$ref);
const exactExportUnion = JSON.stringify(exportRefs) === JSON.stringify([
    "WorkbenchEvaluationJsonExportPayload",
    "WorkbenchEvaluationReportExportPayload",
].map(workbenchRef));

const executionRequest = schema.$defs["Workbench.WorkbenchExecutionRequest"];
const opaqueSdkBoundaries = !schema.$defs["Workbench.WorkbenchContent"]
    && !schema.$defs["Workbench.WorkbenchTool"]
    && !executionRequest?.properties?.arguments?.$ref
    && !schema.$defs["Workbench.WorkbenchExecutionRecord"]?.properties?.result?.$ref;

const runnerState = publishedContractSchema("Runner.RunnerResourceState");
const runnerStateFixture = {
    name: "demo",
    lifecycle: "ready",
    timestamp: "1970-01-01T00:00:00Z",
    kind: "command",
    allocated_port: 4318,
    endpoint: "http://127.0.0.1:4318",
    last_error: "Process exited (code 1)",
};
const runnerKindsMatchProcesses = JSON.stringify(Object.values(RunnerResourceKindValues))
    === JSON.stringify(["collector", "project", "command"]);
const runnerStateWireShape = JSON.stringify(
    Object.keys(schema.$defs["Runner.RunnerResourceState"]?.properties ?? {}).sort(),
) === JSON.stringify(Object.keys(runnerStateFixture).sort());
const runnerStateValidates = runnerState.safeParse(runnerStateFixture).success
    && ["stdio", "http", "inproc"].every((kind) =>
        !runnerState.safeParse({ ...runnerStateFixture, kind }).success)
    && ["server_identity", "tool_count", "restarts"].every((field) =>
        !runnerState.safeParse({ ...runnerStateFixture, [field]: 0 }).success);
const workbenchMcpDiscoveryRetained =
    Boolean(schema.$defs["Workbench.WorkbenchInitializationSnapshot"]?.properties?.server_identity)
    && Boolean(schema.$defs["Workbench.WorkbenchDiscoverySnapshot"]?.properties?.tools)
    && exactServerConfigurationUnion;

const attributeVariants = schema.$defs["Common.AttributeValue"]?.anyOf ?? [];
const attributeObjectValue = schema.$defs["Common.AttributeObjectValue"];
const attributeObjectVariants = attributeObjectValue?.oneOf ?? [];
const attributeDouble = schema.$defs["Common.AttributeDouble"];
// Two levels: bare JSON primitives (and an array of the union itself) at the top, and one
// object member whose variants are discriminated by their `type` tag.
const losslessAttributeValue = attributeVariants.length === 5
    && attributeVariants.some((variant) => variant.type === "null")
    && attributeVariants.some((variant) => variant.type === "string")
    && attributeVariants.some((variant) => variant.type === "boolean")
    && attributeVariants.some((variant) =>
        variant.type === "array" && variant.items?.$ref === "#/$defs/Common.AttributeValue")
    && attributeVariants.some((variant) => variant.$ref === "#/$defs/Common.AttributeObjectValue")
    && attributeObjectValue?.discriminator?.propertyName === "type"
    && attributeObjectVariants.length === 4
    && attributeObjectVariants.some((variant) => variant.$ref === "#/$defs/Common.AttributeIntValue")
    && attributeObjectVariants.some((variant) => variant.$ref === "#/$defs/Common.AttributeDoubleValue")
    && attributeObjectVariants.some((variant) => variant.$ref === "#/$defs/Common.AttributeBytesValue")
    && attributeObjectVariants.some((variant) => variant.$ref === "#/$defs/Common.AttributeKeyValueListValue")
    && JSON.stringify(schema.$defs["Common.AttributeIntValue"]?.properties?.type?.enum) === JSON.stringify(["int"])
    && schema.$defs["Common.AttributeInt64"]?.type === "string"
    && JSON.stringify(attributeDouble?.anyOf?.[1]?.enum) === JSON.stringify(["NaN", "Infinity", "-Infinity"])
    && schema.$defs["Common.AttributeBytesValue"]?.properties?.base64?.contentEncoding === "base64"
    && schema.$defs["Common.AttributeKeyValueListValue"]?.properties?.values?.additionalProperties?.$ref
        === "#/$defs/Common.AttributeValue";

const kvlistFixture = {
    type: "kvlist",
    values: { n: { type: "int", value: "9223372036854775807" }, f: { type: "double", value: "NaN" }, b: { type: "bytes", base64: "AQ==" }, items: ["x", true, null] },
};
const runtimeDecodesEveryVariant =
    formatAttributeValue(kvlistFixture) === '{"n":"9223372036854775807","f":"NaN","b":{"type":"bytes","base64":"AQ=="},"items":["x",true,null]}'
    && formatAttributeValue(null) === "null"
    && attributeNumber({ type: "int", value: "42" }) === 42
    && attributeNumber({ type: "int", value: "9223372036854775807" }) === undefined
    && attributeIdentity({ type: "kvlist", values: { b: 1 === 1, a: "x" } }) === attributeIdentity({ type: "kvlist", values: { a: "x", b: true } })
    && matchAttributeValue(true, { emptyValue: () => "e", stringValue: () => "s", boolValue: () => "b", arrayValue: () => "a", int: () => "i", double: () => "d", bytes: () => "y", kvlist: () => "k" }) === "b";

// The generated name -> type map is the whole published surface, and the typed accessor
// resolves the same validator the string one does.
const typedSchemaCoversEveryDefinition =
    JSON.stringify([...contractDefinitionKeys].sort()) === JSON.stringify([...contractDefinitionNames()].sort())
    && contractSchema("Common.Errors.ProblemDetails") === publishedContractSchema("Common.Errors.ProblemDetails")
    && contractSchema("OTel.Traces.Span").safeParse({}).success === false;

// One identity in every language: this literal is asserted byte for byte by the .NET probe too.
const identityFixture = {
    type: "kvlist",
    values: {
        n: { type: "int", value: "9223372036854775807" },
        f: { type: "double", value: "NaN" },
        g: { type: "double", value: 1e21 },
        h: { type: "double", value: 0.5 },
        b: { type: "bytes", base64: "AQ==" },
        items: ["x", true, null],
        s: "line\n\"q\"",
    },
};
const identityCanonical = "{\"type\":\"kvlist\",\"values\":{\"b\":{\"base64\":\"AQ==\",\"type\":\"bytes\"},\"f\":{\"type\":\"double\",\"value\":\"NaN\"},\"g\":{\"type\":\"double\",\"value\":1e+21},\"h\":{\"type\":\"double\",\"value\":0.5},\"items\":[\"x\",true,null],\"n\":{\"type\":\"int\",\"value\":\"9223372036854775807\"},\"s\":\"line\\n\\\"q\\\"\"}}";
const identityAgreesAcrossLanguages = attributeIdentity(identityFixture) === identityCanonical;

const entityRef = schema.$defs["Common.EntityRef"];
const resourceContract = schema.$defs["OTel.Resource.Resource"];
const exactEntityRef = entityRef?.required?.includes("type")
    && entityRef.required.includes("id_keys")
    && entityRef.properties?.type?.minLength === 1
    && entityRef.properties?.id_keys?.minItems === 1
    && entityRef.properties.id_keys.items?.$ref === "#/$defs/Common.EntityAttributeKey"
    && entityRef.properties?.description_keys?.items?.$ref === "#/$defs/Common.EntityAttributeKey"
    && resourceContract?.properties?.entity_refs?.items?.$ref === "#/$defs/Common.EntityRef";

const logRecord = schema.$defs["OTel.Logs.LogRecord"];
const eventLogContract = logRecord?.properties?.event_name?.type === "string"
    && !logRecord.required?.includes("event_name");

const operations = Object.values(openapi.paths).flatMap((path) => Object.values(path));
const errorResponses = operations
    .flatMap((operation) => Object.values(operation.responses ?? {}))
    .filter((response) => Object.values(response.content ?? {}).some((media) =>
        media.schema?.$ref?.startsWith("#/components/schemas/Common.Errors.")));
const errorsOwnProblemJson = errorResponses.length > 0
    && errorResponses.every((response) =>
        Object.keys(response.content ?? {}).length === 1 && response.content[ProblemDetailsMediaType]);

const workbenchOperations = Object.entries(openapi.paths)
    .filter(([path]) => path.startsWith("/workbench/"))
    .flatMap(([path, pathItem]) =>
        Object.entries(pathItem).map(([method, operation]) => ({ path, method, operation })));
const privateWorkbenchOperations = workbenchOperations
    .filter(({ path, method }) => !(path === "/workbench/session" && method === "post"));
const workbenchCookieAuth = workbenchOperations.length === 45
    && privateWorkbenchOperations.length === 44
    && openapi.components?.securitySchemes?.WorkbenchSessionCookieAuth?.name === "qyl-workbench-session"
    && privateWorkbenchOperations.every(({ operation }) =>
        operation.security?.some((entry) => "WorkbenchSessionCookieAuth" in entry));

const typedBootstrapCookie =
    openapi.paths["/workbench/session"]?.post?.responses?.["200"]?.headers?.["Set-Cookie"]?.required === true;

const logStreamCapacityResponseDeclared = (() => {
    const content = openapi.paths["/api/v1/stream/logs"]?.get?.responses?.["503"]?.content ?? {};
    return Object.keys(content).length === 1
        && content[ProblemDetailsMediaType]?.schema?.$ref
            === "#/components/schemas/Common.Errors.ServiceUnavailableError";
})();

const typedQueryPaths = [
    "/api/v1/traces",
    "/api/v1/logs",
    "/api/v1/sessions",
    "/api/v1/sessions/stats",
    "/api/v1/stream/logs",
];
const typedQueryValidationResponsesDeclared = typedQueryPaths.every((path) => {
    const content = openapi.paths[path]?.get?.responses?.["400"]?.content ?? {};
    return Object.keys(content).length === 1
        && content[ProblemDetailsMediaType]?.schema?.$ref
            === "#/components/schemas/Common.Errors.ValidationError";
});

// These enums mirrored raw OTLP wire vocabulary that no route ever exposed.
// The metrics surface below models qyl's own storage and query vocabulary
// instead, so their absence still holds and is still worth asserting.
const removedSignalEnums = new Set([
    "OTel.Enums.MetricType",
    "OTel.Enums.AggregationTemporality",
    "OTel.Enums.DataPointFlags",
    "OTel.Enums.InstrumentKind",
    "OTel.Enums.OriginalPayloadFormat",
    "OTel.Enums.ProfileFrameType",
]);
const telemetryResponse = schema.$defs["Workbench.WorkbenchExecutionTelemetryResponse"];
const telemetrySignals = schema.$defs["Workbench.WorkbenchTelemetrySignalSummary"];
const profileSurfaceAbsent = Object.keys(schema.$defs).every((name) =>
    !name.startsWith("OTel.Profiles.") && !removedSignalEnums.has(name))
    && Object.keys(openapi.paths).every((path) => !path.startsWith("/api/v1/profiles"))
    && !("metrics" in (telemetryResponse?.properties ?? {}))
    && !("metrics" in (telemetrySignals?.properties ?? {}));

// The collector stores and serves metrics, so the query surface must ship: the
// catalog, the series listing, and the range query the whole design turns on.
const metricSurfacePresent = [
    "OTel.Metrics.MetricDescriptor",
    "OTel.Metrics.MetricSeries",
    "OTel.Metrics.MetricQueryResult",
    "OTel.Metrics.MetricAggregation",
].every((name) => name in schema.$defs)
    && ["/api/v1/metrics", "/api/v1/metrics/{metric_name}/series", "/api/v1/metrics/{metric_name}/query",
        "/api/v1/metrics/{metric_name}/series/{series_id}/points"]
        .every((path) => openapi.paths[path]?.get !== undefined);

const metricPointSchema = contractSchema("OTel.Metrics.MetricPoint");
const pointFixture = {
    observation_id: "original", has_conflict: false, series_id: "series", time_unix_nano: "100", attributes: [],
    data: { type: "number", value: { type: "int", value: "9007199254740993" } },
};
const parsedPoint = metricPointSchema.parse(JSON.parse(JSON.stringify(pointFixture)));
const metricOriginalsRemainExact = parsedPoint.data.value.value === "9007199254740993"
    && BigInt(parsedPoint.data.value.value) === 9007199254740993n
    && !metricPointSchema.safeParse({ ...pointFixture, data: { type: "number", value: { type: "int", value: 9007199254740992 } } }).success
    && !metricPointSchema.safeParse({ ...pointFixture, data: { type: "number", value: { type: "int", value: "9223372036854775808" } } }).success
    && !contractSchema("OTel.Metrics.MetricCount").safeParse("18446744073709551616").success
    && metricPointSchema.safeParse({
        ...pointFixture, data: {
            type: "exponential_histogram", count: "18446744073709551615", scale: -4, zero_count: "4", zero_threshold: 0.01,
            positive: { offset: -2, bucket_counts: ["5", "18446744073709551606"] },
        },
    }).success
    && metricPointSchema.safeParse({
        ...pointFixture, data: { type: "summary", count: "2", sum: 3, quantile_values: [{ quantile: 0.5, value: 1.5 }] },
    }).success;
const historicalPoint = metricPointSchema.parse({ ...pointFixture, data: null, projection: { value: 9007199254740992 } });
const unknownOriginalStaysUnknown = historicalPoint.data === null
    && historicalPoint.flags === undefined && historicalPoint.exemplars === undefined
    && !metricPointSchema.safeParse({ ...pointFixture, data: undefined }).success;

const costSurfaceAbsent = Object.keys(schema.$defs).every((name) => !name.startsWith("Cost."))
    && Object.keys(openapi.paths).every((path) => !path.startsWith("/api/v1/cost"));

// The revision is only useful if a client can read the package's own value and
// the collector's advertised one and compare them, so both halves are checked
// here: the exported constant, and the health surface that carries the peer's.
const healthReport = schema.$defs["Health.HealthReport"];
const healthAdvertisesRevision = healthReport?.required?.includes("contract_revision") === true
    && healthReport.properties?.contract_revision?.$ref === "#/$defs/Common.ContractRevision"
    && schema.$defs["Common.ContractRevision"]?.pattern === "^sha256:[a-f0-9]{16}$";

// The runtime builds its validators from the package's own JSON Schema, so a
// definition count that matches the schema imported above proves the installed
// copy is validating the installed contract and not a bundled snapshot.
const zodProblemDetails = publishedContractSchema("Common.Errors.ProblemDetails");
const internalProblem = {
    type: "https://qyl.at/problems/internal-error",
    title: "Internal Server Error",
    status: 500,
    code: "internal_error",
};
const zodExportValidatesContracts =
    zodProblemDetails.safeParse(internalProblem).success
    && !zodProblemDetails.safeParse({ ...internalProblem, status: "500" }).success
    && !zodProblemDetails.safeParse({ ...internalProblem, type: "about:blank" }).success
    && contractDefinitionNames().length === Object.keys(schema.$defs).length;

// Compare a real runner response across both packages, with every required
// field supplied so omission and null policies cannot mask a wire difference.
const runnerLogFixture = {
    resource: "worker",
    stream: RunnerLogStreamValues.stderr,
    line: "startup failed",
};
const runnerLogFixtureWire = JSON.stringify(runnerLogFixture);

// Each entry is reported by name when it fails. A single OR-chained exit code
// tells a release operator that something is wrong and nothing about what.
const checks = [
    ["problemDetailsMediaType", ProblemDetailsMediaType === "application/problem+json"],
    ["errorsOwnProblemJson", errorsOwnProblemJson],
    ["workbenchCookieAuth", workbenchCookieAuth],
    ["typedBootstrapCookie", typedBootstrapCookie],
    ["logStreamCapacityResponseDeclared", logStreamCapacityResponseDeclared],
    ["typedQueryValidationResponsesDeclared", typedQueryValidationResponsesDeclared],
    ["profileSurfaceAbsent", profileSurfaceAbsent],
    ["metricSurfacePresent", metricSurfacePresent],
    ["metricOriginalsRemainExact", metricOriginalsRemainExact],
    ["unknownOriginalStaysUnknown", unknownOriginalStaysUnknown],
    ["eventLogContract", eventLogContract],
    ["losslessAttributeValue", losslessAttributeValue],
    ["runtimeDecodesEveryVariant", runtimeDecodesEveryVariant],
    ["typedSchemaCoversEveryDefinition", typedSchemaCoversEveryDefinition],
    ["identityAgreesAcrossLanguages", identityAgreesAcrossLanguages],
    ["exactEntityRef", exactEntityRef],
    ["exactServerConfigurationUnion", exactServerConfigurationUnion],
    ["exactAssertionUnion", exactAssertionUnion],
    ["exactExportUnion", exactExportUnion],
    ["opaqueSdkBoundaries", opaqueSdkBoundaries],
    ["costSurfaceAbsent", costSurfaceAbsent],
    ["healthStatusHealthy", HealthStatusValues.healthy === "healthy"],
    ["runnerResourceLifecycleReady", RunnerResourceLifecycleValues.ready === "ready"],
    ["runnerKindsMatchProcesses", runnerKindsMatchProcesses],
    ["runnerStateWireShape", runnerStateWireShape],
    ["runnerStateValidates", runnerStateValidates],
    ["workbenchMcpDiscoveryRetained", workbenchMcpDiscoveryRetained],
    ["workbenchExecutionStatusTimedOut", WorkbenchExecutionStatusValues.timedOut === "timed_out"],
    ["workbenchEvaluationExportFormatReport", WorkbenchEvaluationExportFormatValues.report === "report"],
    ["fetchTelemetryInputDefined", Boolean(schema.$defs["Mcp.Tools.FetchTelemetryInput"])],
    ["ciLogShapesDefined", Boolean(schema.$defs["Mcp.Tools.CiLogInput"])
        && Boolean(schema.$defs["Mcp.Tools.CiLogOutput"])],
    ["contractRevisionExported", /^sha256:[a-f0-9]{16}$/.test(CONTRACT_REVISION)],
    ["zodExportValidatesContracts", zodExportValidatesContracts],
    ["healthAdvertisesRevision", healthAdvertisesRevision],
];

const failed = checks.filter(([, ok]) => !ok).map(([name]) => name);
if (failed.length > 0) {
    console.error(`npm consumer probe failed ${failed.length}/${checks.length} checks:`);
    for (const name of failed) console.error(`  - ${name}`);
    process.exit(1);
}
console.log(`contract-revision=${CONTRACT_REVISION}`);
// prepack stamps the release version into the packed OpenAPI document; the
// caller compares it with the version it installed.
console.log(`openapi-version=${openapi.info.version}`);
console.log(`runner-log-fixture=${Buffer.from(runnerLogFixtureWire).toString("base64")}`);
console.log(`npm consumer probe passed ${checks.length} checks`);
