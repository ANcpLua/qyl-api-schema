// =============================================================================
// OpenTelemetry metric data-point JSON projection
// =============================================================================
// The collector receives the official OTLP protobuf contract. This model is the
// generated client-facing projection returned by the Qyl product API.
// =============================================================================

import "@typespec/openapi";
import "../common/types.tsp";
import "./enums.tsp";
import "./resource.tsp";

using TypeSpec.OpenAPI;
using Qyl.Api.Contracts.Common;
using Qyl.Api.Contracts.OTel.Enums;

namespace Qyl.Api.Contracts.OTel.Metrics;

@doc("An OTLP signed 64-bit metric integer encoded as a decimal JSON string.")
@encode(string)
@TypeSpec.OpenAPI.extension("x-csharp-type", "long")
scalar MetricInt64 extends int64;

@doc("An OTLP unsigned 64-bit metric count encoded as a decimal JSON string.")
@encode(string)
@TypeSpec.OpenAPI.extension("x-csharp-type", "ulong")
scalar MetricUInt64 extends uint64;

@doc("A non-zero OTLP metric or exemplar timestamp in Unix nanoseconds.")
@encode(string)
@minValue(1)
@TypeSpec.OpenAPI.extension("x-csharp-type", "ulong")
scalar MetricUnixNanos extends uint64;

@doc("An optional OTLP metric start timestamp in Unix nanoseconds, encoded as a decimal JSON string.")
@encode(string)
@minValue(0)
@TypeSpec.OpenAPI.extension("x-csharp-type", "ulong")
scalar MetricStartUnixNanos extends uint64;

@doc("An OTLP double encoded as a JSON number when finite or as a canonical named string when non-finite.")
union MetricDouble {
  finite: float64,
  nan: "NaN",
  positiveInfinity: "Infinity",
  negativeInfinity: "-Infinity",
}

@doc("An integer measurement value from an OTLP number data point or exemplar.")
model MetricIntegerValue {
  @encodedName("application/json", "as_int")
  asInt: MetricInt64;
}

@doc("A floating-point measurement value from an OTLP number data point or exemplar.")
model MetricDoubleValue {
  @encodedName("application/json", "as_double")
  asDouble: MetricDouble;
}

@doc("The exactly-one numeric value carried by an OTLP number data point or exemplar.")
union MetricNumberValue {
  integer: MetricIntegerValue,
  double: MetricDoubleValue,
}

@doc("A sampled measurement linked to the trace or span active when it was recorded.")
model MetricExemplar {
  @encodedName("application/json", "time_unix_nano")
  timeUnixNano: MetricUnixNanos;

  value: MetricNumberValue;

  @encodedName("application/json", "span_id")
  spanId?: SpanId;

  @encodedName("application/json", "trace_id")
  traceId?: TraceId;

  @encodedName("application/json", "filtered_attributes")
  filteredAttributes?: Attribute[];
}

@doc("Bucket range used by an OTLP exponential histogram data point.")
model ExponentialHistogramBuckets {
  @doc("Index of the first bucket count.")
  offset: int32;

  @encodedName("application/json", "bucket_counts")
  bucketCounts: MetricUInt64[];
}

@doc("A quantile and value reported by an OTLP summary data point.")
model SummaryQuantileValue {
  @minValue(0)
  @maxValue(1)
  quantile: float64;

  value: MetricDouble;
}

@doc("Fields shared by every persisted OTLP metric data point.")
model MetricPointBase {
  @doc("Metric stream name.")
  @minLength(1)
  name: string;

  description?: string;
  unit?: string;

  @doc("Non-identifying metadata attached to the OTLP metric descriptor.")
  metadata?: Attribute[];

  @doc("Attributes identifying this metric time series.")
  attributes?: Attribute[];

  @encodedName("application/json", "start_time_unix_nano")
  startTimeUnixNano: MetricStartUnixNanos;

  @encodedName("application/json", "time_unix_nano")
  timeUnixNano: MetricUnixNanos;

  @doc("OTLP data-point flags preserved as an extensible bit field.")
  flags: uint32;

  @doc("Resource describing the entity that produced the metric.")
  resource: Qyl.Api.Contracts.OTel.Resource.Resource;

  @encodedName("application/json", "resource_schema_url")
  resourceSchemaUrl?: string;

  @encodedName("application/json", "instrumentation_scope")
  instrumentationScope?: InstrumentationScope;

  @encodedName("application/json", "scope_schema_url")
  scopeSchemaUrl?: string;
}

@doc("Instantaneous gauge measurement.")
model GaugeMetricPoint extends MetricPointBase {
  type: "gauge";

  @doc("Recorded value, absent when flags contain NO_RECORDED_VALUE (bit 1).")
  value?: MetricNumberValue;

  exemplars?: MetricExemplar[];
}

@doc("Delta or cumulative sum measurement.")
model SumMetricPoint extends MetricPointBase {
  type: "sum";

  @doc("Recorded value, absent when flags contain NO_RECORDED_VALUE (bit 1).")
  value?: MetricNumberValue;

  @encodedName("application/json", "aggregation_temporality")
  aggregationTemporality: AggregationTemporality;

  @encodedName("application/json", "is_monotonic")
  isMonotonic: boolean;

  exemplars?: MetricExemplar[];
}

@doc("Explicit-bucket histogram measurement.")
model HistogramMetricPoint extends MetricPointBase {
  type: "histogram";
  count: MetricUInt64;
  sum?: MetricDouble;

  @encodedName("application/json", "bucket_counts")
  bucketCounts: MetricUInt64[];

  @encodedName("application/json", "explicit_bounds")
  explicitBounds: float64[];

  min?: MetricDouble;
  max?: MetricDouble;

  @encodedName("application/json", "aggregation_temporality")
  aggregationTemporality: AggregationTemporality;

  exemplars?: MetricExemplar[];
}

@doc("Base-2 exponential histogram measurement.")
model ExponentialHistogramMetricPoint extends MetricPointBase {
  type: "exponential_histogram";
  count: MetricUInt64;
  sum?: MetricDouble;
  scale: int32;

  @encodedName("application/json", "zero_count")
  zeroCount: MetricUInt64;

  @encodedName("application/json", "zero_threshold")
  zeroThreshold: MetricDouble;

  positive: ExponentialHistogramBuckets;
  negative: ExponentialHistogramBuckets;
  min?: MetricDouble;
  max?: MetricDouble;

  @encodedName("application/json", "aggregation_temporality")
  aggregationTemporality: AggregationTemporality;

  exemplars?: MetricExemplar[];
}

@doc("Pre-aggregated summary measurement.")
model SummaryMetricPoint extends MetricPointBase {
  type: "summary";
  count: MetricUInt64;
  sum: MetricDouble;

  @encodedName("application/json", "quantile_values")
  quantileValues: SummaryQuantileValue[];
}

@doc("One persisted OTLP metric data point, discriminated by aggregation kind.")
union MetricPoint {
  gauge: GaugeMetricPoint,
  sum: SumMetricPoint,
  histogram: HistogramMetricPoint,
  exponentialHistogram: ExponentialHistogramMetricPoint,
  summary: SummaryMetricPoint,
}
