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
  durationMs: float64;
}

@doc("Readiness or liveness report returned by /health and /alive.")
model HealthReport {
  status: HealthStatus;
  totalDurationMs: float64;
  entries: Record<HealthCheckEntry>;
}
