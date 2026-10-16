// Gate for the ./zod export: the Zod validators it builds must agree with the
// published JSON Schema, definition for definition and fixture for fixture.
//
// The adapter in src/zod/index.ts rewrites published JSON Schema constructs that
// z.fromJSONSchema cannot consume. Every rewrite is a place where a validator
// could quietly become weaker than the contract, so each one is pinned below
// against a real wire shape rather than against the rewritten schema.
import {
  contractSchema,
  exercisedFixtures,
} from "./lib/contract-fixtures.mjs";
import {
  contractDefinitionNames,
  contractJsonSchemaId,
  publishedContractSchema,
} from "../generated/zod-runtime/index.js";

// The fixture corpus is a script, not a data file: running it is what fills the
// recording this gate replays. A failure here is a corpus failure and says so,
// because the same script is also its own Check target.
try {
  await import("./verify-contract-fixtures.mjs");
} catch (cause) {
  throw new Error(
    "Zod parity replays the contract fixture corpus, which did not pass. Fix `npm run verify:contracts` first.",
    { cause },
  );
}

if (contractJsonSchemaId !== contractSchema.$id) {
  throw new Error(
    `The ./zod export reports $id '${contractJsonSchemaId}' but ${contractSchema.$id} was published. ` +
    "The runtime is built from a stale generated/json-schema copy; run `npm run compile`.",
  );
}

// 1. The whole published surface builds. A definition that only some consumer
//    happens to name would otherwise hide an adapter gap until that consumer
//    reaches it.
const definitionNames = contractDefinitionNames();
const publishedNames = Object.keys(contractSchema.$defs ?? {}).sort();
if (JSON.stringify(definitionNames) !== JSON.stringify(publishedNames)) {
  throw new Error(
    `contractDefinitionNames() lists ${definitionNames.length} names but the published schema has ` +
    `${publishedNames.length}.`,
  );
}

const constructionFailures = [];
for (const definition of definitionNames) {
  try {
    publishedContractSchema(definition);
  } catch (error) {
    constructionFailures.push(`${definition}: ${error?.message ?? error}`);
  }
}
if (constructionFailures.length > 0) {
  throw new Error(
    `${constructionFailures.length}/${definitionNames.length} published definitions could not be built ` +
    `as Zod schemas:\n  ${constructionFailures.join("\n  ")}`,
  );
}

let unknownDefinitionRejected = false;
try {
  publishedContractSchema("Definition.That.Is.Not.Published");
} catch {
  unknownDefinitionRejected = true;
}
if (!unknownDefinitionRejected) {
  throw new Error("publishedContractSchema must throw for a definition the schema does not publish.");
}

// 2. Zod and Ajv must reach the same verdict on every fixture the corpus judges.
//    Ajv reads the published schema directly, so a divergence is the adapter
//    changing the contract rather than translating it.
const divergences = [];
for (const { definition, fixture, valid, label } of exercisedFixtures) {
  const accepted = publishedContractSchema(definition).safeParse(fixture).success;
  if (accepted !== valid) {
    divergences.push(
      `${definition} — ${label}: JSON Schema says ${valid ? "valid" : "invalid"}, Zod says ` +
      `${accepted ? "valid" : "invalid"}\n      ${JSON.stringify(fixture).slice(0, 400)}`,
    );
  }
}
if (divergences.length > 0) {
  throw new Error(
    `${divergences.length}/${exercisedFixtures.length} contract fixtures are judged differently by the ` +
    `./zod export than by the published JSON Schema:\n    ${divergences.join("\n    ")}`,
  );
}

