// =============================================================================
// ANcpLua v2.0 - OpenTelemetry SDK Semantic Conventions
// =============================================================================
// OTel SDK configuration and telemetry scope attributes.
// =============================================================================

import "../common/types.tsp";

using Qyl.Api.Contracts.Common;

namespace Qyl.Api.Contracts.Domains.Observe.Otel;

// =============================================================================
// Telemetry SDK Attributes
// =============================================================================

@doc("Telemetry SDK resource attributes")
model TelemetrySdkAttributes {
  @doc("SDK name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Telemetry.SdkName)
  name: string;

  @doc("SDK language")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Telemetry.SdkLanguage)
  language: TelemetrySdkLanguage;

  @doc("SDK version")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Telemetry.SdkVersion)
  version: SemVer;
}

@doc("Telemetry distro attributes")
model TelemetryDistroAttributes {
  @doc("Distro name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Telemetry.DistroName)
  name?: string;

  @doc("Distro version")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Telemetry.DistroVersion)
  version?: SemVer;
}

// =============================================================================
// SDK Language Enumeration
// =============================================================================

@doc("Telemetry SDK languages")
enum TelemetrySdkLanguage {
  @doc("C++")
  cpp: "cpp",

  @doc(".NET")
  dotnet: "dotnet",

  @doc("Erlang")
  erlang: "erlang",

  @doc("Go")
  go: "go",

  @doc("Java")
  java: "java",

  @doc("Node.js")
  nodejs: "nodejs",

  @doc("PHP")
  php: "php",

  @doc("Python")
  python: "python",

  @doc("Ruby")
  ruby: "ruby",

  @doc("Rust")
  rust: "rust",

  @doc("Swift")
  swift: "swift",

  @doc("Kotlin")
  kotlin: "kotlin",

  @doc("Scala")
  scala: "scala",
}

// =============================================================================
// Instrumentation Scope Attributes
// =============================================================================

@doc("Extended instrumentation scope with telemetry details")
model InstrumentationScopeDetails {
  @doc("Scope name (library/module name)")
  name: string;

  @doc("Scope version")
  version?: SemVer;

  @doc("Schema URL")
  @encodedName("application/json", "schema_url")
  schemaUrl?: UrlString;

  @doc("Scope attributes")
  attributes?: Attribute[];

  @doc("Dropped attributes count")
  @encodedName("application/json", "dropped_attributes_count")
  droppedAttributesCount?: int32;
}

// =============================================================================
// OTel Collector Configuration
// =============================================================================

@doc("OTel collector endpoint configuration")
model OtelEndpointConfig {
  @doc("OTLP endpoint URL")
  endpoint: UrlString;

  @doc("Protocol")
  protocol: OtlpProtocol;

  @doc("Headers")
  headers?: Record<string>;

  @doc("Compression")
  compression?: OtlpCompression;

  @doc("Timeout in milliseconds")
  @encodedName("application/json", "timeout_ms")
  timeoutMs?: int32;

  @doc("Retry configuration")
  retry?: RetryConfig;
}

@doc("OTLP protocols")
enum OtlpProtocol {
  @doc("gRPC protocol")
  grpc: "grpc",

  @doc("HTTP/protobuf")
  httpProtobuf: "http/protobuf",

  @doc("HTTP/JSON")
  httpJson: "http/json",
}

@doc("OTLP compression types")
enum OtlpCompression {
  @doc("No compression")
  none: "none",

  @doc("Gzip compression")
  gzip: "gzip",

  @doc("Zstd compression")
  zstd: "zstd",
}

@doc("Retry configuration")
model RetryConfig {
  @doc("Enable retry")
  enabled: boolean;

  @doc("Initial interval in milliseconds")
  @encodedName("application/json", "initial_interval_ms")
  initialIntervalMs?: int32;

  @doc("Max interval in milliseconds")
  @encodedName("application/json", "max_interval_ms")
  maxIntervalMs?: int32;

  @doc("Max elapsed time in milliseconds")
  @encodedName("application/json", "max_elapsed_time_ms")
  maxElapsedTimeMs?: int32;

  @doc("Multiplier for exponential backoff")
  multiplier?: float64;
}

// =============================================================================
// Batch Processor Configuration
// =============================================================================

@doc("Batch processor configuration")
model BatchProcessorConfig {
  @doc("Max queue size")
  @encodedName("application/json", "max_queue_size")
  maxQueueSize?: int32;

  @doc("Scheduled delay in milliseconds")
  @encodedName("application/json", "scheduled_delay_ms")
  scheduledDelayMs?: int32;

  @doc("Export timeout in milliseconds")
  @encodedName("application/json", "export_timeout_ms")
  exportTimeoutMs?: int32;

  @doc("Max export batch size")
  @encodedName("application/json", "max_export_batch_size")
  maxExportBatchSize?: int32;
}

// =============================================================================
// Sampling Configuration
// =============================================================================

@doc("Sampler configuration")
model SamplerConfig {
  @doc("Sampler type")
  type: SamplerType;

  @doc("Sample ratio (for ratio-based samplers)")
  ratio?: Ratio;

  @doc("Parent-based root sampler")
  @encodedName("application/json", "root_sampler")
  rootSampler?: SamplerType;
}

@doc("Sampler types")
enum SamplerType {
  @doc("Always on")
  alwaysOn: "always_on",

  @doc("Always off")
  alwaysOff: "always_off",

