// Type-level probe for the published npm package, copied verbatim into a clean
// consumer project by scripts/verify-consumers.mjs and checked there with
// `tsc --noEmit --strict`. It is excluded from every in-repo tsconfig on
// purpose: compiled here it would resolve to generated/ts-types rather than the
// installed package.
//
// There are no runtime assertions in this file. Everything it proves, it proves
// by compiling — including the @ts-expect-error, which fails the build if the
// contract ever starts accepting a bare number as an attribute value.
import type {
    Attribute,
    AttributeValue,
    EntityRef,
    LogRecord,
    Resource,
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
    schema_url: "https://opentelemetry.io/schemas/1.43.0",
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

void [
    eventLog,
    emptyAttribute,
    intAttribute,
    doubleAttribute,
    kvlistAttribute,
    entityRef,
    resource,
    invalidAttribute,
];
