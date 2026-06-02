// Copyright (c) 2025-2026 ancplua
// SPDX-License-Identifier: MIT

import { describe, it, expect } from "vitest";
import { Tester } from "./test-host.js";

const LIB = "@ancplua/typespec-otelconventions-lint";

async function codes(body: string): Promise<string[]> {
    const ds = await Tester.diagnose(`using Qyl.Api.Schema.Semconv; model X {\n${body}\n}`);
    return ds.map((d) => d.code);
}

describe("ANcpLua-LINT-001 upstream-collision", () => {
    it("rejects gen_ai.*", async () => {
        expect(await codes(`@ancpluaAttr("gen_ai.foo", "string") foo: string;`))
            .toContain(`${LIB}/upstream-collision`);
    });
    it("rejects http.*", async () => {
        expect(await codes(`@ancpluaAttr("http.custom", "string") foo: string;`))
            .toContain(`${LIB}/upstream-collision`);
    });
    it("accepts ancplua.* prefix", async () => {
        expect(await codes(`@ancpluaAttr("ancplua.clean.key", "string") foo: string;`))
            .not.toContain(`${LIB}/upstream-collision`);
    });
});
