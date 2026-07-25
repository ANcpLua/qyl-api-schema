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
// Identity model
// =============================================================================
// A qyl identity is a scalar plus the property name it is always spelled with.
// Declaring both directions is the point: it makes "same value, different key"
// unrepresentable rather than merely discouraged.

export interface IdentityBinding {
  /** Scalar declared in `Qyl.Api.Contracts.Common`. */
  readonly scalar: string;
  /** The property name a single value of this identity always uses. */
  readonly singular: string;
  /** The property name a collection of this identity always uses. */
  readonly plural: string;
  /**
   * Additional singular property names allowed for this scalar, each with the
   * relationship that justifies it. An identity may only be spelled more than
   * one way when the extra spelling names a *different edge* to the same thing.
   */
  readonly alternates: Readonly<Record<string, string>>;
}

export const IDENTITIES: readonly IdentityBinding[] = [
  {
    scalar: "TraceId",
    singular: "traceId",
    plural: "traceIds",
    alternates: {
      selectedTraceId: "the selection edge into a returned trace list, not the trace of the response",
    },
  },
  {
    scalar: "SpanId",
    singular: "spanId",
    plural: "spanIds",
    alternates: { parentSpanId: "the parent edge of a span, not the span itself" },
  },
  {
    scalar: "SessionId",
    singular: "sessionId",
    plural: "sessionIds",
    alternates: { previousSessionId: "the continuity edge to the preceding session" },
  },
  {
    scalar: "UserId",
    singular: "userId",
    plural: "userIds",
    alternates: {},
  },
];

/** Property name -> the identity binding and arity that name is reserved for. */
export interface ReservedName {
  readonly identity: IdentityBinding;
  readonly array: boolean;
}

const RESERVED_NAMES = new Map<string, ReservedName>();
for (const identity of IDENTITIES) {
  RESERVED_NAMES.set(identity.singular, { identity, array: false });
  RESERVED_NAMES.set(identity.plural, { identity, array: true });
  for (const alternate of Object.keys(identity.alternates)) {
    RESERVED_NAMES.set(alternate, { identity, array: false });
  }
}

/**
 * Names that are reserved for an identity scalar. A property carrying one of
 * these names must be typed as that scalar — never as a bare `string`.
 */
export function reservedNameFor(propertyName: string): ReservedName | undefined {
  return RESERVED_NAMES.get(propertyName);
}

/** Every property name this identity is allowed to be spelled with. */
export function allowedNamesFor(identity: IdentityBinding, array: boolean): string[] {
  return array ? [identity.plural] : [identity.singular, ...Object.keys(identity.alternates)];
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
