import "../common/types.tsp";

using Qyl.Api.Contracts.Common;

namespace Qyl.Api.Contracts.Health;

@doc("Health state reported by a qyl-managed process.")
enum HealthStatus {
  healthy: "healthy",
  degraded: "degraded",
  unhealthy: "unhealthy",
}

@doc("One named health-check result.")
model HealthCheckEntry {
  status: HealthStatus;
  description?: string;
  @encodedName("application/json", "duration_ms")
  durationMs: float64;
}

@doc("Readiness or liveness report returned by /health and /alive.")
model HealthReport {
  status: HealthStatus;
  @encodedName("application/json", "total_duration_ms")
  totalDurationMs: float64;
  entries: Record<HealthCheckEntry>;

  // The meta surface of the contract loop: first-party clients compare this to
  // the revision baked into their own generated artifacts and refuse to run on
  // a mismatch, so a redeployed collector cannot silently serve a contract its
  // clients were not generated from.
  @doc("Revision of the API contract this process serves, for the client-side startup handshake.")
  @encodedName("application/json", "contract_revision")
  contractRevision: ContractRevision;
}
