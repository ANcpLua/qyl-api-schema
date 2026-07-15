// =============================================================================
// OpenTelemetry JSON projection enumerations
// =============================================================================
// All OTel standard enumerations following OTel Semantic Conventions.
// =============================================================================

namespace Qyl.Api.Contracts.OTel.Enums;

// =============================================================================
// Span Enumerations
// =============================================================================

@doc("Span kind describing the relationship between spans")
enum SpanKind {
  @doc("Default. Internal operation within the application")
  unspecified: 0,

  @doc("Internal operation within the application")
  internal: 1,

  @doc("Server-side operation handling a request")
  server: 2,

  @doc("Client-side operation making a request")
  client: 3,

  @doc("Producer creating a message for async processing")
  producer: 4,

  @doc("Consumer processing a message")
  consumer: 5,
}

@doc("Span status code")
enum SpanStatusCode {
  @doc("Status not set")
  unset: 0,

  @doc("Operation completed successfully")
  ok: 1,

  @doc("Operation failed with an error")
  error: 2,
}

@doc("Span flags as defined in W3C Trace Context")
enum SpanFlags {
  @doc("No flags set")
  none: 0x00,

  @doc("Trace is sampled")
  sampled: 0x01,

  @doc("Trace is random (non-deterministic)")
  random: 0x02,
}

// =============================================================================
// Log Enumerations
// =============================================================================

@doc("Log severity number following OTel specification (1-24)")
enum SeverityNumber {
  @doc("Unspecified severity")
  unspecified: 0,

  @doc("TRACE level")
  trace: 1,

  @doc("TRACE2 level")
  trace2: 2,

  @doc("TRACE3 level")
  trace3: 3,

  @doc("TRACE4 level")
  trace4: 4,

  @doc("DEBUG level")
  debug: 5,

  @doc("DEBUG2 level")
  debug2: 6,

  @doc("DEBUG3 level")
  debug3: 7,

  @doc("DEBUG4 level")
  debug4: 8,

  @doc("INFO level")
  info: 9,

  @doc("INFO2 level")
  info2: 10,

  @doc("INFO3 level")
  info3: 11,

  @doc("INFO4 level")
  info4: 12,

  @doc("WARN level")
  warn: 13,

  @doc("WARN2 level")
  warn2: 14,

  @doc("WARN3 level")
  warn3: 15,

  @doc("WARN4 level")
  warn4: 16,

  @doc("ERROR level")
  error: 17,

  @doc("ERROR2 level")
  error2: 18,

  @doc("ERROR3 level")
  error3: 19,

  @doc("ERROR4 level")
  error4: 20,

  @doc("FATAL level")
  fatal: 21,

  @doc("FATAL2 level")
  fatal2: 22,

  @doc("FATAL3 level")
  fatal3: 23,

  @doc("FATAL4 level")
  fatal4: 24,
}

@doc("Log severity text (human-readable)")
enum SeverityText {
  @doc("Trace level logging")
  TRACE: "TRACE",

  @doc("Debug level logging")
  DEBUG: "DEBUG",

  @doc("Informational logging")
  INFO: "INFO",

  @doc("Warning level logging")
  WARN: "WARN",

  @doc("Error level logging")
  ERROR: "ERROR",

  @doc("Fatal/critical level logging")
  FATAL: "FATAL",
}

// =============================================================================
// Metric Enumerations
// =============================================================================

@doc("Metric data type")
enum MetricType {
  @doc("Gauge - instantaneous value")
  gauge: "gauge",

  @doc("Sum - monotonic or non-monotonic counter")
  sum: "sum",

  @doc("Histogram - distribution of values")
  histogram: "histogram",

  @doc("Exponential histogram - distribution with exponential buckets")
  exponentialHistogram: "exponential_histogram",

  @doc("Summary - pre-aggregated quantiles")
  summary: "summary",
}

@doc("Aggregation temporality for metrics")
enum AggregationTemporality {
  @doc("Delta - values since last report")
  delta: 1,

  @doc("Cumulative - values since start")
  cumulative: 2,
}