// 3. `format: "date-time"` is passed through to Zod unrewritten because Zod
//    4.5's conversion is already RFC 3339. Pin the four properties that decision
//    rests on: a numeric UTC offset is accepted, seconds are required, a
//    colon-less offset is rejected, and a local time without an offset is
//    rejected. If this fails, Zod's date-time conversion moved and the adapter
//    has to rewrite date-time into an explicit RFC 3339 pattern again.
const timestamp = publishedContractSchema("Common.Timestamp");
const dateTimeCases = [
  ["2026-07-28T10:15:00Z", true, "UTC designator"],
  ["2026-07-28T10:15:00+02:00", true, "numeric UTC offset"],
  ["2026-07-28T10:15:00.123456+02:00", true, "fractional seconds with an offset"],
  ["2026-07-28T10:15Z", false, "minute precision (RFC 3339 requires seconds)"],
  ["2026-07-28T10:15:00+0200", false, "colon-less offset"],
  ["2026-07-28T10:15:00", false, "local time with no offset"],
];
const dateTimeFailures = dateTimeCases
  .filter(([value, expected]) => timestamp.safeParse(value).success !== expected)
  .map(([value, expected, why]) =>
    `${JSON.stringify(value)} (${why}) should be ${expected ? "accepted" : "rejected"}`);
if (dateTimeFailures.length > 0) {
  throw new Error(
    "Zod's `format: \"date-time\"` conversion no longer matches RFC 3339 for Common.Timestamp:\n  " +
    dateTimeFailures.join("\n  ") +
    "\nCheck z.fromJSONSchema({ type: \"string\", format: \"date-time\" }) against the installed zod. " +
    "If it narrowed, adaptPublishedSchemaForZod must rewrite date-time to an explicit RFC 3339 pattern.",
  );
}

// 4. 64-bit integers. Nanosecond timestamps are published as decimal strings so
//    they survive JSON exactly; the integer-typed int64 scalars keep the integer
//    rule but must not inherit Zod's +/-2^53 range check, which the contract does
//    not have.
const unixNanos = publishedContractSchema("Common.UnixNanos");
if (!unixNanos.safeParse("1742000000123456789").success) {
  throw new Error("Common.UnixNanos must accept a full-precision nanosecond timestamp as a decimal string.");
}
// The imprecise literal is the input under test: an unencoded number must be
// rejected precisely because it cannot round-trip.
// oxlint-disable-next-line no-loss-of-precision
if (unixNanos.safeParse("1.5").success || unixNanos.safeParse(1742000000123456789).success) {
  throw new Error("Common.UnixNanos must reject non-integral strings and unencoded numbers.");
}
/** @type {Array<[string, string[], string[]]>} */
const decimalRangeCases = [
  ["Common.AttributeInt64", ["0", "9007199254740993", "9223372036854775807", "-9223372036854775808"],
    ["9223372036854775808", "-9223372036854775809", "99999999999999999999", "-0", "+1", "01"]],
  ["OTel.Metrics.MetricCount", ["0", "9007199254740993", "18446744073709551615"],
    ["18446744073709551616", "99999999999999999999", "-1", "01"]],
  ["Common.UnixNanos", ["0", "18446744073709551615"], ["18446744073709551616", "-1"]],
];
for (const [name, accepted, rejected] of decimalRangeCases) {
  const validator = publishedContractSchema(name);
  for (const value of accepted) if (!validator.safeParse(value).success) {
    throw new Error(`${name} rejected an exact in-range decimal ${value}`);
  }
  for (const value of rejected) if (validator.safeParse(value).success) {
    throw new Error(`${name} accepted an out-of-range or noncanonical decimal ${value}`);
  }
}
const byteSize = publishedContractSchema("Common.ByteSize");
// 2^53 + 1: the first integer JavaScript numbers cannot represent exactly, and
// the boundary Zod's int64 conversion would have refused.
// oxlint-disable-next-line no-loss-of-precision -- 2^53+1, per the comment above
if (!byteSize.safeParse(9007199254740993).success) {
  throw new Error(
    "Common.ByteSize (integer/int64) must accept a value above 2^53. Zod's int64 range check leaked back in; " +
    "the adapter converts integer int64/uint64 to `type: number` with `multipleOf: 1` to keep it out.",
  );
}
if (byteSize.safeParse(1.5).success) {
  throw new Error("Common.ByteSize must still reject a fractional value.");
}

