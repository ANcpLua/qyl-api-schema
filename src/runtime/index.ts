// Presentation policy over the generated AttributeValue matcher.
//
// The matcher in generated/ts-types/runtime.ts is emitted from the TypeSpec union node, so it
// cannot drift from the C# converter. What a variant *means* on screen or in a tool's text
// is a decision, and decisions are written here, once, over an exhaustive match: adding a
// variant to the contract fails this file's compile until the policy names it.
import type { AttributeValue } from "@ancplua/qyl-api-schema/types";
import { matchAttributeValue } from "../../generated/ts-runtime/runtime.js";

export * from "./time.js";

export {
  AttributeObjectValueTags,
  isAttributeObjectValue,
  matchAttributeValue,
} from "../../generated/ts-runtime/runtime.js";
export type { AttributeObjectValueTag, AttributeValueHandlers } from "../../generated/ts-runtime/runtime.js";

/** An AttributeValue with the wire tags removed: what a reader sees, not how it travelled. */
export type DecodedAttributeValue =
  | null
  | string
  | boolean
  | number
  | DecodedAttributeValue[]
  | { readonly type: "bytes"; readonly base64: string }
  | { readonly [key: string]: DecodedAttributeValue };

/** Strip the tags. int64 stays text so no digit is lost; bytes stay marked so they never read as a string. */
export function decodeAttributeValue(value: AttributeValue): DecodedAttributeValue {
  return matchAttributeValue<DecodedAttributeValue>(value, {
    emptyValue: () => null,
    stringValue: (text) => text,
    boolValue: (flag) => flag,
    arrayValue: (items) => items.map(decodeAttributeValue),
    int: (tagged) => tagged.value,
    double: (tagged) => tagged.value,
    bytes: (tagged) => ({ type: "bytes", base64: tagged.base64 }),
    kvlist: (tagged) =>
      Object.fromEntries(Object.entries(tagged.values).map(([key, nested]) => [key, decodeAttributeValue(nested)])),
  });
}

/** One line of text for any value; never `[object Object]`. */
export function formatAttributeValue(value: AttributeValue): string {
  const decoded = decodeAttributeValue(value);
  if (decoded === null) return "null";
  if (typeof decoded === "string") return decoded;
  if (typeof decoded === "boolean" || typeof decoded === "number") return String(decoded);
  return JSON.stringify(decoded);
}

/** The value when it is a plain string, otherwise undefined. */
export function attributeString(value: AttributeValue | undefined): string | undefined {
  return typeof value === "string" ? value : undefined;
}

/** A JavaScript number when one can represent the value exactly, otherwise undefined. */
export function attributeNumber(value: AttributeValue | undefined): number | undefined {
  if (value === undefined) return undefined;
  return matchAttributeValue<number | undefined>(value, {
    emptyValue: () => undefined,
    stringValue: () => undefined,
    boolValue: () => undefined,
    arrayValue: () => undefined,
    int: (tagged) => {
      const parsed = Number(tagged.value);
      return Number.isSafeInteger(parsed) ? parsed : undefined;
    },
    double: (tagged) => Number(tagged.value),
    bytes: () => undefined,
    kvlist: () => undefined,
  });
}

/**
 * A stable text identity for grouping and hashing: the canonical wire JSON with object keys
 * sorted. Two values with the same identity are the same attribute value.
 */
export function attributeIdentity(value: AttributeValue): string {
  return JSON.stringify(sortKeys(value));
}

function sortKeys(value: AttributeValue): unknown {
  return matchAttributeValue<unknown>(value, {
    emptyValue: () => null,
    stringValue: (text) => text,
    boolValue: (flag) => flag,
    arrayValue: (items) => items.map(sortKeys),
    int: (tagged) => ({ type: "int", value: tagged.value }),
    double: (tagged) => ({ type: "double", value: tagged.value }),
    bytes: (tagged) => ({ base64: tagged.base64, type: "bytes" }),
    kvlist: (tagged) => ({
      type: "kvlist",
      values: Object.fromEntries(Object.entries(tagged.values).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)).map(([key, nested]) => [key, sortKeys(nested)])),
    }),
  });
}
