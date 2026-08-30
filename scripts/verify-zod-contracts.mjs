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
if (unixNanos.safeParse("1.5").success || unixNanos.safeParse(1742000000123456789).success) {
  throw new Error("Common.UnixNanos must reject non-integral strings and unencoded numbers.");
}
const byteSize = publishedContractSchema("Common.ByteSize");
// 2^53 + 1: the first integer JavaScript numbers cannot represent exactly, and
// the boundary Zod's int64 conversion would have refused.
if (!byteSize.safeParse(9007199254740993).success) {
  throw new Error(
    "Common.ByteSize (integer/int64) must accept a value above 2^53. Zod's int64 range check leaked back in; " +
    "the adapter converts integer int64/uint64 to `type: number` with `multipleOf: 1` to keep it out.",
  );
}
if (byteSize.safeParse(1.5).success) {
  throw new Error("Common.ByteSize must still reject a fractional value.");
}

// 5. Sealed objects stay sealed through `allOf` inheritance. Building the
//    derivative as an intersection instead of a flattened object silently
//    reopens it, and nothing else in this gate would notice.
const badGateway = publishedContractSchema("Common.Errors.BadGatewayError");
const badGatewayBody = { type: "about:blank", title: "Bad Gateway", status: 502 };
if (!badGateway.safeParse(badGatewayBody).success) {
  throw new Error("Common.Errors.BadGatewayError must accept an inherited ProblemDetails body.");
}
if (!badGateway.safeParse({ ...badGatewayBody, dependency: "storage" }).success) {
  throw new Error("Common.Errors.BadGatewayError must accept its own declared `dependency` property.");
}
if (badGateway.safeParse({ ...badGatewayBody, invented: true }).success) {
  throw new Error(
    "Common.Errors.BadGatewayError accepted an undeclared key. Inheritance flattening is not sealing the " +
    "derived object; `unevaluatedProperties: { not: {} }` must survive as `additionalProperties: false`.",
  );
}

console.log(
  `Verified ${definitionNames.length} published definitions build as Zod schemas, ` +
  `${exercisedFixtures.length} contract fixtures across ` +
  `${new Set(exercisedFixtures.map((entry) => entry.definition)).size} definitions agree with the published ` +
  `JSON Schema, and RFC 3339 date-times, 64-bit integers, and inherited object sealing hold.`,
);
