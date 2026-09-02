import "../common/types.tsp";

using Qyl.Api.Contracts.Common;

namespace Qyl.Api.Contracts.OTel.Metrics;

@doc("Shape of a stored metric stream.")
enum MetricKind {
  @doc("A value sampled at a point in time.")
  gauge: "gauge",

  @doc("An additive value; see `temporality` and `monotonic` for how to read it.")
  sum: "sum",

  @doc("A distribution recorded against explicit bucket boundaries.")
  histogram: "histogram",

  @doc("""
    An OTLP exponential histogram. Its buckets are stored in the same explicit
    bound vector `histogram` uses, so both kinds answer the same queries; the
    distinct name records only where the distribution came from.
    """)
  exponential_histogram: "exponential_histogram",
}

@doc("How successive points of a sum or histogram relate to each other.")
enum MetricTemporality {
  unspecified: "unspecified",

  @doc("Each point covers only the interval since the previous one.")
  delta: "delta",

  @doc("Each point is the running total since the stream's start time.")
  cumulative: "cumulative",
}

@doc("Server-side reducer applied to the points falling in one time bucket.")
enum MetricAggregation {
  avg: "avg",
  min: "min",
  max: "max",
  sum: "sum",
  count: "count",

  @doc("The value of the latest point in the bucket.")
  last: "last",

  @doc("50th percentile, interpolated from bucket boundaries. Histogram kinds only.")
  p50: "p50",

  @doc("90th percentile, interpolated from bucket boundaries. Histogram kinds only.")
  p90: "p90",

  @doc("95th percentile, interpolated from bucket boundaries. Histogram kinds only.")
  p95: "p95",

  @doc("99th percentile, interpolated from bucket boundaries. Histogram kinds only.")
  p99: "p99",
}

@doc("""
  One metric name recorded for a project, collapsed across all of its series.
  This is the catalog entry a client reads before it knows which series exist.
  """)
model MetricDescriptor {
  @doc("Instrument name, e.g. `http.server.request.duration`.")
  name: string;

  kind: MetricKind;

  temporality: MetricTemporality;

  @doc("Whether a sum only ever increases. Meaningless for other kinds.")
  monotonic: boolean;

  @doc("UCUM unit as reported by the producer, e.g. `s` or `{request}`.")
  unit?: string;

  @doc("Producer-supplied description of the instrument.")
  description?: string;

  @doc("Number of distinct attribute streams recorded under this name.")
  @encodedName("application/json", "series_count")
  seriesCount: int64;

  @doc("Timestamp of the most recent point recorded under this name.")
  @encodedName("application/json", "last_seen")
  lastSeen: utcDateTime;
}

@doc("One distinct attribute stream recorded under a metric name.")
model MetricSeries {
  @doc("Stable identifier for this stream, derived from its name, attributes and resource.")
  @encodedName("application/json", "series_id")
  seriesId: string;

  @doc("Instrument name this series belongs to.")
  name: string;

  kind: MetricKind;

  @doc("The attributes that distinguish this series from others under the same name.")
  attributes: Attribute[];

  @encodedName("application/json", "service_name")
  serviceName?: string;

  unit?: string;

  @encodedName("application/json", "first_seen")
  firstSeen: utcDateTime;

  @encodedName("application/json", "last_seen")
  lastSeen: utcDateTime;
}

@doc("One aggregated time bucket of a metric range query.")
model MetricBucket {
  @doc("Inclusive start of the bucket, aligned to the query's step from the query's start.")
  @encodedName("application/json", "bucket_start")
  bucketStart: utcDateTime;

  @doc("""
    The aggregation applied to the points in this bucket. Null when the bucket
    holds no value: either no point landed in it, or every point that did was
    an OTLP `NO_RECORDED_VALUE` marker.
    """)
  value: float64 | null;

  @doc("Number of stored points folded into this bucket.")
  @encodedName("application/json", "point_count")
  pointCount: int64;
}

@doc("""
  One result stream of a metric range query. With no `group_by` the whole
  result is a single stream whose `attributes` are empty; with `group_by` there
  is one stream per distinct combination of the requested attribute values.
  """)
model MetricSeriesResult {
  @doc("The grouping key that produced this stream.")
  attributes: Attribute[];

  buckets: MetricBucket[];
}

@doc("The answer to a metric range query: what was asked, and the streams it produced.")
model MetricQueryResult {
  @doc("Instrument name the query ran against.")
  name: string;

  kind: MetricKind;

  unit?: string;

  aggregation: MetricAggregation;

  @doc("Bucket width actually used, which may be widened from the requested step.")
  @encodedName("application/json", "step_ms")
  stepMs: int64;

  @encodedName("application/json", "start_time")
  startTime: utcDateTime;

  @encodedName("application/json", "end_time")
  endTime: utcDateTime;

  series: MetricSeriesResult[];

  @doc("Whether streams were dropped because the result exceeded the series limit.")
  truncated: boolean;
}
