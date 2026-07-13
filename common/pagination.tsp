// =============================================================================
// Qyl API pagination templates
// =============================================================================
// Reusable pagination patterns for list operations.
// =============================================================================

import "@typespec/http";
import "./types.tsp";

using TypeSpec.Http;

namespace Qyl.Api.Contracts.Common.Pagination;

// =============================================================================
// Cursor-Based Pagination (Preferred for Large Datasets)
// =============================================================================

@doc("Cursor-based pagination parameters")
model CursorPaginationParams {
  @doc("Opaque cursor for fetching the next page")
  @query
  cursor?: string;

  @doc("Maximum number of items to return (1-1000)")
  @query
  @minValue(1)
  @maxValue(1000)
  limit?: int32 = 100;

  @doc("Sort direction")
  @query
  order?: SortOrder = SortOrder.desc;
}

@doc("Sort order")
enum SortOrder {
  @doc("Ascending order (oldest first)")
  asc,

  @doc("Descending order (newest first)")
  desc,
}

@doc("Cursor-based paginated response wrapper")
model CursorPage<T> {
  @doc("List of items in this page")
  @pageItems
  items: T[];

  @doc("Cursor for the next page (null if no more pages)")
  @encodedName("application/json", "next_cursor")
  @nextLink
  nextCursor?: string;

  @doc("Cursor for the previous page (null if first page)")
  @encodedName("application/json", "prev_cursor")
  prevCursor?: string;

  @doc("Whether there are more items available")
  @encodedName("application/json", "has_more")
  hasMore: boolean;
}

// =============================================================================
// Offset-Based Pagination (For Small/Medium Datasets)
// =============================================================================

@doc("Offset-based pagination parameters")
model OffsetPaginationParams {
  @doc("Page number (1-indexed)")
  @query
  @pageIndex
  @minValue(1)
  page?: int32 = 1;

  @doc("Items per page (1-1000)")
  @query
  @pageSize
  @minValue(1)
  @maxValue(1000)
  @encodedName("application/json", "page_size")
  pageSize?: int32 = 100;
}

@doc("Offset-based paginated response wrapper")
model OffsetPage<T> {
  @doc("List of items in this page")
  @pageItems
  items: T[];

  @doc("Current page number")
  page: int32;

  @doc("Items per page")
  @encodedName("application/json", "page_size")
  pageSize: int32;

  @doc("Total number of items across all pages")
  @encodedName("application/json", "total_count")
  totalCount: int64;

  @doc("Total number of pages")
  @encodedName("application/json", "total_pages")
  totalPages: int32;

  @doc("Whether there is a next page")
  @encodedName("application/json", "has_next")
  hasNext: boolean;

  @doc("Whether there is a previous page")
  @encodedName("application/json", "has_prev")
  hasPrev: boolean;
}

// =============================================================================
// Time-Range Pagination (For Time-Series Data)
// =============================================================================

@doc("Time-range based query parameters")
model TimeRangeParams {
  @doc("Start of time range (inclusive)")
  @query
  @encodedName("application/json", "start_time")
  startTime?: utcDateTime;

  @doc("End of time range (exclusive)")
  @query
  @encodedName("application/json", "end_time")
  endTime?: utcDateTime;

  @doc("Maximum number of items to return")
  @query
  @minValue(1)
  @maxValue(10000)
  limit?: int32 = 1000;
}

@doc("Time-range paginated response with continuation")
model TimeRangePage<T> {
  @doc("List of items in this page")
  @pageItems
  items: T[];

  @doc("Actual start time of returned data")
  @encodedName("application/json", "start_time")
  startTime: utcDateTime;

  @doc("Actual end time of returned data")
  @encodedName("application/json", "end_time")
  endTime: utcDateTime;

  @doc("Continuation token for next time window")
  @encodedName("application/json", "continuation_token")
  @continuationToken
  continuationToken?: string;

  @doc("Whether there is more data in the time range")
  @encodedName("application/json", "has_more")
  hasMore: boolean;

  @doc("Number of items returned")
  count: int32;
}

// =============================================================================
// Streaming Pagination (For Real-Time Data)
// =============================================================================

@doc("Streaming parameters for SSE endpoints")
model StreamParams {
  @doc("Include historical data from this timestamp")
  @query
  since?: utcDateTime;

  @doc("Filter by trace ID")
  @query
  @encodedName("application/json", "trace_id")
  traceId?: string;

  @doc("Filter by service name")
  @query
  @encodedName("application/json", "service_name")
  serviceName?: string;

  @doc("Maximum events per second (rate limiting)")
  @query
  @encodedName("application/json", "max_events_per_second")
  @minValue(1)
  @maxValue(1000)
  maxEventsPerSecond?: int32 = 100;
}

@doc("SSE event wrapper for streaming")
model StreamEvent<T> {
  @doc("Event ID for resumption")
  id: string;

  @doc("Event type")
  @encodedName("application/json", "event_type")
  eventType: string;

  @doc("Event timestamp")
  timestamp: utcDateTime;

  @doc("Event data payload")
  data: T;

  @doc("Retry interval hint in milliseconds")
  retry?: int32;
}

// =============================================================================
// Aggregation Parameters
// =============================================================================

@doc("Time bucket size for aggregations")
enum TimeBucket {
  @doc("1 minute buckets")
  minute: "1m",

  @doc("5 minute buckets")
  fiveMinutes: "5m",

  @doc("15 minute buckets")
  fifteenMinutes: "15m",

  @doc("1 hour buckets")
  hour: "1h",

  @doc("1 day buckets")
  day: "1d",

  @doc("1 week buckets")
  week: "1w",

  @doc("Auto-select based on time range")
  auto: "auto",
}

@doc("Aggregation query parameters")
model AggregationParams {
  @doc("Time bucket size")
  @query
  bucket?: TimeBucket = TimeBucket.auto;

  @doc("Group by these dimensions")
  @query
  @encodedName("application/json", "group_by")
  groupBy?: string[];

  @doc("Filter expression")
  @query
  filter?: string;
}