// 5. Sealed objects stay sealed through `allOf` inheritance, for every model the
//    contract declares with `extends`. Building the derivative as an intersection
//    instead of a flattened object silently reopens it, and nothing else in this
//    gate would notice. Each case carries the base's fields (accepted), one own
//    property where the model declares one (accepted), an invented key
//    (rejected), and the body minus one base-required field (rejected: the
//    base's `required` set has to survive the flattening too). The case list is
//    checked against the published schema, so a new `extends` model fails here
//    until it has a case.
const problemDetails = (slug, code, title, status) => ({
  type: `https://qyl.at/problems/${slug}`,
  title,
  status,
  detail: "what went wrong in this occurrence",
  instance: "https://api.qyl.at/api/v1/traces/0af7651916cd43dd8448eb211c80319c",
  code,
});
const evaluationRunRequest = {
  idempotency_key: "run-2026-07-28-0001",
  confirmation: { acknowledged: true, acknowledgement: "run the suite" },
  concurrency: 2,
  fail_fast: true,
};
const inheritanceCases = {
  "Mcp.Tools.ToolSpan": {
    body: {
      trace_id: "0af7651916cd43dd8448eb211c80319c",
      span_id: "b7ad6b7169203331", name: "db.query", kind: 3,
      start_time_unix_nano: "123000000", end_time_unix_nano: "124000000",
      status: { code: 2 }, resource: { service_name: "orders-db" }, role: "matched",
    },
    own: { self_time_ms: 1, self_time_share: 1 },
    baseRequired: "trace_id",
  },
  "Mcp.Tools.ToolTrace": {
    body: {
      trace_id: "0af7651916cd43dd8448eb211c80319c", span_count: 0,
      duration_ns: "1500000", start_time: "2026-07-28T10:15:00Z",
      end_time: "2026-07-28T10:15:00.001500Z", services: ["orders-db"], has_error: true,
      spans: [],
    },
    own: {}, baseRequired: "trace_id",
  },

  "Common.Errors.BadGatewayError": {
    body: problemDetails("bad-gateway", "bad_gateway", "Bad Gateway", 502),
    own: { dependency: "storage" },
    baseRequired: "status",
  },
  "Common.Errors.ConflictError": {
    body: problemDetails("conflict", "conflict", "Conflict", 409),
    own: { conflicting_resource: "ws-1" },
    baseRequired: "status",
  },
  "Common.Errors.ForbiddenError": {
    body: problemDetails("forbidden", "forbidden", "Forbidden", 403),
    own: { required_permission: "qyl:read" },
    baseRequired: "status",
  },
  "Common.Errors.InternalServerError": {
    body: problemDetails("internal-error", "internal_error", "Internal Server Error", 500),
    own: {},
    baseRequired: "status",
  },
  "Common.Errors.NotFoundError": {
    body: problemDetails("not-found", "not_found", "Not Found", 404),
    own: { resource_type: "trace", resource_id: "0af7651916cd43dd8448eb211c80319c" },
    baseRequired: "status",
  },
  "Common.Errors.ServiceUnavailableError": {
    body: problemDetails("service-unavailable", "service_unavailable", "Service Unavailable", 503),
    own: { reason: "overloaded" },
    baseRequired: "status",
  },
  "Common.Errors.UnauthorizedError": {
    body: problemDetails("unauthorized", "unauthorized", "Unauthorized", 401), own: {}, baseRequired: "status",
  },
  "Common.Errors.ValidationError": {
    body: {
      ...problemDetails("validation-failed", "validation_failed", "Validation Failed", 400),
      errors: [{ field: "limit", message: "must be at most 1000", code: "max_value", rejected_value: "5000" }],
    },
    own: {},
    baseRequired: "status",
  },
  "Annotations.Annotation": {
    body: {
      id: "ann-1",
      created_at: "2026-10-11T10:15:00Z",
      updated_at: "2026-10-11T10:15:00Z",
      etag: "e-1",
      target: { kind: "trace", trace_id: "0af7651916cd43dd8448eb211c80319c" },
      text: "slow cold start",
    },
    own: {},
    baseRequired: "etag",
  },
  "Common.Errors.PreconditionFailedError": {
    body: problemDetails("precondition-failed", "precondition_failed", "Precondition Failed", 412),
    own: { current_etag: "e-2" },
    baseRequired: "status",
  },
  "Common.Errors.PreconditionRequiredError": {
    body: problemDetails("precondition-required", "precondition_required", "Precondition Required", 428),
    own: { required_header: "If-Match" },
    baseRequired: "status",
  },
  "OTel.Traces.Trace": {
    body: {
      trace_id: "0af7651916cd43dd8448eb211c80319c",
      span_count: 0,
      duration_ns: "1500000",
      start_time: "2026-07-28T10:15:00Z",
      end_time: "2026-07-28T10:15:00.001500Z",
      services: ["qyl-collector"],
      has_error: false,
      spans: [],
    },
    own: {},
    baseRequired: "trace_id",
  },
  "SavedQueries.SavedQuery": {
    body: {
      id: "sq-1",
      created_at: "2026-10-11T10:15:00Z",
      updated_at: "2026-10-11T10:15:00Z",
      etag: "e-1",
      name: "errors last hour",
      filter: { signal: "traces", errors_only: true, lookback_minutes: 60 },
    },
    own: { description: "every failing trace" },
    baseRequired: "id",
  },
  "Workbench.WorkbenchSessionBootstrapResponse": {
    body: {
      id: "wbs-1",
      principal: { id: "local-user", display_name: "Local user", local: true },
      workspace_ids: ["ws-1"],
      active_workspace_id: "ws-1",
      created_at: "2026-07-28T10:15:00Z",
      expires_at: "2026-07-28T22:15:00Z",
    },
    own: {},
    baseRequired: "principal",
  },
  "Workbench.WorkbenchSuiteRunRequest": {
    body: evaluationRunRequest, own: { selected_test_case_ids: ["tc-1"] }, baseRequired: "idempotency_key",
  },
  "Workbench.WorkbenchTestCaseRunRequest": {
    body: evaluationRunRequest, own: {}, baseRequired: "idempotency_key",
  },
};

