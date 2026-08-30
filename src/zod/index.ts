// Runtime validators for the contracts this package publishes.
//
// The JSON Schema in generated/json-schema/qyl-api-schema.json is the artifact a
// validator should be derived from, not a second hand-maintained copy of it: a
// contract change that a consumer forgets to mirror is exactly the failure this
// module exists to make impossible. Everything below is therefore a translation
// layer over `z.fromJSONSchema`, not a schema in its own right.
//
// The package's own schema is reached by self-reference through the "exports"
// map, so this file resolves the same artifact from source, from
// generated/zod-runtime, and from inside an installed node_modules copy.
import contractJsonSchema from "@ancplua/qyl-api-schema/json-schema" with { type: "json" };
import { z } from "zod";

type JsonSchemaObject = Record<string, unknown>;

/**
 * Rewrite the published JSON Schema into the subset `z.fromJSONSchema` accepts,
 * preserving the contract's meaning exactly. Three published constructs need it:
 *
 * - `unevaluatedProperties` — `z.fromJSONSchema` rejects the keyword outright.
 *   The emitted schemas only ever use it to seal an object, which
 *   `additionalProperties` expresses for the same shapes.
 * - `allOf` inheritance — a derived object carries a single `$ref` base plus its
 *   own properties. Zod builds that as an intersection, and an intersection of a
 *   sealed base with a sealed extension accepts neither side's extra keys but
 *   also loses the base's own key set, so the derived object stops rejecting
 *   unknown keys. Flattening the base into the derivative keeps one sealed
 *   object with the full key set.
 * - 64-bit integers — Zod's `int64` conversion adds a +/-2^53 range check. The
 *   contract has no such bound (Unix nanosecond timestamps exceed it), so the
 *   integer rule is kept as `multipleOf: 1` and the format is dropped.
 *
 * `format: "date-time"` is deliberately left untouched: Zod 4.5's conversion is
 * already RFC 3339 offset-aware (it accepts `+02:00`, requires seconds, and
 * rejects colon-less offsets). scripts/verify-zod-contracts.mjs pins that.
 * One consequence for consumers that republish a validator through
 * `z.toJSONSchema`: the output carries `format: "date-time"` next to the RFC
 * 3339 pattern, so a pinned snapshot of such output changes when a consumer
 * moves onto this module.
 */
