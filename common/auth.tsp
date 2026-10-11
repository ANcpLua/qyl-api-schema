// =============================================================================
// Collector key security schemes per role
// =============================================================================
// Every collector key travels in `x-otlp-api-key`; its roles
// (Qyl.Api.Contracts.Common.CollectorKeyRole) decide what it may do. The query
// routes keep the original `ApiKeyAuth` scheme and require the `read` role;
// the schemes below name the roles the write routes require.
// =============================================================================

import "@typespec/http";

using TypeSpec.Http;

namespace TypeSpec.Http {
  @doc("Collector API key in `x-otlp-api-key` carrying the `write` role (Qyl.Api.Contracts.Common.CollectorKeyRole). Creates and updates user resources.")
  model QylWriteKeyAuth is ApiKeyAuth<ApiKeyLocation.header, "x-otlp-api-key">;

  @doc("Collector API key in `x-otlp-api-key` carrying the `delete` role (Qyl.Api.Contracts.Common.CollectorKeyRole). Deletes user resources, never telemetry.")
  model QylDeleteKeyAuth is ApiKeyAuth<ApiKeyLocation.header, "x-otlp-api-key">;
}
