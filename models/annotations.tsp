import "../common/telemetry-query.tsp";
// =============================================================================
// Annotations: user notes on a trace, span or session
// =============================================================================
// A note the user writes inside the verified subject's qyl project. It never
// changes the telemetry it points at. get_trace and list_sessions read
// annotations back, so there is no annotation listing tool.
// =============================================================================

import "@typespec/http";
import "@typespec/openapi";
import "../common/types.tsp";
import "../common/resource.tsp";

using TypeSpec.OpenAPI;
using Qyl.Api.Contracts.Common;

namespace Qyl.Api.Contracts.Annotations;

@doc("An annotation on one whole trace.")
model TraceAnnotationTarget {
  kind: "trace";

  @encodedName("application/json", "trace_id")
  traceId: TraceId;
}

@doc("An annotation on one span of a trace.")
model SpanAnnotationTarget {
  kind: "span";

  @encodedName("application/json", "trace_id")
  traceId: TraceId;

  @encodedName("application/json", "span_id")
  spanId: SpanId;
}

@doc("An annotation on one session.")
model SessionAnnotationTarget {
  kind: "session";

  @encodedName("application/json", "session_id")
  sessionId: SessionId;
}

@doc("Exactly one telemetry object an annotation is attached to.")
@oneOf
union AnnotationTarget {
  trace: TraceAnnotationTarget,
  span: SpanAnnotationTarget,
  session: SessionAnnotationTarget,
  failure: FailureAnnotationTarget,
}

@doc("A user note attached to a trace, span or session.")
model Annotation extends ResourceBase {
  @maxItems(10)
  labels?: AnnotationLabel[];
  classification?: AnnotationClassification;

  @doc("What the note is attached to. Fixed at creation.")
  @visibility(Lifecycle.Read, Lifecycle.Create)
  target: AnnotationTarget;

  @doc("The note, plain text, at most 2000 characters.")
  @minLength(1)
  @maxLength(2000)
  text: string;
}

@doc("Body of POST /api/v1/annotations: the `Lifecycle.Create` members of Annotation.")
model AnnotationCreateRequest {
  @maxItems(10)
  labels?: AnnotationLabel[];
  classification?: AnnotationClassification;

  @doc("What the note is attached to. Fixed at creation.")
  target: AnnotationTarget;

  @doc("The note, plain text, at most 2000 characters.")
  @minLength(1)
  @maxLength(2000)
  text: string;
}

@doc("Body of PATCH /api/v1/annotations/{annotation_id}: the `Lifecycle.Update` members of Annotation.")
model AnnotationUpdateRequest {
  @maxItems(10)
  labels?: AnnotationLabel[];
  classification?: AnnotationClassification;

  @doc("The new note, plain text, at most 2000 characters.")
  @minLength(1)
  @maxLength(2000)
  text?: string;
}

@doc("FailureAnnotationTarget contract.")
model FailureAnnotationTarget {
  kind: "failure";
  @encodedName("application/json", "failure_id")
  failureId: FailureId;
}


@doc("Classification of the human annotation.")
enum AnnotationClassification { note, hypothesis, finding, rejected }

@doc("A short user-defined annotation label.")
@minLength(1)
@maxLength(64)
scalar AnnotationLabel extends string;