@doc("Data point flags")
enum DataPointFlags {
  @doc("No flags set")
  none: 0,

  @doc("Value is absent (no measurement)")
  noRecordedValue: 1,
}

@doc("Metric instrument kinds per OTel specification")
enum InstrumentKind {
  @doc("Counter - monotonically increasing cumulative sum")
  counter: "Counter",

  @doc("UpDownCounter - can increase or decrease")
  upDownCounter: "UpDownCounter",

  @doc("Histogram - distribution of values with buckets")
  histogram: "Histogram",

  @doc("Gauge - instantaneous value at read time")
  gauge: "Gauge",

  @doc("Observable counter - async counter with callback")
  observableCounter: "ObservableCounter",

  @doc("Observable gauge - async gauge with callback")
  observableGauge: "ObservableGauge",

  @doc("Observable up-down counter - async up-down with callback")
  observableUpDownCounter: "ObservableUpDownCounter",
}

// =============================================================================
// Resource Enumerations
// =============================================================================

@doc("Telemetry SDK language")
enum TelemetrySdkLanguage {
  @doc("C++")
  cpp: "cpp",

  @doc(".NET (C#, F#, VB.NET)")
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

  @doc("Web browser JavaScript")
  webjs: "webjs",
}

// =============================================================================
// Error Enumerations
// =============================================================================

@doc("Standardized error types")
enum ErrorType {
  @doc("Generic error")
  error: "_OTHER",

  @doc("Timeout error")
  timeout: "TIMEOUT",

  @doc("Connection refused")
  connectionRefused: "CONNECTION_REFUSED",

  @doc("DNS resolution failed")
  dnsError: "DNS_ERROR",

  @doc("TLS/SSL handshake error")
  tlsError: "TLS_ERROR",

  @doc("Authentication failed")
  authError: "AUTH_ERROR",

  @doc("Permission denied")
  permissionDenied: "PERMISSION_DENIED",

  @doc("Resource not found")
  notFound: "NOT_FOUND",

  @doc("Resource exhausted/rate limited")
  resourceExhausted: "RESOURCE_EXHAUSTED",

  @doc("Invalid argument")
  invalidArgument: "INVALID_ARGUMENT",

  @doc("Operation cancelled")
  cancelled: "CANCELLED",
}

// =============================================================================
// Event Domain Types
// =============================================================================

@doc("Event domain (namespace for event types)")
enum EventDomain {
  @doc("Browser/RUM events")
  browser: "browser",

  @doc("Device events")
  device: "device",

  @doc("Kubernetes events")
  k8s: "k8s",

  @doc("User/session lifecycle events")
  session: "session",

  @doc("GenAI events")
  genAi: "gen_ai",

  @doc("Exception events")
  exception: "exception",

  @doc("Log events")
  log: "log",
}

// =============================================================================
// Profile Enumerations (v1development, Development stability)
// =============================================================================

@doc("Original payload format for profile data")
enum OriginalPayloadFormat {
  @doc("Google pprof format (original_payload SHOULD NOT be populated — lossless mapping)")
  pprof: "pprof",

  @doc("Java Flight Recorder")
  jfr: "jfr",

  @doc("Linux perf.data format")
  linuxPerf: "linux_perf",
}

@doc("Profile frame type — interpreter or compiler of a single frame")
enum ProfileFrameType {
  @doc("Erlang (BEAM VM)")
  beam: "beam",

  @doc("Python (CPython)")
  cpython: "cpython",

  @doc(".NET")
  dotnet: "dotnet",

  @doc("Go")
  go: "go",

  @doc("JVM")
  jvm: "jvm",

  @doc("OS Kernel")
  kernel: "kernel",

  @doc("C, C++, Go, Rust (use more precise value if possible)")
  native: "native",

  @doc("Perl")
  perl: "perl",

  @doc("PHP")
  php: "php",

  @doc("Ruby")
  ruby: "ruby",

  @doc("Rust")
  rust: "rust",

  @doc("V8 JavaScript engine")
  v8js: "v8js",
}
