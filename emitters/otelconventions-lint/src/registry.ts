// Copyright (c) 2025-2026 ancplua
// SPDX-License-Identifier: MIT

import registryJson from "../data/otel-attribute-registry.json" with { type: "json" };
import type { AncpluaAttrPrimitive } from "./index.js";

interface RawOtelAttr {
    name: string;
    type: string;
    stability: string;
    deprecated: boolean;
    group: string;
}

export interface OtelAttr {
    name: string;
    type: AncpluaAttrPrimitive;
    stability: "experimental" | "stable" | "deprecated" | "development";
    deprecated: boolean;
    group: string;
}

/**
 * Reserved top-level OTel namespaces. Any attribute that starts with one of
 * these prefixes (followed by a `.`) is owned by upstream and may not be
 * redeclared under `@ancpluaAttr`.
 *
 * Source: https://opentelemetry.io/docs/specs/semconv/ — extend when Weaver
 * advances; do not let the list drift silently.
 */
export const RESERVED_PREFIXES: readonly string[] = [
    "gen_ai.",
    "http.",
    "db.",
    "rpc.",
    "network.",
    "server.",
    "client.",
    "url.",
    "user_agent.",
    "code.",
    "exception.",
    "event.",
    "log.",
    "messaging.",
    "faas.",
    "cloud.",
    "aws.",
    "azure.",
    "gcp.",
    "k8s.",
    "container.",
    "host.",
    "os.",
    "process.",
    "thread.",
    "service.",
    "deployment.",
    "telemetry.",
    "otel.",
    "session.",
    "enduser.",
    "feature_flag.",
    "error.",
    "file.",
    "peer.",
    "source.",
    "destination.",
    "device.",
    "browser.",
    "disk.",
    "hw.",
    "jvm.",
    "nodejs.",
    "dotnet.",
    "aspnetcore.",
    "signalr.",
    "v8js.",
    "webengine.",
    "android.",
    "ios.",
] as const;

function normalizeType(raw: string): AncpluaAttrPrimitive {
    // Weaver emits "int" as a 64-bit integer in OTel attribute space; collapse to our
    // canonical "long". Any other exotic upstream type collapses to "string" since
    // the library only cares about primitive classification for drift checks.
    switch (raw) {
        case "int":
            return "long";
        case "long":
            return "long";
        case "double":
            return "double";
        case "boolean":
            return "boolean";
        case "string[]":
            return "string[]";
        case "string":
            return "string";
        default:
            return "string";
    }
}

function normalizeStability(raw: string): OtelAttr["stability"] {
    switch (raw) {
        case "stable":
        case "experimental":
        case "deprecated":
        case "development":
            return raw;
        default:
            return "experimental";
    }
}

const REGISTRY: ReadonlyMap<string, OtelAttr> = (() => {
    const map = new Map<string, OtelAttr>();
    for (const raw of registryJson as RawOtelAttr[]) {
        map.set(raw.name, {
            name: raw.name,
            type: normalizeType(raw.type),
            stability: normalizeStability(raw.stability),
            deprecated: raw.deprecated,
            group: raw.group,
        });
    }
    return map;
})();

export function lookupUpstream(name: string): OtelAttr | undefined {
    return REGISTRY.get(name);
}

export function upstreamCount(): number {
    return REGISTRY.size;
}