const derivedDefinitions = Object.entries(contractSchema.$defs)
  .filter(([, definition]) =>
    definition.type === "object" &&
    Array.isArray(definition.allOf) &&
    definition.allOf.every((entry) => typeof entry?.$ref === "string"))
  .map(([name]) => name)
  .sort((a, b) => a.localeCompare(b));
const casedDefinitions = Object.keys(inheritanceCases).sort((a, b) => a.localeCompare(b));
if (JSON.stringify(derivedDefinitions) !== JSON.stringify(casedDefinitions)) {
  throw new Error(
    "The `extends` models in the published schema and the inheritance cases in this gate differ.\n" +
    `  published: ${derivedDefinitions.join(", ")}\n  cased:     ${casedDefinitions.join(", ")}\n` +
    "Add a case for each new derived model (base fields, one own property, the base-required field to drop).",
  );
}

const inheritanceFailures = [];
for (const [definition, { body, own, baseRequired }] of Object.entries(inheritanceCases)) {
  const schema = publishedContractSchema(definition);
  const judge = (fixture, expected, why) => {
    if (schema.safeParse(fixture).success !== expected) {
      inheritanceFailures.push(`${definition}: ${why} must be ${expected ? "accepted" : "rejected"}`);
    }
  };
  judge(body, true, "the inherited base fields");
  if (Object.keys(own).length > 0) judge({ ...body, ...own }, true, `its own ${Object.keys(own).join(", ")}`);
  judge({ ...body, ...own, invented: true }, false, "an undeclared key");
  const withoutBaseRequired = { ...body };
  delete withoutBaseRequired[baseRequired];
  judge(withoutBaseRequired, false, `a body missing the base-required \`${baseRequired}\``);
}
if (inheritanceFailures.length > 0) {
  throw new Error(
    `${inheritanceFailures.length} inheritance checks failed. Inheritance flattening is not sealing the ` +
    "derived object or is losing the base's key set; `unevaluatedProperties: { not: {} }` must survive as " +
    `\`additionalProperties: false\` with the base's properties and required inlined:\n  ${
      inheritanceFailures.join("\n  ")}`,
  );
}

console.log(
  `Verified ${definitionNames.length} published definitions build as Zod schemas, ` +
  `${exercisedFixtures.length} contract fixtures across ` +
  `${new Set(exercisedFixtures.map((entry) => entry.definition)).size} definitions agree with the published ` +
  `JSON Schema, and RFC 3339 date-times, 64-bit integers, and sealed inheritance across ` +
  `${derivedDefinitions.length} derived models hold.`,
);
