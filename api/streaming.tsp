// =============================================================================
// qyl streaming API routes
// =============================================================================
// Server-Sent Events (SSE) streaming endpoints for real-time telemetry.
// =============================================================================

import "@typespec/http";
import "@typespec/sse";
import "@typespec/events";
import "@typespec/versioning";

import "../common/types.tsp";
import "../common/pagination.tsp";
import "../otel/span.tsp";
import "../otel/logs.tsp";
import "../otel/metrics.tsp";
import "../models/deployment.tsp";

using TypeSpec.Http;
using TypeSpec.SSE;
using TypeSpec.Events;
using TypeSpec.Versioning;

using Qyl.Api.Contracts.Common;
using Qyl.Api.Contracts.OTel.Traces;
using Qyl.Api.Contracts.OTel.Logs;
using Qyl.Api.Contracts.OTel.Metrics;
using Qyl.Api.Contracts.OTel.Enums;
using Qyl.Api.Contracts.Domains.Ops.Deployment;

namespace Qyl.Api.Contracts.Streaming;

// =============================================================================
// Stream Event Types
// =============================================================================

@doc("Trace stream event")
model TraceStreamEvent {
  @doc("Event type")
  type: "trace";

  @doc("Trace data")
  data: Trace;

  @doc("Event timestamp")
  timestamp: utcDateTime;
}

@doc("Span stream event")
model SpanStreamEvent {
  @doc("Event type")
  type: "span";

  @doc("Span data")
  data: Span;

  @doc("Event timestamp")
  timestamp: utcDateTime;
}

@doc("Log stream event")
model LogStreamEvent {
  @doc("Event type")
  type: "log";

  @doc("Log data")
  data: LogRecord;

  @doc("Event timestamp")
  timestamp: utcDateTime;
}

@doc("Metric stream event")
model MetricStreamEvent {
  @doc("Event type")
  type: "metric";

  @doc("Metric data")
  data: Metric;

  @doc("Event timestamp")
  timestamp: utcDateTime;
}

@doc("Deployment stream event")
model DeploymentStreamEvent {
  @doc("Event type")
  type: "deployment";

  @doc("Deployment event data")
  data: DeploymentEvent;

  @doc("Event timestamp")
  timestamp: utcDateTime;
}

@doc("Heartbeat event for connection keep-alive")
model HeartbeatEvent {
  @doc("Event type")
  type: "heartbeat";

  @doc("Server timestamp")
  timestamp: utcDateTime;
}

// =============================================================================
// Combined Stream Event Union
// =============================================================================

@doc("All possible stream event types")
@events
union TelemetryStreamEvent {
  trace: TraceStreamEvent,
  span: SpanStreamEvent,
  log: LogStreamEvent,
  metric: MetricStreamEvent,
  deployment: DeploymentStreamEvent,
  heartbeat: HeartbeatEvent,
}

@doc("Trace stream events")
@events
union TraceEvents {
  trace: TraceStreamEvent,
  heartbeat: HeartbeatEvent,
}

@doc("Span stream events")
@events
union SpanEvents {
  span: SpanStreamEvent,
  heartbeat: HeartbeatEvent,
}

@doc("Log stream events")
@events
union LogEvents {
  log: LogStreamEvent,
  heartbeat: HeartbeatEvent,
}

@doc("Metric stream events")
@events
union MetricEvents {
  metric: MetricStreamEvent,
  heartbeat: HeartbeatEvent,
}

@doc("Deployment stream events")
@events
union DeploymentEvents {
  deployment: DeploymentStreamEvent,
  heartbeat: HeartbeatEvent,
}

// =============================================================================
// Stream Subscription Models
// =============================================================================

@doc("Stream subscription request")
model StreamSubscription {
  @doc("Event types to subscribe to")
  @encodedName("application/json", "event_types")
  eventTypes: StreamEventType[];

  @doc("Service name filter")
  @encodedName("application/json", "service_name")
  serviceName?: string;

  @doc("Trace ID filter (for specific trace)")
  @encodedName("application/json", "trace_id")
  traceId?: TraceId;

  @doc("Minimum severity for logs (1-24)")
  @encodedName("application/json", "min_severity")
  @minValue(1)
  @maxValue(24)
  minSeverity?: int32;

  @doc("Attribute filters")
  filters?: Record<string>;

  @doc("Sample rate (0.0-1.0)")
  @encodedName("application/json", "sample_rate")
  @minValue(0)
  @maxValue(1)
  sampleRate?: float64;
}

