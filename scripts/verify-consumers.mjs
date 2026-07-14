import { access, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const npmPackage = "@ancplua/qyl-api-schema";
const nugetPackage = "Qyl.Api.Contracts";
const mcpSdkPackage = "ModelContextProtocol.Core";
const mcpSdkVersion = "1.4.1";
const nugetOrg = "https://api.nuget.org/v3/index.json";
const typeSpecToolchainPackages = [
  "compiler",
  "events",
  "http",
  "openapi",
  "openapi3",
  "sse",
];

async function exists(path) {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

function run(command, args, cwd, environment = {}) {
  const result = spawnSync(command, args, {
    cwd,
    encoding: "utf8",
    stdio: "inherit",
    env: { ...process.env, ...environment },
  });
  if (result.status !== 0) throw new Error(`${command} ${args.join(" ")} failed with ${result.status}`);
}

function escapeXml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("\"", "&quot;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

export async function verifyConsumers({ version, npmSpec, npmInstallArgs = [], nugetSource }) {
  const root = await mkdtemp(join(tmpdir(), "qyl-contract-consumers-"));
  try {
    const npmDir = join(root, "npm");
    await mkdir(npmDir);
    run("npm", ["init", "--yes"], npmDir);
    run(
      "npm",
      ["install", "--save-exact", npmSpec, ...npmInstallArgs, "--ignore-scripts"],
      npmDir,
      { NPM_CONFIG_CACHE: join(root, "npm-cache") },
    );
    const installedToolchainPackages = [];
    for (const packageName of typeSpecToolchainPackages) {
      if (await exists(join(npmDir, "node_modules", "@typespec", packageName))) {
        installedToolchainPackages.push(`@typespec/${packageName}`);
      }
    }
    if (installedToolchainPackages.length > 0) {
      throw new Error(
        `generated-only npm consumer unexpectedly installed the TypeSpec toolchain: ${installedToolchainPackages.join(", ")}`,
      );
    }
    await writeFile(
      join(npmDir, "smoke.mjs"),
      `import { GenAiEtlCandidateStatusValues, GenAiEtlEvidenceSignalValues, GenAiEtlFrontierCostBasisValues, GenAiEtlValidationMetricValues, HealthStatusValues, ModelCatalogBillingModeValues, ModelCatalogMatchKindValues, ModelCatalogObservedIdentityBasisValues, ModelCatalogPriceSemanticsValues, ModelCatalogRateRelationValues, ModelCatalogTokenExclusionReasonValues, ProblemDetailsMediaType, ProviderBillingAttributionValues, ProviderBillingSourceStatusValues, RunnerMcpTaskStatusValues, RunnerMcpToolTaskSupportValues, RunnerResourceKindValues, RunnerResourceLifecycleValues } from ${JSON.stringify(`${npmPackage}/types`)};\n` +
        `import openapi from ${JSON.stringify(`${npmPackage}/openapi`)} with { type: "json" };\n` +
        `import schema from ${JSON.stringify(`${npmPackage}/json-schema`)} with { type: "json" };\n` +
        `const content = schema.$defs["Runner.Mcp.RunnerMcpContent"];\n` +
        `const contentRefs = (content?.oneOf ?? []).map((variant) => variant.$ref);\n` +
        `const expectedContentRefs = ["RunnerMcpTextContent", "RunnerMcpImageContent", "RunnerMcpAudioContent", "RunnerMcpEmbeddedResourceContent", "RunnerMcpResourceLinkContent", "RunnerMcpToolUseContent", "RunnerMcpToolResultContent"].map((name) => "#/$defs/Runner.Mcp." + name);\n` +
        `const exactContentUnion = JSON.stringify(contentRefs) === JSON.stringify(expectedContentRefs) && schema.$defs["Runner.Mcp.RunnerMcpTextContent"]?.required?.includes("text") && schema.$defs["Runner.Mcp.RunnerMcpImageContent"]?.required?.includes("data") && schema.$defs["Runner.Mcp.RunnerMcpToolResultContent"]?.required?.includes("content");\n` +
        `const resourceRefs = (schema.$defs["Runner.Mcp.RunnerMcpResourceContent"]?.oneOf ?? []).map((variant) => variant.$ref);\n` +
        `const exactResourceUnion = JSON.stringify(resourceRefs) === JSON.stringify(["#/$defs/Runner.Mcp.RunnerMcpTextResourceContent", "#/$defs/Runner.Mcp.RunnerMcpBlobResourceContent"]) && schema.$defs["Runner.Mcp.RunnerMcpTextResourceContent"]?.required?.includes("text") && schema.$defs["Runner.Mcp.RunnerMcpBlobResourceContent"]?.required?.includes("blob");\n` +
        `const attributeVariants = schema.$defs["Common.AttributeValue"]?.anyOf ?? [];\n` +
        `const recursiveAttributeValue = attributeVariants.some((variant) => variant.$ref === "#/$defs/Common.AttributeBytesValue") && attributeVariants.some((variant) => variant.type === "array" && variant.items?.$ref === "#/$defs/Common.AttributeValue") && attributeVariants.some((variant) => variant.$ref === "#/$defs/Common.AttributeKeyValueListValue") && schema.$defs["Common.AttributeBytesValue"]?.properties?.base64?.contentEncoding === "base64";\n` +
        `const auditCluster = schema.$defs["Cost.GenAiEtlAuditCluster"];\n` +
        `const compoundValidationMetrics = auditCluster?.required?.includes("validation_metrics") && !auditCluster.required.includes("validation_metric") && auditCluster.properties?.validation_metrics?.type === "array" && auditCluster.properties.validation_metrics.minItems === 1 && auditCluster.properties.validation_metrics.items?.$ref === "#/$defs/Cost.GenAiEtlValidationMetric" && !("validation_metric" in (auditCluster.properties ?? {}));\n` +
        `const qualifiedCandidate = auditCluster?.required?.includes("candidate_status") && auditCluster.properties?.candidate_status?.allOf?.[0]?.$ref === "#/$defs/Cost.GenAiEtlCandidateStatus" && JSON.stringify(Object.values(GenAiEtlCandidateStatusValues)) === JSON.stringify(["hypothesis_only", "insufficient_evidence"]);\n` +
        `const auditReport = schema.$defs["Cost.GenAiEtlAuditReport"];\n` +
        `const removedCostDefinitions = ["ProviderCostSourceKind", "ProviderCostSourceStatus", "ProviderCostAttribution", "ProviderCostSource", "ModelCatalogSourceKind", "GenAiEtlCalculationStatus"].every((name) => !schema.$defs["Cost." + name]);\n` +
        `const billingStatuses = ["unconfigured", "pending", "current", "stale", "sync_failed"];\n` +
        `const billingAttributions = ["provider_model_period", "provider_period", "unavailable"];\n` +
        `const aggregateBilling = removedCostDefinitions && JSON.stringify(Object.values(ProviderBillingSourceStatusValues)) === JSON.stringify(billingStatuses) && JSON.stringify(Object.values(ProviderBillingAttributionValues)) === JSON.stringify(billingAttributions) && auditReport?.required?.includes("billing_sources") && !("cost_sources" in auditReport.properties) && auditReport.properties?.billing_sources?.items?.$ref === "#/$defs/Cost.ProviderBillingSource" && !("kind" in schema.$defs["Cost.ProviderBillingSource"].properties);\n` +
        `const catalogSource = schema.$defs["Cost.ModelCatalogSource"];\n` +
        `const requiredCatalogSources = auditReport?.required?.includes("catalog_sources") && auditReport.properties?.catalog_sources?.items?.$ref === "#/$defs/Cost.ModelCatalogSource" && !("kind" in catalogSource.properties) && "source_id" in catalogSource.properties && catalogSource.required?.includes("priority") && "price_semantics" in catalogSource.properties && "last_verified_at" in catalogSource.properties && "active_snapshot_id" in catalogSource.properties && "model_count" in catalogSource.properties;\n` +
        `const catalogEstimate = schema.$defs["Cost.GenAiEtlCatalogTokenCostEstimate"];\n` +
        `const expectedEstimateRefs = ["GenAiEtlCatalogTokenCalculatedEstimate", "GenAiEtlCatalogTokenSourceUnavailableEstimate", "GenAiEtlCatalogTokenStaleSourceEstimate", "GenAiEtlCatalogTokenMissingModelIdentityEstimate", "GenAiEtlCatalogTokenModelNotFoundEstimate", "GenAiEtlCatalogTokenAmbiguousModelEstimate", "GenAiEtlCatalogTokenIncompleteUsageEstimate", "GenAiEtlCatalogTokenConditionalPricingUnresolvableEstimate", "GenAiEtlCatalogTokenUnsupportedPricingEstimate"].map((name) => "#/$defs/Cost." + name);\n` +
        `const estimateRefs = (catalogEstimate?.oneOf ?? []).map((variant) => variant.$ref);\n` +
        `const calculatedEstimate = schema.$defs["Cost.GenAiEtlCatalogTokenCalculatedEstimate"];\n` +
        `const calculatedRequired = ["status", "estimated_catalog_token_cost_usd", "estimated_catalog_token_cost_per_call_usd", "provenance", "components"];\n` +
        `const expectedComponentRefs = ["ModelCatalogTokenBaseRateComponent", "ModelCatalogTokenAdditiveSurchargeComponent", "ModelCatalogTokenInclusiveReplacementRateComponent", "ModelCatalogTokenConditionalOverrideRateComponent"].map((name) => "#/$defs/Cost." + name);\n` +
        `const componentRefs = (schema.$defs["Cost.ModelCatalogTokenEstimateComponent"]?.oneOf ?? []).map((variant) => variant.$ref);\n` +
        `const expectedExclusionRefs = ["ModelCatalogUsageNotObservedExclusion", "ModelCatalogConditionalAdjustmentNotAppliedExclusion", "ModelCatalogSupersededOverrideExclusion", "ModelCatalogOutsideTokenScopeExclusion", "ModelCatalogUnsupportedUsageExclusion", "ModelCatalogUnsupportedBillingExclusion"].map((name) => "#/$defs/Cost." + name);\n` +
        `const exclusionRefs = (schema.$defs["Cost.ModelCatalogTokenEstimateExclusion"]?.oneOf ?? []).map((variant) => variant.$ref);\n` +
        `const inclusiveReplacement = schema.$defs["Cost.ModelCatalogTokenInclusiveReplacementRateComponent"];\n` +
        `const conditionalOverride = schema.$defs["Cost.ModelCatalogTokenConditionalOverrideRateComponent"];\n` +
        `const conditionalExclusion = schema.$defs["Cost.ModelCatalogConditionalExclusionBase"];\n` +
        `const expectedRateEvidenceRefs = ["ModelCatalogBaseRateEvidence", "ModelCatalogAdditiveSurchargeEvidence", "ModelCatalogInclusiveReplacementEvidence", "ModelCatalogPublishedReplacementEvidence"].map((name) => "#/$defs/Cost." + name);\n` +
        `const rateEvidenceRefs = (schema.$defs["Cost.ModelCatalogExclusionRateEvidence"]?.oneOf ?? []).map((variant) => variant.$ref);\n` +
        `const inclusiveExclusionEvidence = schema.$defs["Cost.ModelCatalogInclusiveReplacementEvidence"];\n` +
        `const publishedExclusionEvidence = schema.$defs["Cost.ModelCatalogPublishedReplacementEvidence"];\n` +
        `const supportedExclusion = schema.$defs["Cost.ModelCatalogSupportedBillingExclusionBase"];\n` +
        `const optionallyNormalizedExclusion = schema.$defs["Cost.ModelCatalogOptionallyNormalizedBillingExclusionBase"];\n` +
        `const unsupportedBillingExclusion = schema.$defs["Cost.ModelCatalogUnsupportedBillingExclusion"];\n` +
        `const sourceOrder = schema.$defs["Cost.ModelCatalogSourceOrder"];\n` +
        `const provenance = schema.$defs["Cost.ModelCatalogPriceProvenance"];\n` +
        `const matchKinds = ["exact_model_id", "exact_canonical_slug"];\n` +
        `const removedClusterEconomics = ["observed_cost_usd", "cost_per_call_usd", "cost_attribution", "spend_share"].every((property) => !(property in auditCluster.properties));\n` +
        `const failureVariantsSealed = expectedEstimateRefs.slice(1).every((reference) => "unevaluatedProperties" in schema.$defs[reference.split("Cost.")[1].replace(/^/, "Cost.")]);\n` +
        `const replacementEvidenceShape = inclusiveReplacement?.required?.includes("replaces_usage_dimension") && !inclusiveReplacement.required.includes("conditional_evidence") && conditionalOverride?.required?.includes("replaces_usage_dimension") && conditionalOverride.required.includes("conditional_evidence") && conditionalOverride.properties?.rate_relation?.enum?.[0] === "replaces_published_rate" && JSON.stringify(rateEvidenceRefs) === JSON.stringify(expectedRateEvidenceRefs) && inclusiveExclusionEvidence?.required?.includes("replaces_usage_dimension") && !inclusiveExclusionEvidence.required.includes("conditional_evidence") && publishedExclusionEvidence?.required?.includes("replaces_usage_dimension") && publishedExclusionEvidence.required.includes("conditional_evidence") && conditionalExclusion?.required?.includes("rate_evidence") && conditionalExclusion.properties?.rate_evidence?.allOf?.[0]?.$ref === "#/$defs/Cost.ModelCatalogPublishedReplacementEvidence" && supportedExclusion?.required?.includes("billing_mode") && !optionallyNormalizedExclusion?.required?.includes("billing_mode") && !conditionalExclusion.required.includes("billing_mode") && !unsupportedBillingExclusion?.required?.includes("billing_mode") && sourceOrder?.minimum === 1 && failureVariantsSealed;\n` +
        `const provenanceShape = ["source_id", "source_endpoint", "snapshot_id", "price_model_id", "observed_model_id", "observed_model_identity_basis", "model_match_kind", "retrieved_at", "price_semantics"].every((property) => provenance?.required?.includes(property));\n` +
        `const separatedCatalogEstimate = auditCluster?.required?.includes("catalog_token_estimate") && auditCluster.properties?.catalog_token_estimate?.allOf?.[0]?.$ref === "#/$defs/Cost.GenAiEtlCatalogTokenCostEstimate" && removedClusterEconomics && JSON.stringify(estimateRefs) === JSON.stringify(expectedEstimateRefs) && calculatedRequired.every((property) => calculatedEstimate?.required?.includes(property)) && calculatedEstimate.properties?.components?.minItems === 1 && calculatedEstimate.properties.components.items?.$ref === "#/$defs/Cost.ModelCatalogTokenEstimateComponent" && calculatedEstimate.properties?.exclusions?.minItems === 1 && calculatedEstimate.properties.exclusions.items?.$ref === "#/$defs/Cost.ModelCatalogTokenEstimateExclusion" && calculatedEstimate.properties?.provenance?.allOf?.[0]?.$ref === "#/$defs/Cost.ModelCatalogPriceProvenance" && JSON.stringify(componentRefs) === JSON.stringify(expectedComponentRefs) && JSON.stringify(exclusionRefs) === JSON.stringify(expectedExclusionRefs) && replacementEvidenceShape && provenanceShape && JSON.stringify(Object.values(ModelCatalogMatchKindValues)) === JSON.stringify(matchKinds) && ModelCatalogObservedIdentityBasisValues.responseModel === "response_model" && ModelCatalogObservedIdentityBasisValues.requestModelFallback === "request_model_fallback" && ModelCatalogBillingModeValues.perUnit === "per_unit" && ModelCatalogRateRelationValues.replacesInclusiveBaseRate === "replaces_inclusive_base_rate" && ModelCatalogRateRelationValues.replacesPublishedRate === "replaces_published_rate" && ModelCatalogTokenExclusionReasonValues.usageNotObserved === "usage_not_observed" && ModelCatalogTokenExclusionReasonValues.supersededByLaterOverride === "superseded_by_later_override" && ModelCatalogPriceSemanticsValues.minimumAvailableRate === "minimum_available_rate" && GenAiEtlEvidenceSignalValues.catalogTokenEstimate === "catalog_token_estimate" && !Object.values(GenAiEtlEvidenceSignalValues).includes("provider_cost");\n` +
        `const auditSummary = schema.$defs["Cost.GenAiEtlAuditSummary"];\n` +
        `const catalogSummaryMetrics = auditSummary?.required?.includes("catalog_token_priced_call_coverage") && ["estimated_catalog_token_cost_usd", "estimated_token_economic_concentration", "candidate_etl_estimated_token_spend_share"].every((property) => property in (auditSummary.properties ?? {})) && ["estimated_catalog_cost_usd", "catalog_priced_call_coverage", "attributed_cost_usd", "priced_call_coverage", "economic_concentration", "candidate_etl_spend_share"].every((property) => !(property in (auditSummary.properties ?? {})));\n` +
        `const frontierBasis = schema.$defs["Cost.GenAiEtlFrontierCostBasis"];\n` +
        `const frontierBasisValues = ["scenario", "catalog_token_estimate", "unavailable"];\n` +
        `const evaluation = schema.$defs["Cost.GenAiEtlClusterEvaluation"];\n` +
        `const expectedEvaluationRefs = ["GenAiEtlScenarioClusterEvaluation", "GenAiEtlCatalogTokenClusterEvaluation", "GenAiEtlUnavailableClusterEvaluation"].map((name) => "#/$defs/Cost." + name);\n` +
        `const evaluationRefs = (evaluation?.oneOf ?? []).map((variant) => variant.$ref);\n` +
        `const catalogEvaluation = schema.$defs["Cost.GenAiEtlCatalogTokenClusterEvaluation"];\n` +
        `const calculatedEvaluation = schema.$defs["Cost.GenAiEtlCalculatedClusterEvaluationBase"];\n` +
        `const separatedFrontierBasis = JSON.stringify(frontierBasis?.enum) === JSON.stringify(frontierBasisValues) && JSON.stringify(Object.values(GenAiEtlFrontierCostBasisValues)) === JSON.stringify(frontierBasisValues) && JSON.stringify(evaluationRefs) === JSON.stringify(expectedEvaluationRefs) && catalogEvaluation?.required?.includes("catalog_provenance") && ["frontier_cost_per_call_usd", "current_period_cost_usd", "gross_replaceable_value_usd", "net_replaceable_value_usd"].every((property) => calculatedEvaluation?.required?.includes(property));\n` +
        `const tool = schema.$defs["Runner.Mcp.RunnerMcpTool"]?.properties;\n` +
        `const request = schema.$defs["Runner.Mcp.RunnerMcpToolCallRequest"]?.properties;\n` +
        `const response = schema.$defs["Runner.Mcp.RunnerMcpToolCallResponse"]?.properties;\n` +
        `const operations = Object.values(openapi.paths).flatMap((path) => Object.values(path));\n` +
        `const errorResponses = operations.flatMap((operation) => Object.values(operation.responses ?? {})).filter((response) => Object.values(response.content ?? {}).some((media) => media.schema?.$ref?.startsWith("#/components/schemas/Common.Errors.")));\n` +
        `const errorsOwnProblemJson = errorResponses.length > 0 && errorResponses.every((response) => Object.keys(response.content ?? {}).length === 1 && response.content[ProblemDetailsMediaType]);\n` +
        `const runnerOperations = Object.entries(openapi.paths).flatMap(([path, pathItem]) => Object.entries(pathItem).map(([method, operation]) => ({ path, method, operation }))).filter(({ operation }) => operation.tags?.some((tag) => tag === "Runner resources" || tag === "Runner MCP"));\n` +
        `const runnerSecurityResponsesDeclared = runnerOperations.length === 9 && runnerOperations.every(({ operation }) => { const response = operation.responses?.["403"]; const content = response?.content ?? {}; return Object.keys(content).length === 1 && content[ProblemDetailsMediaType]?.schema?.$ref === "#/components/schemas/Common.Errors.ForbiddenError"; });\n` +
        `const runnerCapacityResponsesDeclared = runnerOperations.length === 9 && runnerOperations.every(({ operation }) => { const response = operation.responses?.["503"]; const content = response?.content ?? {}; return Object.keys(content).length === 1 && content[ProblemDetailsMediaType]?.schema?.$ref === "#/components/schemas/Common.Errors.ServiceUnavailableError"; });\n` +
        `const logStreamCapacityResponseDeclared = (() => { const content = openapi.paths["/api/v1/stream/logs"]?.get?.responses?.["503"]?.content ?? {}; return Object.keys(content).length === 1 && content[ProblemDetailsMediaType]?.schema?.$ref === "#/components/schemas/Common.Errors.ServiceUnavailableError"; })();\n` +
        `const typedQueryPaths = ["/api/v1/traces", "/api/v1/logs", "/api/v1/profiles", "/api/v1/profiles/by-trace/{traceId}", "/api/v1/profiles/by-span/{spanId}", "/api/v1/sessions", "/api/v1/sessions/stats", "/api/v1/stream/logs"];\n` +
        `const typedQueryValidationResponsesDeclared = typedQueryPaths.every((path) => { const content = openapi.paths[path]?.get?.responses?.["400"]?.content ?? {}; return Object.keys(content).length === 1 && content[ProblemDetailsMediaType]?.schema?.$ref === "#/components/schemas/Common.Errors.ValidationError"; });\n` +
        `const resourceEvent = openapi.paths["/runner/resources/stream"]?.get?.responses?.["200"]?.content?.["text/event-stream"]?.itemSchema?.oneOf?.[0]?.properties?.event?.const;\n` +
        `const logEvent = openapi.paths["/runner/resources/{resource}/logs/stream"]?.get?.responses?.["200"]?.content?.["text/event-stream"]?.itemSchema?.oneOf?.[0]?.properties?.event?.const;\n` +
        `if (ProblemDetailsMediaType !== "application/problem+json" || !errorsOwnProblemJson || !runnerSecurityResponsesDeclared || !runnerCapacityResponsesDeclared || !logStreamCapacityResponseDeclared || !typedQueryValidationResponsesDeclared || !exactContentUnion || !exactResourceUnion || !recursiveAttributeValue || !compoundValidationMetrics || !qualifiedCandidate || !aggregateBilling || !requiredCatalogSources || !separatedCatalogEstimate || !catalogSummaryMetrics || !separatedFrontierBasis || GenAiEtlValidationMetricValues.calibrationError !== "calibration_error" || GenAiEtlValidationMetricValues.spanPrecision !== "span_precision" || GenAiEtlValidationMetricValues.spanRecall !== "span_recall" || resourceEvent !== "message" || logEvent !== "message" || HealthStatusValues.healthy !== "healthy" || RunnerResourceLifecycleValues.ready !== "ready" || RunnerResourceKindValues.stdio !== "stdio" || RunnerMcpToolTaskSupportValues.required !== "required" || RunnerMcpTaskStatusValues.inputRequired !== "input_required" || !tool?.execution || !tool?.icons || !request?._meta || !request?.task || !response?.task || !schema.$defs["Mcp.Tools.FetchTelemetryInput"]) process.exit(1);\n`,
    );
    run("node", ["smoke.mjs"], npmDir);

    const dotnetDir = join(root, "dotnet");
    const dotnetEnvironment = {
      DOTNET_CLI_HOME: join(root, "dotnet-home"),
      NUGET_PACKAGES: join(root, "nuget-packages"),
      NUGET_HTTP_CACHE_PATH: join(root, "nuget-http-cache"),
    };
    run(
      "dotnet",
      ["new", "console", "--framework", "net10.0", "--no-restore", "--output", dotnetDir],
      root,
      dotnetEnvironment,
    );
    await writeFile(
      join(dotnetDir, "NuGet.Config"),
      `<?xml version="1.0" encoding="utf-8"?><configuration><packageSources><clear/><add key="contracts" value="${escapeXml(nugetSource)}"/>${nugetSource === nugetOrg ? "" : `<add key="nuget.org" value="${nugetOrg}"/>`}</packageSources></configuration>`,
    );
    run(
      "dotnet",
      ["add", "package", nugetPackage, "--version", version, "--no-restore"],
      dotnetDir,
      dotnetEnvironment,
    );
    run(
      "dotnet",
      ["add", "package", mcpSdkPackage, "--version", mcpSdkVersion, "--no-restore"],
      dotnetDir,
      dotnetEnvironment,
    );
    run(
      "dotnet",
      ["restore", "--configfile", "NuGet.Config", "--force", "--no-cache"],
      dotnetDir,
      dotnetEnvironment,
    );
    await writeFile(
      join(dotnetDir, "Program.cs"),
      `using System.Text.Json;\nusing System.Text.Json.Nodes;\nusing System.Text.Json.Serialization;\nusing ModelContextProtocol;\nusing ModelContextProtocol.Protocol;\nusing Qyl.Api.Contracts.Common.Errors;\nusing Qyl.Api.Contracts.Cost;\nusing Qyl.Api.Contracts.Health;\nusing Qyl.Api.Contracts.Mcp.Tools;\nusing Qyl.Api.Contracts.Runner;\nusing Qyl.Api.Contracts.Runner.Mcp;\n#pragma warning disable MCPEXP001\n` +
        `var health = JsonSerializer.Serialize(HealthStatus.Healthy);\n` +
        `var lifecycle = JsonSerializer.Serialize(RunnerResourceLifecycle.Ready);\n` +
        `var kind = JsonSerializer.Serialize(RunnerResourceKind.Stdio);\n` +
        `var binary = new byte[] { 0, 1, 2, 255 };\n` +
        `var icon = new RunnerMcpIcon { Src = "data:image/png;base64,AA==", MimeType = "image/png", Sizes = ["16x16"], Theme = "dark" };\n` +
        `var request = new RunnerMcpToolCallRequest { Name = "smoke", Arguments = new Dictionary<string, object> { ["trace_id"] = "abc" }, Task = new RunnerMcpTaskMetadata { Ttl = 1500 }, Metadata = new Dictionary<string, object> { ["progressToken"] = 7L } };\n` +
        `var resource = new RunnerMcpResourceReadRequest { Uri = new Uri("ui://app/index.html"), Metadata = new Dictionary<string, object> { ["progressToken"] = "progress-1" } };\n` +
        `var state = new RunnerResourceState { Name = "demo", Lifecycle = RunnerResourceLifecycle.Ready, Timestamp = DateTimeOffset.UnixEpoch, Kind = RunnerResourceKind.Stdio };\n` +
        `var tool = new RunnerMcpTool { Name = "inspect", InputSchema = new Dictionary<string, object> { ["type"] = "object" }, Execution = new RunnerMcpToolExecution { TaskSupport = RunnerMcpToolTaskSupport.Required }, Icons = [icon], Annotations = new Dictionary<string, object> { ["readOnlyHint"] = true }, Metadata = new Dictionary<string, object> { ["ui/resourceUri"] = "ui://app/index.html" } };\n` +
        `var text = new RunnerMcpTextContent { Text = "ok" };\n` +
        `var image = new RunnerMcpImageContent { Data = binary, MimeType = "image/png" };\n` +
        `var audio = new RunnerMcpAudioContent { Data = binary, MimeType = "audio/wav" };\n` +
        `var textResource = new RunnerMcpTextResourceContent { Uri = new Uri("ui://app/index.html"), Text = "<html></html>", Metadata = new Dictionary<string, object> { ["ui"] = true } };\n` +
        `var blobResource = new RunnerMcpBlobResourceContent { Uri = new Uri("file:///tmp/blob"), MimeType = "application/octet-stream", Blob = binary };\n` +
        `var embedded = new RunnerMcpEmbeddedResourceContent { Resource = textResource };\n` +
        `var resourceLink = new RunnerMcpResourceLinkContent { Uri = new Uri("ui://app/index.html"), Name = "dashboard", Icons = [icon] };\n` +
        `var toolUse = new RunnerMcpToolUseContent { Id = "call-1", Name = "inspect", Input = new Dictionary<string, object> { ["trace_id"] = "abc" }, Annotations = new Dictionary<string, object> { ["priority"] = 0.8 }, Metadata = new Dictionary<string, object> { ["source"] = "smoke" } };\n` +
        `var toolResult = new RunnerMcpToolResultContent { ToolUseId = "call-1", Content = [new RunnerMcpTextContent { Text = "ok" }], StructuredContent = new Dictionary<string, object> { ["ok"] = true }, IsError = false };\n` +
        `var response = new RunnerMcpToolCallResponse { Content = [text, image, audio, embedded, resourceLink, toolUse, toolResult], IsError = false, Task = new RunnerMcpTask { TaskId = "task-1", Status = RunnerMcpTaskStatus.InputRequired, StatusMessage = "waiting", CreatedAt = DateTimeOffset.UnixEpoch, LastUpdatedAt = DateTimeOffset.UnixEpoch.AddSeconds(1), Ttl = 60000, PollInterval = 250 }, Metadata = new Dictionary<string, object> { ["requestId"] = "req-1" } };\n` +
        `var readResponse = new RunnerMcpResourceReadResponse { Contents = [textResource, blobResource], Metadata = new Dictionary<string, object> { ["requestId"] = "req-2" } };\n` +
        `var toolInput = new FetchTelemetryInput { View = FetchTelemetryView.Traces };\n` +
        `var billingSource = new ProviderBillingSource { Provider = "provider", Status = ProviderBillingSourceStatus.Current, SourceEndpoint = "https://provider.example/api/billing", Attribution = ProviderBillingAttribution.ProviderPeriod, ReportedCostUsd = 1.25 };\n` +
        `var catalogSource = new ModelCatalogSource { SourceId = "provider-model-catalog", Priority = 0, Status = ModelCatalogSourceStatus.Current, PriceSemantics = ModelCatalogPriceSemantics.MinimumAvailableRate, SourceEndpoint = "https://provider.example/api/models", LastVerifiedAt = DateTimeOffset.UnixEpoch.AddMinutes(1), RetrievedAt = DateTimeOffset.UnixEpoch, ActiveSnapshotId = "sha256:catalog-snapshot", ModelCount = 42 };\n` +
        `var catalogProvenance = new ModelCatalogPriceProvenance { SourceId = catalogSource.SourceId, SourceEndpoint = catalogSource.SourceEndpoint, SnapshotId = catalogSource.ActiveSnapshotId!, PriceModelId = "provider/model-version", ObservedModelId = "provider/model-version", ObservedModelIdentityBasis = ModelCatalogObservedIdentityBasis.ResponseModel, ModelMatchKind = ModelCatalogMatchKind.ExactModelId, RetrievedAt = catalogSource.RetrievedAt!.Value, PriceSemantics = ModelCatalogPriceSemantics.MinimumAvailableRate };\n` +
        `var replacementEvidence = new ModelCatalogConditionalRateEvidence { SourceOrder = 2, ConditionUsageDimension = "cache_write_input_tokens", ExclusiveMinimumQuantity = 250, ObservedPerCallQuantity = 500 };\n` +
        `var catalogEstimate = new GenAiEtlCatalogTokenCalculatedEstimate { EstimatedCatalogTokenCostUsd = 0.0047, EstimatedCatalogTokenCostPerCallUsd = 0.00235, Provenance = catalogProvenance, Components = [new ModelCatalogTokenInclusiveReplacementRateComponent { Component = "cache_read", UsageDimension = "cache_read_input_tokens", Unit = "token", SourceBillingMode = "per_token", BillingMode = ModelCatalogBillingMode.PerUnit, ReplacesUsageDimension = "input_tokens", Quantity = 1500, UnitPriceUsd = 0.000001, EstimatedCostUsd = 0.0015 }, new ModelCatalogTokenConditionalOverrideRateComponent { Component = "cache_write_override", UsageDimension = "cache_write_input_tokens", Unit = "token", SourceBillingMode = "per_token", BillingMode = ModelCatalogBillingMode.PerUnit, ReplacesUsageDimension = "cache_write_input_tokens", ConditionalEvidence = replacementEvidence, Quantity = 500, UnitPriceUsd = 0.000001, EstimatedCostUsd = 0.0005 }, new ModelCatalogTokenBaseRateComponent { Component = "completion", UsageDimension = "output_tokens", Unit = "token", SourceBillingMode = "per_token", BillingMode = ModelCatalogBillingMode.PerUnit, Quantity = 500, UnitPriceUsd = 0.000002, EstimatedCostUsd = 0.001 }, new ModelCatalogTokenBaseRateComponent { Component = "request", UsageDimension = "call_count", Unit = "request", SourceBillingMode = "per_request", BillingMode = ModelCatalogBillingMode.PerRequest, Quantity = 2, UnitPriceUsd = 0.00085, EstimatedCostUsd = 0.0017 }], Exclusions = [new ModelCatalogUsageNotObservedExclusion { Component = "internal_reasoning", UsageDimension = "reasoning_output_tokens", Unit = "token", SourceBillingMode = "per_token", BillingMode = ModelCatalogBillingMode.PerUnit, RateEvidence = new ModelCatalogInclusiveReplacementEvidence { ReplacesUsageDimension = "output_tokens" }, UnitPriceUsd = 0.0000001 }, new ModelCatalogSupersededOverrideExclusion { Component = "cache_write_override", UsageDimension = "cache_write_input_tokens", Unit = "token", SourceBillingMode = "per_token", BillingMode = ModelCatalogBillingMode.PerUnit, RateEvidence = new ModelCatalogPublishedReplacementEvidence { ReplacesUsageDimension = "cache_write_input_tokens", ConditionalEvidence = new ModelCatalogConditionalRateEvidence { SourceOrder = 1, ConditionUsageDimension = "cache_write_input_tokens", ExclusiveMinimumQuantity = 100, ObservedPerCallQuantity = 500 } }, UnitPriceUsd = 0.00000075 }, new ModelCatalogOutsideTokenScopeExclusion { Component = "audio", UsageDimension = "audio_duration", Unit = "second", SourceBillingMode = "per_audio_second", RateEvidence = new ModelCatalogBaseRateEvidence(), UnitPriceUsd = 0.001 }, new ModelCatalogConditionalAdjustmentNotAppliedExclusion { Component = "input_audio_cache", UsageDimension = "input_audio_cache", Unit = "audio", SourceBillingMode = "per_audio_unit", RateEvidence = new ModelCatalogPublishedReplacementEvidence { ReplacesUsageDimension = "input_audio_cache", ConditionalEvidence = new ModelCatalogConditionalRateEvidence { SourceOrder = 3, ConditionUsageDimension = "input_audio_cache", ExclusiveMinimumQuantity = 0, ObservedPerCallQuantity = 1 } }, UnitPriceUsd = 0.002 }] };\n` +
        `var auditCluster = new GenAiEtlAuditCluster { ClusterId = "cluster-1", WorkflowKey = "workflow-1", ServiceName = "orders", Provider = "provider", ModelName = "model-version", OutputContract = GenAiEtlOutputContract.Record, TaskFamily = GenAiEtlTaskFamily.StructuredExtraction, CallCount = 2, InputTokens = 3000, OutputTokens = 500, CacheReadInputTokens = 1500, CacheCreationInputTokens = 500, ReasoningOutputTokens = 0, ErrorCount = 0, ErrorRate = 0, AverageLatencyMs = 25, P95LatencyMs = 40, CatalogTokenEstimate = catalogEstimate, CandidateStatus = GenAiEtlCandidateStatus.HypothesisOnly, CandidatePath = GenAiEtlCandidatePath.SmallerGenerativeModel, ValidationMetrics = [GenAiEtlValidationMetric.FieldExactMatch, GenAiEtlValidationMetric.SchemaValidity], ResidualPath = GenAiEtlResidualPath.FrontierModel, EvidenceSignals = [GenAiEtlEvidenceSignal.ProviderModel, GenAiEtlEvidenceSignal.TokenUsage, GenAiEtlEvidenceSignal.CatalogTokenEstimate], MissingEvidence = [], PromotionGates = [] };\n` +
        `var auditSummary = new GenAiEtlAuditSummary { TotalCalls = 2, TotalInputTokens = 3000, TotalOutputTokens = 500, EstimatedCatalogTokenCostUsd = 0.0047, CatalogTokenPricedCallCoverage = 1, EstimatedTokenEconomicConcentration = 1, CandidateEtlEstimatedTokenSpendShare = 0.6 };\n` +
        `var auditReport = new GenAiEtlAuditReport { GeneratedAt = DateTimeOffset.UnixEpoch, PeriodStart = DateTimeOffset.UnixEpoch, PeriodEnd = DateTimeOffset.UnixEpoch.AddDays(1), Summary = auditSummary, BillingSources = [billingSource], CatalogSources = [catalogSource], Clusters = [auditCluster] };\n` +
        `var evaluation = new GenAiEtlCatalogTokenClusterEvaluation { ClusterId = auditCluster.ClusterId, Status = "calculated", CallCount = auditCluster.CallCount, Coverage = 1, ServedCallCount = 2, ResidualCallCount = 0, FrontierCostPerCallUsd = catalogEstimate.EstimatedCatalogTokenCostPerCallUsd, CatalogProvenance = catalogProvenance, AlternativeCostPerCallUsd = 0.001, CurrentPeriodCostUsd = 0.0047, GrossReplaceableValueUsd = 0.0027, PeriodMaintenanceCostUsd = 0, PeriodErrorCostUsd = 0, NetReplaceableValueUsd = 0.0027 };\n` +
        `var evaluationWire = JsonSerializer.Serialize<GenAiEtlClusterEvaluation>(evaluation);\n` +
        `var evaluationRoundTrip = JsonSerializer.Deserialize<GenAiEtlClusterEvaluation>(evaluationWire);\n` +
        `var catalogWire = string.Join("\\n", JsonSerializer.Serialize(auditReport), evaluationWire);\n` +
        `var wire = string.Join("\\n", JsonSerializer.Serialize(tool), JsonSerializer.Serialize(request), JsonSerializer.Serialize(response), JsonSerializer.Serialize(resource), JsonSerializer.Serialize(readResponse));\n` +
        `var ambiguousResourceRejected = false;\n` +
        `try { JsonSerializer.Deserialize<RunnerMcpResourceContent>("{\\\"uri\\\":\\\"file:///tmp/both\\\",\\\"text\\\":\\\"x\\\",\\\"blob\\\":\\\"AAE=\\\"}"); } catch (JsonException) { ambiguousResourceRejected = true; }\n` +
        `var sdkIcon = new Icon { Source = icon.Src, MimeType = icon.MimeType, Sizes = ["16x16"], Theme = icon.Theme };\n` +
        `var sdkTool = new Tool { Name = "inspect", InputSchema = JsonSerializer.Deserialize<JsonElement>("{\\\"type\\\":\\\"object\\\"}"), Execution = new ToolExecution { TaskSupport = ToolTaskSupport.Required }, Icons = [sdkIcon], Annotations = new ToolAnnotations { ReadOnlyHint = true }, Meta = new JsonObject { ["ui/resourceUri"] = "ui://app/index.html" } };\n` +
        `var sdkRequest = new CallToolRequestParams { Name = "inspect", Arguments = new Dictionary<string, JsonElement> { ["trace_id"] = JsonSerializer.Deserialize<JsonElement>("\\\"abc\\\"") }, Task = new McpTaskMetadata { TimeToLive = TimeSpan.FromMilliseconds(1500) }, Meta = new JsonObject { ["progressToken"] = 7L } };\n` +
        `var sdkText = new TextContentBlock { Text = "ok" };\n` +
        `var sdkImage = ImageContentBlock.FromBytes(binary, "image/png");\n` +
        `var sdkAudio = AudioContentBlock.FromBytes(binary, "audio/wav");\n` +
        `var sdkToolUse = new ToolUseContentBlock { Id = "call-1", Name = "inspect", Input = JsonSerializer.Deserialize<JsonElement>("{\\\"trace_id\\\":\\\"abc\\\"}"), Annotations = new Annotations { Priority = 0.8F }, Meta = new JsonObject { ["source"] = "smoke" } };\n` +
        `var sdkToolResult = new ToolResultContentBlock { ToolUseId = "call-1", Content = [new TextContentBlock { Text = "ok" }], StructuredContent = JsonSerializer.Deserialize<JsonElement>("{\\\"ok\\\":true}"), IsError = false };\n` +
        `var sdkResourceLink = new ResourceLinkBlock { Uri = "ui://app/index.html", Name = "dashboard", Icons = [sdkIcon] };\n` +
        `var sdkEmbedded = new EmbeddedResourceBlock { Resource = new TextResourceContents { Uri = "ui://app/index.html", Text = "<html></html>", Meta = new JsonObject { ["ui"] = true } } };\n` +
        `var sdkResponse = new CallToolResult { Content = [sdkText, sdkImage, sdkAudio, sdkEmbedded, sdkResourceLink, sdkToolUse, sdkToolResult], IsError = false, Task = new McpTask { TaskId = "task-1", Status = McpTaskStatus.InputRequired, StatusMessage = "waiting", CreatedAt = DateTimeOffset.UnixEpoch, LastUpdatedAt = DateTimeOffset.UnixEpoch.AddSeconds(1), TimeToLive = TimeSpan.FromMilliseconds(60000), PollInterval = TimeSpan.FromMilliseconds(250) }, Meta = new JsonObject { ["requestId"] = "req-1" } };\n` +
        `var sdkReadRequest = new ReadResourceRequestParams { Uri = "ui://app/index.html", Meta = new JsonObject { ["progressToken"] = "progress-1" } };\n` +
        `var sdkReadResponse = new ReadResourceResult { Contents = [new TextResourceContents { Uri = "ui://app/index.html", Text = "<html></html>", Meta = new JsonObject { ["ui"] = true } }, BlobResourceContents.FromBytes(binary, "file:///tmp/blob", "application/octet-stream")], Meta = new JsonObject { ["requestId"] = "req-2" } };\n` +
        `var projectedTool = JsonSerializer.Deserialize<RunnerMcpTool>(JsonSerializer.Serialize(sdkTool, McpJsonUtilities.DefaultOptions));\n` +
        `var projectedRequest = JsonSerializer.Deserialize<RunnerMcpToolCallRequest>(JsonSerializer.Serialize(sdkRequest, McpJsonUtilities.DefaultOptions));\n` +
        `var projectedResponse = JsonSerializer.Deserialize<RunnerMcpToolCallResponse>(JsonSerializer.Serialize(sdkResponse, McpJsonUtilities.DefaultOptions));\n` +
        `var projectedReadRequest = JsonSerializer.Deserialize<RunnerMcpResourceReadRequest>(JsonSerializer.Serialize(sdkReadRequest, McpJsonUtilities.DefaultOptions));\n` +
        `var projectedReadResponse = JsonSerializer.Deserialize<RunnerMcpResourceReadResponse>(JsonSerializer.Serialize(sdkReadResponse, McpJsonUtilities.DefaultOptions));\n` +
        `var validationMetricsProperty = typeof(GenAiEtlAuditCluster).GetProperty("ValidationMetrics");\n` +
        `var validationMetricsWireName = validationMetricsProperty?.GetCustomAttributes(typeof(JsonPropertyNameAttribute), false).OfType<JsonPropertyNameAttribute>().SingleOrDefault()?.Name;\n` +
        `var validationMetricsWire = JsonSerializer.Serialize(new[] { GenAiEtlValidationMetric.CalibrationError, GenAiEtlValidationMetric.SpanPrecision, GenAiEtlValidationMetric.SpanRecall });\n` +
        `var costAssembly = typeof(GenAiEtlAuditReport).Assembly;\n` +
        `var removedCostTypes = new[] { "ProviderCostSourceKind", "ProviderCostSourceStatus", "ProviderCostAttribution", "ProviderCostSource", "ModelCatalogSourceKind", "GenAiEtlCalculationStatus" };\n` +
        `var removedCostTypesAbsent = removedCostTypes.All(name => costAssembly.GetType("Qyl.Api.Contracts.Cost." + name) is null);\n` +
        `var clusterLegacyEconomicsAbsent = new[] { "ObservedCostUsd", "CostPerCallUsd", "CostAttribution", "SpendShare", "CatalogEstimate" }.All(name => typeof(GenAiEtlAuditCluster).GetProperty(name) is null);\n` +
        `var summaryLegacyEconomicsAbsent = new[] { "AttributedCostUsd", "PricedCallCoverage", "EconomicConcentration", "CandidateEtlSpendShare", "EstimatedCatalogCostUsd", "CatalogPricedCallCoverage" }.All(name => typeof(GenAiEtlAuditSummary).GetProperty(name) is null);\n` +
        `var billingStatusWire = JsonSerializer.Serialize(Enum.GetValues<ProviderBillingSourceStatus>());\n` +
        `var billingAttributionWire = JsonSerializer.Serialize(Enum.GetValues<ProviderBillingAttribution>());\n` +
        `var matchKindWire = JsonSerializer.Serialize(Enum.GetValues<ModelCatalogMatchKind>());\n` +
        `var identityBasisWire = JsonSerializer.Serialize(Enum.GetValues<ModelCatalogObservedIdentityBasis>());\n` +
        `var rateRelationWire = JsonSerializer.Serialize(Enum.GetValues<ModelCatalogRateRelation>());\n` +
        `var exclusionReasonWire = JsonSerializer.Serialize(Enum.GetValues<ModelCatalogTokenExclusionReason>());\n` +
        `var evidenceSignalWire = JsonSerializer.Serialize(Enum.GetValues<GenAiEtlEvidenceSignal>());\n` +
        `var frontierBasisWire = JsonSerializer.Serialize(Enum.GetValues<GenAiEtlFrontierCostBasis>());\n` +
        `var candidateStatusWire = JsonSerializer.Serialize(Enum.GetValues<GenAiEtlCandidateStatus>());\n` +
        `var calculatedEstimateWire = JsonSerializer.Serialize<GenAiEtlCatalogTokenCostEstimate>(catalogEstimate);\n` +
        `var calculatedEstimateRoundTrip = JsonSerializer.Deserialize<GenAiEtlCatalogTokenCostEstimate>(calculatedEstimateWire);\n` +
        `GenAiEtlCatalogTokenCostEstimate failedEstimate = new GenAiEtlCatalogTokenModelNotFoundEstimate();\n` +
        `var failedEstimateWire = JsonSerializer.Serialize(failedEstimate);\n` +
        `var failedEstimateRoundTrip = JsonSerializer.Deserialize<GenAiEtlCatalogTokenCostEstimate>(failedEstimateWire);\n` +
        `GenAiEtlCatalogTokenCostEstimate unsupportedEstimate = new GenAiEtlCatalogTokenUnsupportedPricingEstimate { Exclusions = [new ModelCatalogUnsupportedBillingExclusion { Component = "audio", UsageDimension = "audio_duration", Unit = "second", SourceBillingMode = "per_audio_second", RateEvidence = new ModelCatalogBaseRateEvidence(), UnitPriceUsd = 0.0001 }] };\n` +
        `var unsupportedEstimateWire = JsonSerializer.Serialize(unsupportedEstimate);\n` +
        `var unsupportedEstimateRoundTrip = JsonSerializer.Deserialize<GenAiEtlCatalogTokenCostEstimate>(unsupportedEstimateWire);\n` +
        `var catalogUnionTypesValid = typeof(GenAiEtlCatalogTokenCostEstimate).IsInterface && typeof(ModelCatalogTokenEstimateComponent).IsInterface && typeof(ModelCatalogExclusionRateEvidence).IsInterface && typeof(ModelCatalogTokenEstimateExclusion).IsInterface && calculatedEstimateRoundTrip is GenAiEtlCatalogTokenCalculatedEstimate calculatedRoundTrip && calculatedRoundTrip.Exclusions?[0] is ModelCatalogUsageNotObservedExclusion { RateEvidence: ModelCatalogInclusiveReplacementEvidence } && calculatedRoundTrip.Exclusions?[2] is ModelCatalogOutsideTokenScopeExclusion { BillingMode: null } && calculatedRoundTrip.Exclusions?[3] is ModelCatalogConditionalAdjustmentNotAppliedExclusion { BillingMode: null } && failedEstimateRoundTrip is GenAiEtlCatalogTokenModelNotFoundEstimate && unsupportedEstimateRoundTrip is GenAiEtlCatalogTokenUnsupportedPricingEstimate unsupportedRoundTrip && unsupportedRoundTrip.Exclusions?[0] is ModelCatalogUnsupportedBillingExclusion { BillingMode: null, RateEvidence: ModelCatalogBaseRateEvidence } && typeof(GenAiEtlCatalogTokenCalculatedEstimate).GetProperty("Status") is null && typeof(GenAiEtlCatalogTokenCalculatedEstimate).GetProperty("Components")?.PropertyType == typeof(IReadOnlyList<ModelCatalogTokenEstimateComponent>) && typeof(ModelCatalogTokenConditionalOverrideRateComponent).GetProperty("ConditionalEvidence")?.PropertyType == typeof(ModelCatalogConditionalRateEvidence) && typeof(ModelCatalogOutsideTokenScopeExclusion).GetProperty("RateEvidence")?.PropertyType == typeof(ModelCatalogExclusionRateEvidence) && typeof(ModelCatalogPublishedReplacementEvidence).GetProperty("ConditionalEvidence")?.PropertyType == typeof(ModelCatalogConditionalRateEvidence) && typeof(ModelCatalogOutsideTokenScopeExclusion).GetProperty("BillingMode")?.PropertyType == typeof(ModelCatalogBillingMode?) && typeof(ModelCatalogConditionalAdjustmentNotAppliedExclusion).GetProperty("BillingMode")?.PropertyType == typeof(ModelCatalogBillingMode?) && typeof(ModelCatalogUnsupportedBillingExclusion).GetProperty("BillingMode")?.PropertyType == typeof(ModelCatalogBillingMode?) && typeof(ModelCatalogUsageNotObservedExclusion).GetProperty("BillingMode")?.PropertyType == typeof(ModelCatalogBillingMode) && typeof(ModelCatalogPriceProvenance).GetProperty("ObservedModelId")?.PropertyType == typeof(string) && typeof(ModelCatalogPriceProvenance).GetProperty("ObservedModelIdentityBasis")?.PropertyType == typeof(ModelCatalogObservedIdentityBasis);\n` +
        `var catalogSourceTypesValid = removedCostTypesAbsent && typeof(ProviderBillingSource).GetProperty("Kind") is null && typeof(ModelCatalogSource).GetProperty("Kind") is null && typeof(ModelCatalogSource).GetProperty("SourceId")?.PropertyType == typeof(string) && typeof(ModelCatalogSource).GetProperty("Priority")?.PropertyType == typeof(long) && typeof(ModelCatalogSource).GetProperty("LastVerifiedAt")?.PropertyType == typeof(DateTimeOffset?) && typeof(ModelCatalogSource).GetProperty("ActiveSnapshotId")?.PropertyType == typeof(string) && typeof(ModelCatalogSource).GetProperty("ModelCount")?.PropertyType == typeof(long?) && typeof(GenAiEtlAuditReport).GetProperty("BillingSources")?.PropertyType == typeof(IReadOnlyList<ProviderBillingSource>) && typeof(GenAiEtlAuditReport).GetProperty("CatalogSources")?.PropertyType == typeof(IReadOnlyList<ModelCatalogSource>) && typeof(GenAiEtlAuditReport).GetProperty("CostSources") is null;\n` +
        `var catalogEconomicsTypesValid = typeof(GenAiEtlAuditCluster).GetProperty("CatalogTokenEstimate")?.PropertyType == typeof(GenAiEtlCatalogTokenCostEstimate) && typeof(GenAiEtlAuditCluster).GetProperty("CandidateStatus")?.PropertyType == typeof(GenAiEtlCandidateStatus) && clusterLegacyEconomicsAbsent && summaryLegacyEconomicsAbsent && typeof(GenAiEtlAuditSummary).GetProperty("CatalogTokenPricedCallCoverage")?.PropertyType == typeof(double) && typeof(GenAiEtlAuditSummary).GetProperty("EstimatedTokenEconomicConcentration")?.PropertyType == typeof(double?) && typeof(GenAiEtlAuditSummary).GetProperty("CandidateEtlEstimatedTokenSpendShare")?.PropertyType == typeof(double?) && typeof(GenAiEtlClusterEvaluation).IsInterface && evaluationRoundTrip is GenAiEtlCatalogTokenClusterEvaluation && typeof(GenAiEtlCatalogTokenClusterEvaluation).GetProperty("CatalogProvenance")?.PropertyType == typeof(ModelCatalogPriceProvenance) && typeof(GenAiEtlCatalogTokenClusterEvaluation).GetProperty("NetReplaceableValueUsd")?.PropertyType == typeof(double) && typeof(GenAiEtlUnavailableClusterEvaluation).GetProperty("FrontierCostPerCallUsd") is null;\n` +
        `var catalogEnumWireValid = billingStatusWire == "[\\"unconfigured\\",\\"pending\\",\\"current\\",\\"stale\\",\\"sync_failed\\"]" && billingAttributionWire == "[\\"provider_model_period\\",\\"provider_period\\",\\"unavailable\\"]" && matchKindWire == "[\\"exact_model_id\\",\\"exact_canonical_slug\\"]" && identityBasisWire == "[\\"response_model\\",\\"request_model_fallback\\"]" && rateRelationWire == "[\\"base_rate\\",\\"additive_surcharge\\",\\"replaces_inclusive_base_rate\\",\\"replaces_published_rate\\"]" && exclusionReasonWire == "[\\"usage_not_observed\\",\\"conditional_adjustment_not_applied\\",\\"superseded_by_later_override\\",\\"outside_token_estimate_scope\\",\\"unsupported_usage_dimension\\",\\"unsupported_billing_mode\\"]" && evidenceSignalWire.Contains("\\"catalog_token_estimate\\"") && !evidenceSignalWire.Contains("\\"provider_cost\\"") && frontierBasisWire == "[\\"scenario\\",\\"catalog_token_estimate\\",\\"unavailable\\"]";\n` +
        `var catalogWireValid = catalogWire.Contains("\\"billing_sources\\"") && catalogWire.Contains("\\"catalog_sources\\"") && catalogWire.Contains("\\"priority\\":0") && catalogWire.Contains("\\"active_snapshot_id\\":\\"sha256:catalog-snapshot\\"") && catalogWire.Contains("\\"catalog_token_estimate\\":{\\"status\\":\\"calculated\\"") && catalogWire.Contains("\\"estimated_catalog_token_cost_usd\\":0.0047") && catalogWire.Contains("\\"snapshot_id\\":\\"sha256:catalog-snapshot\\"") && catalogWire.Contains("\\"observed_model_id\\":\\"provider/model-version\\"") && catalogWire.Contains("\\"observed_model_identity_basis\\":\\"response_model\\"") && catalogWire.Contains("\\"model_match_kind\\":\\"exact_model_id\\"") && catalogWire.Contains("\\"rate_evidence\\":{") && catalogWire.Contains("\\"rate_relation\\":\\"replaces_inclusive_base_rate\\"") && catalogWire.Contains("\\"rate_relation\\":\\"replaces_published_rate\\"") && catalogWire.Contains("\\"reason\\":\\"superseded_by_later_override\\"") && catalogWire.Contains("\\"reason\\":\\"outside_token_estimate_scope\\"") && catalogWire.Contains("\\"source_order\\":3") && catalogWire.Contains("\\"frontier_cost_basis\\":\\"catalog_token_estimate\\"") && catalogWire.Contains("\\"catalog_provenance\\"") && !catalogWire.Contains("\\"priced_call_count\\"") && failedEstimateWire.Contains("\\"status\\":\\"model_not_found\\"") && unsupportedEstimateWire.Contains("\\"status\\":\\"unsupported_pricing\\"") && unsupportedEstimateWire.Contains("\\"source_billing_mode\\":\\"per_audio_second\\"");\n` +
        `var candidateStatusValid = candidateStatusWire == "[\\\"hypothesis_only\\\",\\\"insufficient_evidence\\\"]";\n` +
        `var candidateWireValid = catalogWire.Contains("\\\"candidate_status\\\":\\\"hypothesis_only\\\"") && catalogWire.Contains("\\\"reason\\\":\\\"conditional_adjustment_not_applied\\\"") && catalogWire.Contains("\\\"source_billing_mode\\\":\\\"per_audio_second\\\"");\n` +
        `var catalogContractValid = catalogUnionTypesValid && catalogSourceTypesValid && catalogEconomicsTypesValid && catalogEnumWireValid && candidateStatusValid && catalogWireValid && candidateWireValid;\n` +
        `if (!catalogContractValid || ProblemDetailsMediaType.Value != "application/problem+json" || typeof(FetchTelemetryInput).Namespace != "Qyl.Api.Contracts.Mcp.Tools" || typeof(GenAiEtlAuditCluster).GetProperty("ValidationMetric") is not null || validationMetricsProperty?.PropertyType != typeof(IReadOnlyList<GenAiEtlValidationMetric>) || validationMetricsWireName != "validation_metrics" || validationMetricsWire != "[\\\"calibration_error\\\",\\\"span_precision\\\",\\\"span_recall\\\"]" || health != "\\\"healthy\\\"" || lifecycle != "\\\"ready\\\"" || kind != "\\\"stdio\\\"" || request.Name != "smoke" || resource.Uri.Scheme != "ui" || state.Kind != RunnerResourceKind.Stdio || tool.Name != "inspect" || toolInput.View != FetchTelemetryView.Traces || response.Task?.PollInterval != 250 || !ambiguousResourceRejected || !wire.Contains("\\\"taskSupport\\\":\\\"required\\\"") || !wire.Contains("\\\"type\\\":\\\"tool_result\\\"") || !wire.Contains("\\\"data\\\":\\\"AAEC/w==\\\"") || !wire.Contains("\\\"progressToken\\\"") || projectedTool?.Execution?.TaskSupport != RunnerMcpToolTaskSupport.Required || projectedTool.Icons?[0].Src != sdkIcon.Source || projectedRequest?.Task?.Ttl != 1500 || !projectedRequest.Metadata!.ContainsKey("progressToken") || projectedResponse?.Content[0] is not RunnerMcpTextContent projectedText || projectedText.Text != "ok" || projectedResponse.Content[1] is not RunnerMcpImageContent projectedImage || !projectedImage.Data.Span.SequenceEqual(binary) || projectedResponse.Content[2] is not RunnerMcpAudioContent projectedAudio || !projectedAudio.Data.Span.SequenceEqual(binary) || projectedResponse.Content[3] is not RunnerMcpEmbeddedResourceContent projectedEmbedded || projectedEmbedded.Resource is not RunnerMcpTextResourceContent projectedEmbeddedText || projectedEmbeddedText.Text != "<html></html>" || projectedResponse.Content[4] is not RunnerMcpResourceLinkContent projectedLink || projectedLink.Icons?[0].Src != sdkIcon.Source || projectedResponse.Content[5] is not RunnerMcpToolUseContent projectedUse || projectedUse.Id != "call-1" || projectedResponse.Content[6] is not RunnerMcpToolResultContent projectedResult || projectedResult.Content[0] is not RunnerMcpTextContent || projectedResponse.Task?.Status != RunnerMcpTaskStatus.InputRequired || projectedResponse.Task.PollInterval != 250 || projectedReadRequest?.Metadata is null || projectedReadResponse?.Contents[0] is not RunnerMcpTextResourceContent projectedReadText || projectedReadText.Metadata is null || projectedReadResponse.Contents[1] is not RunnerMcpBlobResourceContent projectedReadBlob || !projectedReadBlob.Blob.Span.SequenceEqual(binary)) return 1;\nreturn 0;\n`,
    );
    run(
      "dotnet",
      ["run", "--configuration", "Release", "--no-restore"],
      dotnetDir,
      dotnetEnvironment,
    );
  } finally {
    await rm(root, { recursive: true, force: true });
  }
}
