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
    SessionEventNameValues,
    WorkbenchEvaluationExportFormatValues,
    WorkbenchExecutionStatusValues,
    // Unused below on purpose: a named ESM import of a missing binding is a
    // link-time error, so the import itself asserts the export survives.
    WorkbenchTransportKindValues,
} from "@ancplua/qyl-api-schema/types";
import openapi from "@ancplua/qyl-api-schema/openapi" with { type: "json" };
import schema from "@ancplua/qyl-api-schema/json-schema" with { type: "json" };
// zod is an optional peer, so this import also proves the subpath resolves and
// the published runtime loads under a consumer's own zod rather than one hoisted
// out of this repository.
import { contractDefinitionNames, publishedContractSchema } from "@ancplua/qyl-api-schema/zod";

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

const attributeVariants = schema.$defs["Common.AttributeValue"]?.anyOf ?? [];
const attributeDouble = schema.$defs["Common.AttributeDouble"];
const losslessAttributeValue = attributeVariants.length === 8
    && attributeVariants.some((variant) => variant.type === "null")
    && attributeVariants.some((variant) => variant.$ref === "#/$defs/Common.AttributeIntValue")
    && attributeVariants.some((variant) => variant.$ref === "#/$defs/Common.AttributeDoubleValue")
    && attributeVariants.some((variant) => variant.$ref === "#/$defs/Common.AttributeBytesValue")
    && attributeVariants.some((variant) =>
        variant.type === "array" && variant.items?.$ref === "#/$defs/Common.AttributeValue")
    && attributeVariants.some((variant) => variant.$ref === "#/$defs/Common.AttributeKeyValueListValue")
    && schema.$defs["Common.AttributeInt64"]?.type === "string"
    && JSON.stringify(attributeDouble?.anyOf?.[1]?.enum) === JSON.stringify(["NaN", "Infinity", "-Infinity"])
    && schema.$defs["Common.AttributeBytesValue"]?.properties?.base64?.contentEncoding === "base64"
    && schema.$defs["Common.AttributeKeyValueListValue"]?.properties?.values?.unevaluatedProperties?.$ref
        === "#/$defs/Common.AttributeValue";

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
    && ["/api/v1/metrics", "/api/v1/metrics/{metric_name}/series", "/api/v1/metrics/{metric_name}/query"]
        .every((path) => openapi.paths[path]?.get !== undefined);

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
const zodExportValidatesContracts =
    zodProblemDetails.safeParse({ type: "about:blank", title: "x", status: 500 }).success
    && !zodProblemDetails.safeParse({ type: "about:blank", title: "x", status: "500" }).success
    && contractDefinitionNames().length === Object.keys(schema.$defs).length;

// The npm and NuGet faces of one contract have to agree on bytes, not just on
// field names. SessionEvent is the fixture because every field is required and
// scalar: there is no optional to omit on one side and write as null on the
// other, so a byte difference can only be a real wire divergence — a renamed
// property, a reordered member, or a changed date-time or enum encoding.
const sessionEventFixture = {
    event_name: SessionEventNameValues.sessionStart,
    session_id: "sess-0001",
    timestamp: "2026-07-28T12:34:56+00:00",
    event_domain: "session",
};
const sessionEventFixtureWire = JSON.stringify(sessionEventFixture);

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
    ["eventLogContract", eventLogContract],
    ["losslessAttributeValue", losslessAttributeValue],
    ["exactEntityRef", exactEntityRef],
    ["exactServerConfigurationUnion", exactServerConfigurationUnion],
    ["exactAssertionUnion", exactAssertionUnion],
    ["exactExportUnion", exactExportUnion],
    ["opaqueSdkBoundaries", opaqueSdkBoundaries],
    ["costSurfaceAbsent", costSurfaceAbsent],
    ["healthStatusHealthy", HealthStatusValues.healthy === "healthy"],
    ["runnerResourceLifecycleReady", RunnerResourceLifecycleValues.ready === "ready"],
    ["runnerResourceKindStdio", RunnerResourceKindValues.stdio === "stdio"],
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
console.log(`session-event-fixture=${Buffer.from(sessionEventFixtureWire).toString("base64")}`);
console.log(`npm consumer probe passed ${checks.length} checks`);
