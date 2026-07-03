// =============================================================================
// ANcpLua v2.0 - RPC Semantic Conventions
// =============================================================================
// Remote Procedure Call telemetry attributes (gRPC, etc.).
// =============================================================================

import "../common/types.tsp";

using Qyl.Api.Contracts.Common;

namespace Qyl.Api.Contracts.Domains.Transport.Rpc;

// =============================================================================
// RPC Span Attributes
// =============================================================================

@doc("RPC span attributes")
model RpcAttributes {
  @doc("The RPC system (e.g., grpc, wcf, java_rmi)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.System)
  system: RpcSystem;

  @doc("The RPC service name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.Service)
  service?: string;

  @doc("The RPC method name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.Method)
  method?: string;

  @doc("Server address")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Server.Address)
  serverAddress?: string;

  @doc("Server port")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Server.Port)
  serverPort?: Port;

  // ---------------------------------------------------------------------------
  // gRPC-Specific Attributes
  // ---------------------------------------------------------------------------

  @doc("gRPC status code")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.GrpcStatusCode)
  grpcStatusCode?: GrpcStatusCode;

  @doc("gRPC request metadata. Keys map to rpc.grpc.request.metadata.<key>")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.GrpcRequestMetadata)
  grpcRequestMetadata?: Record<string[]>;

  @doc("gRPC response metadata. Keys map to rpc.grpc.response.metadata.<key>")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.GrpcResponseMetadata)
  grpcResponseMetadata?: Record<string[]>;

  // ---------------------------------------------------------------------------
  // Message Attributes
  // ---------------------------------------------------------------------------

  @doc("Message type (SENT or RECEIVED)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.MessageType)
  messageType?: RpcMessageType;

  @doc("Message ID (sequence number)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.MessageId)
  messageId?: int64;

  @doc("Compressed message size in bytes")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.MessageCompressedSize)
  messageCompressedSize?: ByteSize;

  @doc("Uncompressed message size in bytes")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.MessageUncompressedSize)
  messageUncompressedSize?: ByteSize;

  // ---------------------------------------------------------------------------
  // Connect RPC Attributes
  // ---------------------------------------------------------------------------

  @doc("Connect RPC error code")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.ConnectRpcErrorCode)
  connectRpcErrorCode?: ConnectRpcErrorCode;

  // ---------------------------------------------------------------------------
  // JSON-RPC Attributes
  // ---------------------------------------------------------------------------

  @doc("JSON-RPC error code")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.JsonrpcErrorCode)
  jsonrpcErrorCode?: int32;

  @doc("JSON-RPC error message")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.JsonrpcErrorMessage)
  jsonrpcErrorMessage?: string;

  @doc("JSON-RPC request ID")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.JsonrpcRequestId)
  jsonrpcRequestId?: string;

  @doc("JSON-RPC version")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.JsonrpcVersion)
  jsonrpcVersion?: string;
}

// =============================================================================
// RPC Enumerations
// =============================================================================

@doc("RPC systems")
enum RpcSystem {
  @doc("gRPC protocol")
  grpc: "grpc",

  @doc("Apache Thrift")
  apacheThrift: "apache_thrift",

  @doc("Connect RPC")
  connectRpc: "connect_rpc",

  @doc("JSON-RPC")
  jsonrpc: "jsonrpc",

  @doc("Apache Dubbo")
  apacheDubbo: "apache_dubbo",

  @doc("Windows Communication Foundation")
  wcf: "wcf",

  @doc("Java RMI")
  javaRmi: "java_rmi",

  @doc(".NET Remoting")
  dotnetRemoting: "dotnet_remoting",
}

@doc("gRPC status codes")
enum GrpcStatusCode {
  @doc("Success")
  ok: 0,

  @doc("Cancelled by client")
  cancelled: 1,

  @doc("Unknown error")
  `unknown`: 2,

  @doc("Invalid argument")
  invalidArgument: 3,

  @doc("Deadline exceeded")
  deadlineExceeded: 4,

  @doc("Not found")
  notFound: 5,

  @doc("Already exists")
  alreadyExists: 6,

  @doc("Permission denied")
  permissionDenied: 7,

  @doc("Resource exhausted")
  resourceExhausted: 8,

  @doc("Failed precondition")
  failedPrecondition: 9,

  @doc("Aborted")
  aborted: 10,

  @doc("Out of range")
  outOfRange: 11,

  @doc("Unimplemented")
  unimplemented: 12,

  @doc("Internal error")
  internal: 13,

  @doc("Unavailable")
  unavailable: 14,

  @doc("Data loss")
  dataLoss: 15,

  @doc("Unauthenticated")
  unauthenticated: 16,
}

@doc("Connect RPC error codes")
enum ConnectRpcErrorCode {
  @doc("Cancelled")
  cancelled: "cancelled",

  @doc("Unknown")
  `unknown`: "unknown",

  @doc("Invalid argument")
  invalidArgument: "invalid_argument",

  @doc("Deadline exceeded")
  deadlineExceeded: "deadline_exceeded",

  @doc("Not found")
  notFound: "not_found",

  @doc("Already exists")
  alreadyExists: "already_exists",

  @doc("Permission denied")
  permissionDenied: "permission_denied",

  @doc("Resource exhausted")
  resourceExhausted: "resource_exhausted",

  @doc("Failed precondition")
  failedPrecondition: "failed_precondition",

  @doc("Aborted")
  aborted: "aborted",

  @doc("Out of range")
  outOfRange: "out_of_range",

  @doc("Unimplemented")
  unimplemented: "unimplemented",

  @doc("Internal")
  internal: "internal",

  @doc("Unavailable")
  unavailable: "unavailable",

  @doc("Data loss")
  dataLoss: "data_loss",

  @doc("Unauthenticated")
  unauthenticated: "unauthenticated",
}

@doc("RPC message types")
enum RpcMessageType {
  @doc("Message sent")
  sent: "SENT",

  @doc("Message received")
  received: "RECEIVED",
}

// =============================================================================
// RPC Metrics
// =============================================================================

@doc("RPC server duration metric")
model RpcServerDurationMetric {
  @doc("Metric name")
  name: "rpc.server.duration";

  @doc("Metric unit (seconds)")
  unit: "s";

  @doc("RPC system")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.System)
  system: RpcSystem;

  @doc("RPC service")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.Service)
  service: string;

  @doc("RPC method")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.Method)
  method: string;

  @doc("gRPC status code")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.GrpcStatusCode)
  grpcStatusCode?: GrpcStatusCode;
}

@doc("RPC client duration metric")
model RpcClientDurationMetric {
  @doc("Metric name")
  name: "rpc.client.duration";

  @doc("Metric unit (seconds)")
  unit: "s";

  @doc("RPC system")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.System)
  system: RpcSystem;

  @doc("RPC service")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.Service)
  service: string;

  @doc("RPC method")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.Method)
  method: string;

  @doc("Server address")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Server.Address)
  serverAddress: string;

  @doc("Server port")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Server.Port)
  serverPort: Port;

  @doc("gRPC status code")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Rpc.GrpcStatusCode)
  grpcStatusCode?: GrpcStatusCode;
}
