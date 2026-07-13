// Qyl.Api.Contracts local compile entry point.
// Product contracts are imported here; local emitter routing is the only difference from index.tsp.

import "@typespec/events";
import "@typespec/http";
import "@typespec/openapi";
import "@typespec/sse";

import "./generated/otel-keys.gen.tsp";

import "./common/types.tsp";
import "./common/errors.tsp";
import "./common/pagination.tsp";

import "./otel/enums.tsp";
import "./otel/resource.tsp";
import "./otel/span.tsp";
import "./otel/logs.tsp";
import "./otel/profiles.tsp";

import "./models/session.tsp";
import "./models/health.tsp";
import "./models/runner.tsp";
import "./models/runner-mcp.tsp";

import "./api/routes.tsp";
import "./api/streaming.tsp";
import "./api/runner.tsp";

import "./emit-config.tsp";