function adaptPublishedSchemaForZod(schemaNode: unknown): JsonSchemaObject {
  if (typeof schemaNode !== "object" || schemaNode === null || Array.isArray(schemaNode)) {
    throw new Error("Published Qyl JSON Schema root must be an object");
  }

  const root = schemaNode as JsonSchemaObject;
  const sourceDefinitions = asSchemaRecord(root.$defs, "$defs");
  const definitionCache = new Map<string, JsonSchemaObject>();
  const resolvingDefinitions = new Set<string>();

  const definition = (name: string): JsonSchemaObject => {
    const cached = definitionCache.get(name);
    if (cached) return cached;
    // Inheritance is flattened by inlining the base, so a cycle would recurse
    // forever rather than fail; a $ref cycle that is not inheritance is fine and
    // never reaches here.
    if (resolvingDefinitions.has(name)) {
      throw new Error(`Published Qyl JSON Schema has an inheritance cycle at '${name}'`);
    }
    const source = sourceDefinitions[name];
    if (source === undefined) {
      throw new Error(`Published Qyl JSON Schema is missing definition '${name}'`);
    }
    resolvingDefinitions.add(name);
    const adapted = adaptNode(source);
    resolvingDefinitions.delete(name);
    definitionCache.set(name, adapted);
    return adapted;
  };

  const adaptNode = (node: unknown): JsonSchemaObject => {
    if (typeof node !== "object" || node === null || Array.isArray(node)) {
      throw new Error("Expected a JSON Schema object node");
    }
    const source = node as JsonSchemaObject;
    const inheritedDefinitions = inheritedObjectDefinitions(source, definition);
    const adapted: JsonSchemaObject = {};

    if (inheritedDefinitions.length > 0) {
      let inheritedAdditionalProperties: unknown;
      for (const inherited of inheritedDefinitions) {
        const existingProperties = optionalSchemaRecord(adapted.properties);
        const inheritedProperties = optionalSchemaRecord(inherited.properties);
        const existingRequired = stringArray(adapted.required);
        const inheritedRequired = stringArray(inherited.required);
        Object.assign(adapted, inherited);
        adapted.properties = { ...existingProperties, ...inheritedProperties };
        adapted.required = [...new Set([...existingRequired, ...inheritedRequired])];
        inheritedAdditionalProperties = inherited.additionalProperties;
      }
      // The derivative documents itself and seals itself; inheriting either
      // would describe the wrong type and could reopen a sealed object.
      delete adapted.description;
      delete adapted.additionalProperties;

      for (const [keyword, child] of Object.entries(source)) {
        if (
          keyword === "allOf" ||
          keyword === "properties" ||
          keyword === "required" ||
          keyword === "unevaluatedProperties"
        ) {
          continue;
        }
        adapted[keyword] = adaptValue(child);
      }
      adapted.properties = {
        ...optionalSchemaRecord(adapted.properties),
        ...adaptSchemaRecord(source.properties),
      };
      const required = [
        ...new Set([...stringArray(adapted.required), ...stringArray(source.required)]),
      ];
      if (required.length > 0) adapted.required = required;
      else delete adapted.required;

      if ("unevaluatedProperties" in source) {
        adapted.additionalProperties = adaptUnevaluatedProperties(source.unevaluatedProperties);
      } else if (inheritedAdditionalProperties !== undefined) {
        adapted.additionalProperties = inheritedAdditionalProperties;
      }
    } else {
      for (const [keyword, child] of Object.entries(source)) {
        if (keyword === "unevaluatedProperties") continue;
        adapted[keyword] = adaptValue(child);
      }
      if ("unevaluatedProperties" in source) {
        adapted.additionalProperties = adaptUnevaluatedProperties(source.unevaluatedProperties);
      }
    }

    if (
      source.type === "integer" &&
      (source.format === "int64" || source.format === "uint64")
    ) {
      adapted.type = "number";
      adapted.multipleOf = 1;
      delete adapted.format;
    }
    return adapted;
  };

  const adaptValue = (value: unknown): unknown => {
    if (Array.isArray(value)) return value.map(adaptValue);
    if (typeof value === "object" && value !== null) return adaptNode(value);
    return value;
  };

  const adaptSchemaRecord = (value: unknown): JsonSchemaObject => {
    const record = optionalSchemaRecord(value);
    return Object.fromEntries(
      Object.entries(record).map(([name, child]) => [name, adaptValue(child)]),
    );
  };

  const adaptUnevaluatedProperties = (value: unknown): unknown =>
    isFalseSchema(value) ? false : adaptValue(value);

  const rootWithoutDefinitions = { ...root };
  delete rootWithoutDefinitions.$defs;
  const adaptedRoot = adaptNode(rootWithoutDefinitions);
  // Re-attached after adaptation so every `#/$defs/...` reference in an adapted
  // node resolves against the adapted definitions rather than the source ones.
  adaptedRoot.$defs = Object.fromEntries(
    Object.keys(sourceDefinitions).map((name) => [name, definition(name)]),
  );
  return adaptedRoot;
}

/**
 * The base definitions a node inherits from, or none if this is not the
 * single-`$ref`-base object inheritance the emitter produces. Anything else —
 * an `allOf` of inline schemas, a non-object base — is left for Zod to build as
 * a real intersection.
 */
function inheritedObjectDefinitions(
  source: JsonSchemaObject,
  resolve: (name: string) => JsonSchemaObject,
): JsonSchemaObject[] {
  if (source.type !== "object" || !Array.isArray(source.allOf)) return [];
  const names = source.allOf.map((entry) => definitionNameFromRef(entry));
  if (names.some((name) => name === undefined)) return [];
  const inherited = names.map((name) => resolve(name!));
  return inherited.every((definition) => definition.type === "object") ? inherited : [];
}

function definitionNameFromRef(value: unknown): string | undefined {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return undefined;
  const record = value as JsonSchemaObject;
  if (Object.keys(record).length !== 1 || typeof record.$ref !== "string") return undefined;
  const prefix = "#/$defs/";
  return record.$ref.startsWith(prefix) ? record.$ref.slice(prefix.length) : undefined;
}