@doc("Stream event types")
enum StreamEventType {
  @doc("Trace events")
  traces: "traces",

  @doc("Span events")
  spans: "spans",

  @doc("Log events")
  logs: "logs",

  @doc("Metric events")
  metrics: "metrics",

  @doc("Deployment events")
  deployments: "deployments",

  @doc("All events")
  all: "all",
}

// =============================================================================
// Streaming API Interfaces
// =============================================================================

@route("/api/v1/stream")
@tag("Streaming")
interface StreamingApi {
  @doc("Stream all telemetry events (SSE)")
  @get
  @route("/events")
  streamEvents(
    @query @doc("Event types") types?: StreamEventType[],
    @query @doc("Service name filter") serviceName?: string,
    @query @doc("Sample rate") sampleRate?: float64,
  ): SSEStream<TelemetryStreamEvent>;

  @doc("Stream traces in real-time")
  @get
  @route("/traces")
  streamTraces(
    @query @doc("Service name filter") serviceName?: string,
    @query @doc("Minimum duration filter") minDurationMs?: int64,
  ): SSEStream<TraceEvents>;

  @doc("Stream spans for a specific trace")
  @get
  @route("/traces/{traceId}/spans")
  streamTraceSpans(@path traceId: TraceId): SSEStream<SpanEvents>;

  @doc("Stream logs in real-time")
  @get
  @route("/logs")
  streamLogs(
    @query @doc("Service name filter") serviceName?: string,
    @query @doc("Minimum severity") minSeverity?: int32,
    @query @doc("Query filter") query?: string,
  ): SSEStream<LogEvents>;

  @doc("Stream metrics in real-time")
  @get
  @route("/metrics")
  streamMetrics(
    @query @doc("Metric name filter") metricName?: string,
    @query @doc("Service name filter") serviceName?: string,
  ): SSEStream<MetricEvents>;

  @doc("Stream deployment events")
  @get
  @route("/deployments")
  streamDeployments(
    @query @doc("Service name filter") serviceName?: string,
    @query @doc("Environment filter") environment?: string,
  ): SSEStream<DeploymentEvents>;
}

// =============================================================================
// WebSocket Streaming (Alternative)
// =============================================================================

@doc("WebSocket message wrapper")
model WebSocketMessage<T> {
  @doc("Message ID")
  id: string;

  @doc("Message type")
  type: WebSocketMessageType;

  @doc("Message payload")
  payload?: T;

  @doc("Timestamp")
  timestamp: utcDateTime;
}

@doc("WebSocket message types")
enum WebSocketMessageType {
  @doc("Subscribe to events")
  subscribe: "subscribe",

  @doc("Unsubscribe from events")
  unsubscribe: "unsubscribe",

  @doc("Data event")
  data: "data",

  @doc("Error message")
  error: "error",

  @doc("Acknowledgment")
  ack: "ack",

  @doc("Ping")
  ping: "ping",

  @doc("Pong")
  pong: "pong",
}

// =============================================================================
// Tail-based Sampling Configuration
// =============================================================================

@doc("Tail-based sampling configuration for streaming")
model TailSamplingConfig {
  @doc("Enable tail-based sampling")
  enabled: boolean;

  @doc("Sample error traces")
  @encodedName("application/json", "sample_errors")
  sampleErrors: boolean;

  @doc("Sample slow traces (above threshold)")
  @encodedName("application/json", "sample_slow")
  sampleSlow: boolean;

  @doc("Slow trace threshold in milliseconds")
  @encodedName("application/json", "slow_threshold_ms")
  slowThresholdMs?: int64;

  @doc("Random sample rate for remaining traces")
  @encodedName("application/json", "random_rate")
  @minValue(0)
  @maxValue(1)
  randomRate: float64;
}
