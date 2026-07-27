// =============================================================================
// The qyl wire-naming policy, in one place.
// =============================================================================
// Every rule in this library reads its definition of "correct" from here, so
// the convention exists exactly once and cannot drift between rules.
// =============================================================================

import type { Model, ModelProperty, Namespace, Scalar, Type } from "@typespec/compiler";
import { isArrayModelType } from "@typespec/compiler";

/** Namespace that owns the product contract. Rules ignore everything outside it. */
export const PRODUCT_NAMESPACE = "Qyl.Api.Contracts";

/** Namespace declaring the shared identity scalars. */
export const COMMON_NAMESPACE = "Qyl.Api.Contracts.Common";

/** The single legal shape of a JSON body property name and of a query/path parameter name. */
export const SNAKE_CASE = /^[a-z][a-z0-9]*(_[a-z0-9]+)*$/;

/**
 * camelCase -> snake_case, the only casing transform in the contract.
 *
 * `traceId` -> `trace_id`, `p95DurationMs` -> `p95_duration_ms`,
 * `k8sPodUid` -> `k8s_pod_uid`, `wwwAuthenticate` -> `www_authenticate`.
 */
export function snakeCase(name: string): string {
  return name
    .replace(/([a-z0-9])([A-Z])/g, "$1_$2")
    .replace(/([A-Z]+)([A-Z][a-z])/g, "$1_$2")
    .toLowerCase();
}

// =============================================================================
// Wire-name derivation
// =============================================================================
// A wire name is `snakeCase(propertyName)` unless it appears below. Deriving it
// is what makes casing a non-decision: there is no per-property judgement call
// to get wrong, and a reviewer never has to ask whether a given spelling was
// intended. The exceptions are the cases where the wire name genuinely differs
// from the property name — never a casing fix, which the derivation already
// covers.

/** `Model.property` -> the wire name it ships, with the reason it differs. */
export interface WireNameException {
  readonly wire: string;
  readonly reason: string;
}

export const WIRE_NAME_EXCEPTIONS: Readonly<Record<string, WireNameException>> = {
  // The TypeSpec names are prefixed only to stay unique inside the model; on the
  // wire the object already *is* the scope, so OTLP names the fields bare.
  "InstrumentationScope.scopeName": { wire: "name", reason: "OTLP InstrumentationScope.name" },
  "InstrumentationScope.scopeVersion": { wire: "version", reason: "OTLP InstrumentationScope.version" },
  "InstrumentationScope.scopeAttributes": { wire: "attributes", reason: "OTLP InstrumentationScope.attributes" },
  // RFC 7807 fixes this member name; `type` is reserved in TypeSpec.
  "ProblemDetails.problemType": { wire: "type", reason: "RFC 7807 problem-details member" },
  // GenAI is one token in semantic conventions, so it does not split.
  "SessionStats.sessionsWithGenAi": { wire: "sessions_with_genai", reason: "'genai' is a single semconv token" },
};

/** The wire name a property must ship: derived, or the registered exception. */
export function expectedWireName(modelName: string, propertyName: string): string {
  return WIRE_NAME_EXCEPTIONS[`${modelName}.${propertyName}`]?.wire ?? snakeCase(propertyName);
}

// =============================================================================
// Identity model
// =============================================================================
// A qyl identity is a scalar plus the property name it is always spelled with.
// Declaring both directions is the point: it makes "same value, different key"
// unrepresentable rather than merely discouraged.

export interface IdentityBinding {
  /** Scalar declared in `Qyl.Api.Contracts.Common`. */
  readonly scalar: string;
  /** The property name a single value of this identity uses when it is the subject. */
  readonly singular: string;
  /** The property name a collection of this identity uses when it is the subject. */
  readonly plural: string;
  /**
   * Names reserved for this identity: a property called one of these must be
   * typed as the scalar. This is an exact list, never an `endsWith("Id")` test —
   * the contract has ~25 other `*Id` properties (WorkbenchServerId,
   * WorkbenchExecutionId, …) that are their own types and must not be captured.
   */
  readonly reserved: readonly string[];
  /**
   * Qualified names that carry this identity while naming a *relationship* to it
   * rather than the subject itself — `parentSpanId`, `previousSessionId`. Each
   * one is registered here with the relationship it expresses.
   *
   * This is a closed list on purpose. A suffix test (`endsWith("TraceId")`)
   * would silently admit `candidateTraceId`, `rootTraceId`, and every future
   * coinage — which is how three spellings of one identity appeared in the first
   * place. A new edge is a deliberate one-line entry, not an emergent property.
   */
  readonly edges: Readonly<Record<string, string>>;
}

