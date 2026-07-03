// =============================================================================
// ANcpLua v2.0 - User/Client/Service Semantic Conventions
// =============================================================================
// User, client, service, and app identity attributes.
// =============================================================================

import "../common/types.tsp";

using Qyl.Api.Contracts.Common;

namespace Qyl.Api.Contracts.Domains.Identity;

// =============================================================================
// User Attributes
// =============================================================================

@doc("User attributes")
model UserAttributes {
  @doc("User ID (unique identifier)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.User.Id)
  id?: UserId;

  @doc("User name (may be pseudonymized)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.User.Name)
  name?: string;

  @doc("User email (may be hashed)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.User.Email)
  email?: string;

  @doc("User full name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.User.FullName)
  fullName?: string;

  @doc("User hash (for privacy)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.User.Hash)
  hash?: string;

  @doc("User roles")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.User.Roles)
  roles?: string[];
}

// =============================================================================
// Client Attributes
// =============================================================================

@doc("Client attributes")
model ClientAttributes {
  @doc("Client address (IP, hostname, or Unix socket path)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Client.Address)
  address?: IpAddress | string;

  @doc("Client port")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Client.Port)
  port?: Port;
}

// =============================================================================
// Service Attributes
// =============================================================================

@doc("Service resource attributes")
model ServiceAttributes {
  @doc("Service name (required)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Service.Name)
  name: string;

  @doc("Service namespace")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Service.Namespace)
  `namespace`?: string;

  @doc("Service instance ID (unique per instance)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Service.InstanceId)
  instanceId?: string;

  @doc("Service version")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Service.Version)
  version?: SemVer;
}

// =============================================================================
// App Attributes
// =============================================================================

@doc("Application attributes")
model AppAttributes {
  @doc("Application name")
  @encodedName("application/json", "app.name")
  name?: string;

  @doc("Application version")
  @encodedName("application/json", "app.version")
  version?: SemVer;

  @doc("Application build ID")
  @encodedName("application/json", "app.build.id")
  buildId?: string;
}

// =============================================================================
// Server Attributes
// =============================================================================

@doc("Server attributes")
model ServerAttributes {
  @doc("Server address (hostname or IP)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Server.Address)
  address?: string;

  @doc("Server port")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Server.Port)
  port?: Port;
}

// =============================================================================
// Destination Attributes
// =============================================================================

@doc("Destination attributes (for client spans)")
model DestinationAttributes {
  @doc("Destination address")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Destination.Address)
  address?: string;

  @doc("Destination port")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Destination.Port)
  port?: Port;
}

// =============================================================================
// Source Attributes
// =============================================================================

@doc("Source attributes")
model SourceAttributes {
  @doc("Source address (IP, hostname, or Unix socket path)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Source.Address)
  address?: IpAddress | string;

  @doc("Source port")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Source.Port)
  port?: Port;
}

// =============================================================================
// Peer Attributes (Deprecated, for compatibility)
// =============================================================================

@doc("Peer attributes (deprecated)")
model PeerAttributes {
  @doc("Peer service name")
  @encodedName("application/json", "peer.service")
  service?: string;
}

// =============================================================================
// Identity Statistics
// =============================================================================

@doc("User activity statistics")
model UserActivityStats {
  @doc("Total unique users")
  @encodedName("application/json", "total_users")
  totalUsers: Count;

  @doc("Active users in time range")
  @encodedName("application/json", "active_users")
  activeUsers: Count;

  @doc("New users in time range")
  @encodedName("application/json", "new_users")
  newUsers: Count;

  @doc("Users by role")
  @encodedName("application/json", "by_role")
  byRole?: UserRoleStats[];
}

@doc("User stats by role")
model UserRoleStats {
  @doc("Role name")
  role: string;

  @doc("User count")
  count: Count;

  @doc("Percentage of total")
  percentage: Percentage;
}

@doc("Service dependency map")
model ServiceDependency {
  @doc("Source service")
  @encodedName("application/json", "source_service")
  sourceService: string;

  @doc("Target service")
  @encodedName("application/json", "target_service")
  targetService: string;

  @doc("Request count")
  @encodedName("application/json", "request_count")
  requestCount: Count;

  @doc("Error rate")
  @encodedName("application/json", "error_rate")
  errorRate: Ratio;

  @doc("Average latency in milliseconds")
  @encodedName("application/json", "avg_latency_ms")
  avgLatencyMs: float64;
}
