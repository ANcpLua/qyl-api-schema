// Type-level probe for the published npm package, copied verbatim into a clean
// consumer project by scripts/verify-consumers.mjs and checked there with
// `tsc --noEmit --strict`. It is excluded from every in-repo tsconfig on
// purpose: compiled here it would resolve to generated/ts-types rather than the
// installed package.
//
// There are no runtime assertions in this file. Everything it proves, it proves
// by compiling — including the @ts-expect-error, which fails the build if the
// contract ever starts accepting a bare number as an attribute value.
import { CONTRACT_REVISION } from "@ancplua/qyl-api-schema/types";
import { publishedContractSchema } from "@ancplua/qyl-api-schema/zod";
import type { z } from "zod";
import type {
    Attribute,
    AttributeValue,
    CiLogOutput,
    EntityRef,
    HealthReport,
    LogRecord,
    Resource,
    SessionEvent,
    SessionId,
} from "@ancplua/qyl-api-schema/types";

const eventLog: LogRecord = {
    time_unix_nano: "2",
    observed_time_unix_nano: "3",
    severity_number: 9,
    body: { string_value: "evaluation completed" },
    event_name: "gen_ai.evaluation.result",
    resource: { service_name: "evaluator" },
};

const emptyAttribute: Attribute = { key: "empty", value: null };

const intAttribute: Attribute = {
    key: "int",
    value: { type: "int", value: "9223372036854775807" },
};

const doubleAttribute: Attribute = {
    key: "double",
    value: { type: "double", value: "Infinity" },
};

const kvlistAttribute: Attribute = {
    key: "kvlist",
    value: {
        type: "kvlist",
        values: { empty: null, nested: [intAttribute.value, doubleAttribute.value] },
    },
};

const entityRef: EntityRef = {
    schema_url: "https://opentelemetry.io/schemas/1.44.0",
    type: "service",
    id_keys: ["service.instance.id"],
    description_keys: ["service.version"],
};

const resource: Resource = {
    service_name: "orders",
    attributes: [emptyAttribute, intAttribute, doubleAttribute, kvlistAttribute],
    entity_refs: [entityRef],
};

// @ts-expect-error Attribute integers require the tagged lossless representation.
const invalidAttribute: AttributeValue = 1;

// Compiling this is the whole assertion: the revision is a required member of
// the health surface under its snake_case wire name, and the package exports the
// value a client compares against it.
const healthReport: HealthReport = {
    status: "healthy",
    total_duration_ms: 0,
    entries: {},
    contract_revision: CONTRACT_REVISION,
};

// The runtime validator is typed by the contract type it is asked for, so a
// consumer gets the published DTO out of `parse` rather than `unknown`. Both
// annotations are the assertion: neither compiles if the ./zod export stops
// carrying the type through.
const healthReportSchema: z.ZodType<HealthReport> =
    publishedContractSchema<HealthReport>("Health.HealthReport");
const parsedHealthReport: HealthReport = healthReportSchema.parse(healthReport);

const ciLog: CiLogOutput = {
    // A CI run id is the session identity, so it keeps that scalar rather than
    // becoming a second spelling of it.
    run_id: "nuget-publish-42" as SessionId,
    phases: [{ leg: "macos-latest", phase: "pack", status: "error", duration_ms: 12 }],
    mode: "live",
};

const sessionEvent: SessionEvent = {
    event_name: "session.start",
    session_id: "sess-0001" as SessionId,
    timestamp: "2026-07-28T12:34:56+00:00",
    event_domain: "session",
};

void [
    eventLog,
    emptyAttribute,
    intAttribute,
    doubleAttribute,
    kvlistAttribute,
    entityRef,
    resource,
    invalidAttribute,
    healthReport,
    parsedHealthReport,
    ciLog,
    sessionEvent,
];
