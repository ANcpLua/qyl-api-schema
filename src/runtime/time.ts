// Absolute wire timestamps are unsigned 64-bit nanosecond counts encoded as decimal strings.
// They exceed Number.MAX_SAFE_INTEGER, so every operation goes through BigInt and only the
// millisecond result is a number.

/** The exact nanosecond count. */
export function parseUnixNanos(nanos: string): bigint {
  return BigInt(nanos);
}

/** Ascending comparator, exact at nanosecond resolution. */
export function compareUnixNanos(a: string, b: string): number {
  const left = BigInt(a);
  const right = BigInt(b);
  return left < right ? -1 : left > right ? 1 : 0;
}

/** Exact nanosecond delta as a number; safe for any span shorter than about 104 days. */
export function unixNanosDelta(fromNanos: string, toNanos: string): number {
  return Number(BigInt(toNanos) - BigInt(fromNanos));
}

/** Epoch milliseconds, floored in BigInt so no precision is assumed. */
export function unixNanosToEpochMs(nanos: string): number {
  return Number(BigInt(nanos) / 1_000_000n);
}

/** ISO-8601 at millisecond resolution. */
export function unixNanosToIso(nanos: string): string {
  return new Date(unixNanosToEpochMs(nanos)).toISOString();
}

/** The wire form of an epoch-millisecond instant. */
export function epochMsToUnixNanos(epochMs: number): string {
  return (BigInt(Math.round(epochMs)) * 1_000_000n).toString();
}