  @doc("Trace ID ratio based")
  traceIdRatio: "trace_id_ratio",

  @doc("Parent based")
  parentBased: "parent_based",

  @doc("Jaeger remote")
  jaegerRemote: "jaeger_remote",
}

// =============================================================================
// Resource Detection
// =============================================================================

@doc("Resource detector configuration")
model ResourceDetectorConfig {
  @doc("Enabled detectors")
  detectors: ResourceDetector[];

  @doc("Timeout in milliseconds")
  @encodedName("application/json", "timeout_ms")
  timeoutMs?: int32;
}

@doc("Resource detectors")
enum ResourceDetector {
  @doc("Environment variables")
  env: "env",

  @doc("Host")
  host: "host",

  @doc("OS")
  os: "os",

  @doc("Process")
  process: "process",

  @doc("Container")
  container: "container",

  @doc("Kubernetes")
  k8s: "k8s",

  @doc("AWS EC2")
  awsEc2: "aws_ec2",

  @doc("AWS ECS")
  awsEcs: "aws_ecs",

  @doc("AWS EKS")
  awsEks: "aws_eks",

  @doc("AWS Lambda")
  awsLambda: "aws_lambda",

  @doc("Azure VM")
  azureVm: "azure_vm",

  @doc("Azure App Service")
  azureAppService: "azure_app_service",

  @doc("Azure Functions")
  azureFunctions: "azure_functions",

  @doc("GCP Compute Engine")
  gcpGce: "gcp_gce",

  @doc("GCP Cloud Run")
  gcpCloudRun: "gcp_cloud_run",

  @doc("GCP Cloud Functions")
  gcpCloudFunctions: "gcp_cloud_functions",
}

// =============================================================================
// Propagation Configuration
// =============================================================================

@doc("Context propagation configuration")
model PropagationConfig {
  @doc("Propagators to use")
  propagators: Propagator[];
}

@doc("Context propagators")
enum Propagator {
  @doc("W3C Trace Context")
  tracecontext: "tracecontext",

  @doc("W3C Baggage")
  baggage: "baggage",

  @doc("B3 (single header)")
  b3: "b3",

  @doc("B3 (multi header)")
  b3multi: "b3multi",

  @doc("Jaeger")
  jaeger: "jaeger",

  @doc("X-Ray")
  xray: "xray",

  @doc("OpenTracing")
  ot: "ot",
}

// =============================================================================
// Complete SDK Configuration
// =============================================================================

@doc("Complete OTel SDK configuration")
model OtelSdkConfig {
  @doc("Service name")
  @encodedName("application/json", "service_name")
  serviceName: string;

  @doc("Service version")
  @encodedName("application/json", "service_version")
  serviceVersion?: SemVer;

  @doc("Deployment environment")
  @encodedName("application/json", "deployment_environment")
  deploymentEnvironment?: string;

  @doc("Traces configuration")
  traces?: TracesConfig;

  @doc("Metrics configuration")
  metrics?: MetricsConfig;

  @doc("Logs configuration")
  logs?: LogsConfig;

  @doc("Resource detectors")
  @encodedName("application/json", "resource_detectors")
  resourceDetectors?: ResourceDetectorConfig;

  @doc("Propagation configuration")
  propagation?: PropagationConfig;
}

@doc("Traces pipeline configuration")
model TracesConfig {
  @doc("Enabled")
  enabled: boolean;

  @doc("Exporter endpoint")
  exporter?: OtelEndpointConfig;

  @doc("Batch processor")
  @encodedName("application/json", "batch_processor")
  batchProcessor?: BatchProcessorConfig;

  @doc("Sampler")
  sampler?: SamplerConfig;
}

@doc("Metrics pipeline configuration")
model MetricsConfig {
  @doc("Enabled")
  enabled: boolean;

  @doc("Exporter endpoint")
  exporter?: OtelEndpointConfig;

  @doc("Export interval in milliseconds")
  @encodedName("application/json", "export_interval_ms")
  exportIntervalMs?: int32;
}

@doc("Logs pipeline configuration")
model LogsConfig {
  @doc("Enabled")
  enabled: boolean;

  @doc("Exporter endpoint")
  exporter?: OtelEndpointConfig;

  @doc("Batch processor")
  @encodedName("application/json", "batch_processor")
  batchProcessor?: BatchProcessorConfig;
}

// =============================================================================
// Telemetry Statistics
// =============================================================================

@doc("Telemetry pipeline statistics")
model TelemetryStats {
  @doc("Spans exported")
  @encodedName("application/json", "spans_exported")
  spansExported: Count;

  @doc("Spans dropped")
  @encodedName("application/json", "spans_dropped")
  spansDropped: Count;

  @doc("Metrics exported")
  @encodedName("application/json", "metrics_exported")
  metricsExported: Count;

  @doc("Metrics dropped")
  @encodedName("application/json", "metrics_dropped")
  metricsDropped: Count;

  @doc("Logs exported")
  @encodedName("application/json", "logs_exported")
  logsExported: Count;

  @doc("Logs dropped")
  @encodedName("application/json", "logs_dropped")
  logsDropped: Count;

  @doc("Export errors")
  @encodedName("application/json", "export_errors")
  exportErrors: Count;

  @doc("Queue utilization ratio")
  @encodedName("application/json", "queue_utilization")
  queueUtilization: Ratio;
}
