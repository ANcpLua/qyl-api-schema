import "@ancplua/typespec-emit-duckdb";

using Qyl.Api.Schema.Emit.DuckDb;

@duckdbTable("spans")
model SpanRow {
  @duckdbPrimaryKey
  span_id: string;

  @duckdbIndex("idx_spans_trace")
  trace_id: string;

  name: string;
  start_unix_nano: int64;
  duration_ns: int64;
  attributes: string;
}