function asSchemaRecord(value: unknown, context: string): JsonSchemaObject {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error(`Published Qyl JSON Schema ${context} must be an object`);
  }
  return value as JsonSchemaObject;
}

function optionalSchemaRecord(value: unknown): JsonSchemaObject {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as JsonSchemaObject
    : {};
}

function stringArray(value: unknown): string[] {
  return Array.isArray(value) && value.every((item) => typeof item === "string")
    ? value
    : [];
}

/** `{ "not": {} }` — how the emitter spells "no further properties". */
function isFalseSchema(value: unknown): boolean {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return false;
  const record = value as JsonSchemaObject;
  const not = record.not;
  return Object.keys(record).length === 1 &&
    typeof not === "object" &&
    not !== null &&
    !Array.isArray(not) &&
    Object.keys(not).length === 0;
}

const zodCompatibleContractJsonSchema = adaptPublishedSchemaForZod(contractJsonSchema);
const zodCompatibleDefinitions = asSchemaRecord(zodCompatibleContractJsonSchema.$defs, "$defs");

/**
 * A published contract type as it looks *before* validation: branded identity
 * scalars are still plain strings and arrays may be readonly, because branding
 * is what `parse` produces rather than what a caller can construct.
 *
 * Annotating a projection with `satisfies ContractInput<T>` moves the wire-name
 * check from a runtime `parse` throw to a compile error, so a property spelled
 * in an internal camelCase instead of the contract's snake_case cannot reach a
 * response at all.
 */
export type ContractInput<TContract> =
  TContract extends { readonly __brand: string } ? string
    : TContract extends readonly (infer TElement)[] ? readonly ContractInput<TElement>[]
      : TContract extends (...args: never[]) => unknown ? TContract
        : TContract extends object ? { readonly [K in keyof TContract]: ContractInput<TContract[K]> }
          : TContract;

const publishedContractSchemas = new Map<string, z.ZodType<unknown>>();

/**
 * Build a strict runtime validator for one published contract definition.
 *
 * `definitionName` is a key of the published schema's `$defs` — the same name
 * the OpenAPI component and the generated C#/TypeScript DTOs carry, for example
 * `"OTel.Traces.Span"` or `"Common.Errors.ProblemDetails"`. Pair it with the
 * matching type from `@ancplua/qyl-api-schema/types`; the type argument is not
 * checked against the schema, so an unrelated one produces a validator that
 * lies about what it returns.
 *
 * Results are memoized per name: building a schema walks the whole definition,
 * and the returned validator is stateless.
 *
 * @throws Error if no such definition is published.
 *
 * @example
 * ```ts
 * import { publishedContractSchema } from "@ancplua/qyl-api-schema/zod";
 * import type { Span } from "@ancplua/qyl-api-schema/types";
 *
 * const SpanSchema = publishedContractSchema<Span>("OTel.Traces.Span");
 * const span = SpanSchema.parse(await response.json());
 * ```
 */
export function publishedContractSchema<TContract>(definitionName: string): z.ZodType<TContract> {
  const cached = publishedContractSchemas.get(definitionName);
  if (cached) return cached as z.ZodType<TContract>;
  if (!Object.hasOwn(zodCompatibleDefinitions, definitionName)) {
    throw new Error(`Published Qyl JSON Schema has no '${definitionName}' definition`);
  }
  const schema = z.fromJSONSchema({
    $schema: zodCompatibleContractJsonSchema.$schema,
    $defs: zodCompatibleDefinitions,
    $ref: `#/$defs/${definitionName}`,
  } as unknown as Parameters<typeof z.fromJSONSchema>[0]) as z.ZodType<TContract>;
  publishedContractSchemas.set(definitionName, schema as z.ZodType<unknown>);
  return schema;
}

const definitionNames: readonly string[] = Object.freeze(
  Object.keys(zodCompatibleDefinitions).sort(),
);

/**
 * Every definition name {@link publishedContractSchema} accepts, sorted.
 *
 * Enumerating the published surface is how a consumer proves it covers all of
 * it — a contract definition that gains no validator is otherwise invisible.
 */
export function contractDefinitionNames(): readonly string[] {
  return definitionNames;
}

/** The published schema's `$id`, for reporting which contract a validator came from. */
export const contractJsonSchemaId: string = typeof contractJsonSchema.$id === "string"
  ? contractJsonSchema.$id
  : "";
