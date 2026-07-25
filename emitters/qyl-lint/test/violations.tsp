// =============================================================================
// Negative fixture — every construct here MUST be rejected.
// =============================================================================
// This file is never imported by the product contract. It exists so the gate
// proves the rules actually fire: a linter that silently matches nothing passes
// exactly like a clean tree, and the whole guarantee would be vacuous.
//
// scripts/verify-lint-rules.mjs compiles this file and asserts a non-zero exit
// plus at least one diagnostic from every rule the library declares.
// =============================================================================

import "@typespec/http";
import "../../../common/types.tsp";

using TypeSpec.Http;
using Qyl.Api.Contracts.Common;

namespace Qyl.Api.Contracts.LintFixture;

@doc("Body properties that must be rejected for their wire names.")
model CamelAndDottedBody {
  // wire-name-snake-case: falls back to the raw camelCase TypeSpec name.
  serviceName: string;

  // wire-name-snake-case: a dotted semantic-convention key in a product DTO.
  @encodedName("application/json", "session.id")
  attributeKey: string;

  // wire-name-snake-case: an explicit but camelCase encoded name. The name must
  // differ from the property's own, which the compiler rejects as a conflict.
  @encodedName("application/json", "startTime")
  beganAt: utcDateTime;
}

@doc("Identity properties that must be rejected for their type or name.")
model UntypedIdentities {
  // identity-binding (name -> type): a reserved identity name typed as string.
  @encodedName("application/json", "trace_id")
  traceId?: string;

  // identity-binding (name -> type): reserved plural typed as string[].
  @encodedName("application/json", "span_ids")
  spanIds?: string[];

  // identity-binding (type -> name): carries SessionId under an unrelated name
  // that is not the bare token and does not end in the scalar.
  owner?: SessionId;

  // identity-binding (name -> key): an identity renamed on the wire.
  @encodedName("application/json", "correlation_trace")
  parentSpanId?: SpanId;

  // identity-binding (type -> name): an unregistered qualified edge. A suffix
  // rule would have admitted this silently, which is how one identity acquires
  // a second spelling; only names in the edge registry are legal.
  @encodedName("application/json", "candidate_trace_id")
  candidateTraceId?: TraceId;
}

@doc("A scalar that reads like a shared identity but declares no relationship.")
@minLength(1)
scalar FixtureSessionId extends string;

@doc("Uses the undocumented confusable scalar so it is reachable.")
model ConfusableHolder {
  @encodedName("application/json", "fixture_session_id")
  fixtureSessionId: FixtureSessionId;
}

@route("/lint-fixture")
interface LintFixtureApi {
  // http-param-snake-case: camelCase query and path parameter names.
  @get
  @route("/{traceId}")
  read(@path traceId: TraceId, @query serviceName?: string): CamelAndDottedBody;
}
