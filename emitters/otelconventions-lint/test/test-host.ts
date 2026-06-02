// Copyright (c) 2025-2026 ancplua
// SPDX-License-Identifier: MIT

import { resolvePath } from "@typespec/compiler";
import { createTester } from "@typespec/compiler/testing";

// .import() explicitly adds `import "@ancplua/typespec-otelconventions-lint";` to the synthetic main.tsp
// of every fixture. The fixture itself opens the namespace via `using Qyl.Api.Schema.Semconv;` — bundling
// that into `.using()` double-registers the decorator and triggers `ambiguous-symbol`.
export const Tester = createTester(resolvePath(import.meta.dirname, ".."), {
    libraries: ["@ancplua/typespec-otelconventions-lint"],
}).import("@ancplua/typespec-otelconventions-lint");
