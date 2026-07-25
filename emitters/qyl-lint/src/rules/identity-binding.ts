// INV-1 and INV-2 — one identity, one type, one name, one key.
//
// The migration this rule guards existed because nothing tied an identity's
// scalar to the name it is spelled with. `SessionId` reached clients as
// `session.id`, `session_id`, and `sessionId`; `traceId` was declared as a bare
// `string` in errors.tsp and pagination.tsp, losing the 32-hex-character
// validation it has everywhere else. Both directions are checked here:
//
//   type -> name  a property carrying a shared identity scalar uses that
//                 identity's property name (or a declared alternate that names
//                 a genuinely different edge, such as `parentSpanId`)
//   name -> type  a property using an identity's reserved name is typed as that
//                 scalar and never as a bare `string`
//
// Together with wire-name-snake-case these make "same value, different key"
// unrepresentable rather than merely discouraged: the name follows from the
// type, and the wire key follows from the name.

import type { Model, ModelProperty } from "@typespec/compiler";
import { createRule, getTypeName, isArrayModelType, paramMessage, resolveEncodedName } from "@typespec/compiler";
import { isStatusCode } from "@typespec/http";
import {
  COMMON_NAMESPACE,
  PRODUCT_NAMESPACE,
  allowedNamesFor,
  identityOfProperty,
  isInNamespace,
  reservedNameFor,
  snakeCase,
} from "../policy.js";

export const identityBindingRule = createRule({
  name: "identity-binding",
  severity: "warning",
  description:
    "A qyl identity has one scalar, one property name, and one wire key everywhere it appears.",
  messages: {
    name: paramMessage`Property '${"property"}' carries the shared identity '${"scalar"}' but is not named ${"allowed"}. One identity is spelled one way across the whole contract, so a generic correlation helper is possible and grep finds every use.`,
    arity: paramMessage`Property '${"property"}' is a collection of '${"scalar"}' and must be named '${"expected"}'.`,
    type: paramMessage`Property '${"property"}' uses the name reserved for the '${"scalar"}' identity but is typed '${"actual"}'. Type it as '${"canonical"}' so it keeps that scalar's pattern and length validation instead of accepting any string.`,
    elementType: paramMessage`Property '${"property"}' uses the name reserved for the '${"scalar"}' identity but its elements are typed '${"actual"}'. Type it as '${"canonical"}[]'.`,
    rename: paramMessage`Identity property '${"property"}' is renamed on the wire to '${"wire"}'. An identity's wire key always follows from its name: use '${"expected"}'.`,
  },
  create(context) {
    const seen = new Set<unknown>();

    return {
      modelProperty: (property: ModelProperty) => {
        if (!isInNamespace(property, PRODUCT_NAMESPACE)) return;
        if (isStatusCode(context.program, property)) return;
        if (seen.has(property.node)) return;
        seen.add(property.node);

        const carried = identityOfProperty(property);
        const reserved = reservedNameFor(property.name);

        // type -> name
        if (carried) {
          const allowed = allowedNamesFor(carried.identity, carried.array);
          if (!allowed.includes(property.name)) {
            context.reportDiagnostic({
              messageId: carried.array ? "arity" : "name",
              target: property,
              format: {
                property: property.name,
                scalar: carried.identity.scalar,
                expected: carried.identity.plural,
                allowed: allowed.map((name) => `'${name}'`).join(" or "),
              },
            });
          }

          // An identity never carries a wire alias: its key is snake(name).
          const wire = resolveEncodedName(context.program, property, "application/json");
          const expected = snakeCase(property.name);
          if (wire !== expected && wire !== property.name) {
            context.reportDiagnostic({
              messageId: "rename",
              target: property,
              format: { property: property.name, wire, expected },
            });
          }
        }

        // name -> type
        if (reserved && !carried) {
          const isArray = property.type.kind === "Model" && isArrayModelType(property.type as Model);
          const actual = isArray
            ? getTypeName((property.type as Model).indexer!.value)
            : getTypeName(property.type);
          context.reportDiagnostic({
            messageId: reserved.array || isArray ? "elementType" : "type",
            target: property,
            format: {
              property: property.name,
              scalar: reserved.identity.scalar,
              canonical: `${COMMON_NAMESPACE}.${reserved.identity.scalar}`,
              actual,
            },
          });
        }
      },
    };
  },
});