export const IDENTITIES: readonly IdentityBinding[] = [
  {
    scalar: "TraceId",
    singular: "traceId",
    plural: "traceIds",
    reserved: ["traceId", "traceIds"],
    // A UI selection pointing at one of the traces already in the response.
    edges: { selectedTraceId: "the trace the client has focused, within a listed set" },
  },
  {
    scalar: "SpanId",
    singular: "spanId",
    plural: "spanIds",
    reserved: ["spanId", "spanIds", "parentSpanId"],
    // The OTLP parent link; absent on a root span.
    edges: { parentSpanId: "the span this span is a child of" },
  },
  {
    scalar: "SessionId",
    singular: "sessionId",
    plural: "sessionIds",
    reserved: ["sessionId", "sessionIds", "previousSessionId"],
    edges: {
      // Session continuity across a reconnect.
      previousSessionId: "the session this one continues from",
      // A CI workflow run is emitted as one session; `ci_log` names it for the
      // agent in the run's own vocabulary while keeping the session identity.
      runId: "the CI workflow run whose telemetry is grouped under this session",
    },
  },
  {
    scalar: "UserId",
    singular: "userId",
    plural: "userIds",
    reserved: ["userId", "userIds"],
    edges: {},
  },
];

/** Property name -> the identity binding and arity that name is reserved for. */
export interface ReservedName {
  readonly identity: IdentityBinding;
  readonly array: boolean;
}

const RESERVED_NAMES = new Map<string, ReservedName>();
for (const identity of IDENTITIES) {
  for (const name of identity.reserved) {
    RESERVED_NAMES.set(name, { identity, array: name === identity.plural });
  }
}

/**
 * Names that are reserved for an identity scalar. A property carrying one of
 * these names must be typed as that scalar — never as a bare `string`.
 */
export function reservedNameFor(propertyName: string): ReservedName | undefined {
  return RESERVED_NAMES.get(propertyName);
}

/**
 * Whether a property carrying this identity may be spelled `name`.
 *
 * Exactly three spellings are legal: the bare token (`traceId`), its plural
 * (`traceIds`), or a registered edge (`parentSpanId`). Nothing is inferred.
 */
export function isAllowedIdentityName(
  identity: IdentityBinding,
  array: boolean,
  name: string,
): boolean {
  if (name === (array ? identity.plural : identity.singular)) return true;
  return Object.hasOwn(identity.edges, name);
}

/** How the allowed spelling reads in a diagnostic. */
export function describeAllowedNames(identity: IdentityBinding, array: boolean): string {
  const subject = `'${array ? identity.plural : identity.singular}'`;
  const edges = Object.keys(identity.edges);
  return edges.length === 0
    ? subject
    : `${subject} or a registered edge (${edges.map((edge) => `'${edge}'`).join(", ")})`;
}

// =============================================================================
// Type inspection
// =============================================================================

/** True when `type` is nested anywhere inside the named namespace. */
export function isInNamespace(type: Type, fullName: string): boolean {
  const segments = fullName.split(".");
  for (let ns = namespaceOf(type); ns; ns = ns.namespace) {
    if (matchesFrom(ns, segments)) return true;
  }
  return false;
}

function matchesFrom(leaf: Namespace, segments: readonly string[]): boolean {
  let cursor: Namespace | undefined = leaf;
  for (let i = segments.length - 1; i >= 0; i--) {
    if (!cursor || cursor.name !== segments[i]) return false;
    cursor = cursor.namespace;
  }
  return true;
}

function namespaceOf(type: Type): Namespace | undefined {
  if (type.kind === "Namespace") return type;
  if (type.kind === "ModelProperty") {
    return type.model ? namespaceOf(type.model) : undefined;
  }
  return "namespace" in type ? (type.namespace as Namespace | undefined) : undefined;
}

/** The full namespace path of a type, for diagnostics. */
export function namespaceName(type: Type): string {
  const parts: string[] = [];
  for (let ns = namespaceOf(type); ns?.name; ns = ns.namespace) parts.unshift(ns.name);
  return parts.join(".");
}

export interface ResolvedIdentity {
  readonly identity: IdentityBinding;
  readonly array: boolean;
}

/**
 * The shared identity scalar a property carries, if any — looking through
 * optionality and one level of array.
 */
export function identityOfProperty(property: ModelProperty): ResolvedIdentity | undefined {
  const type = property.type;
  if (type.kind === "Model" && isArrayModelType(type as Model)) {
    const element = (type as Model).indexer?.value;
    const identity = element ? identityOfType(element) : undefined;
    return identity && { identity, array: true };
  }
  const identity = identityOfType(type);
  return identity && { identity, array: false };
}

function identityOfType(type: Type): IdentityBinding | undefined {
  if (type.kind !== "Scalar") return undefined;
  const scalar = type as Scalar;
  if (!isInNamespace(scalar, COMMON_NAMESPACE)) return undefined;
  return IDENTITIES.find((candidate) => candidate.scalar === scalar.name);
}

/**
 * A scalar that could be mistaken for a shared identity because its name ends
 * with one — e.g. `WorkbenchSessionId` against `SessionId`.
 */
export function confusableIdentityFor(scalar: Scalar): IdentityBinding | undefined {
  if (isInNamespace(scalar, COMMON_NAMESPACE)) return undefined;
  return IDENTITIES.find(
    (candidate) => scalar.name !== candidate.scalar && scalar.name.endsWith(candidate.scalar),
  );
}

/** The doc phrase a confusable scalar must carry to declare its relationship. */
export function relationshipPhrase(identity: IdentityBinding): string {
  return `${COMMON_NAMESPACE}.${identity.scalar}`;
}
