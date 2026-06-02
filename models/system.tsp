// =============================================================================
// ANcpLua v2.0 - System Semantic Conventions (OTel v1.40)
// =============================================================================
// Operating system telemetry attributes.
// =============================================================================

import "../common/types.tsp";
import "../otel/resource.tsp";

using Qyl.Api.Contracts.Common;
using Qyl.Api.Contracts.OTel.Resource;

namespace Qyl.Api.Contracts.Domains.Runtime.System;

// =============================================================================
// OS Resource Attributes
// =============================================================================

@doc("Operating system resource attributes")
model OsAttributes {
  @doc("Operating system type")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Os.Type)
  osType?: OsType;

  @doc("Operating system description")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Os.Description)
  description?: string;

  @doc("Operating system name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Os.Name)
  name?: string;

  @doc("Operating system version")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Os.Version)
  version?: string;

  @doc("Operating system build ID")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Os.BuildId)
  buildId?: string;
}

// =============================================================================
// System Metrics
// =============================================================================

@doc("System CPU utilization metric")
model SystemCpuUtilizationMetric {
  @doc("Metric name")
  name: "system.cpu.utilization";

  @doc("Metric unit (ratio)")
  unit: "1";

  @doc("CPU state")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.System.CpuState)
  cpuState: SystemCpuState;

  @doc("CPU logical number")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.System.CpuLogicalNumber)
  cpuLogicalNumber?: int32;
}

@doc("System CPU time metric")
model SystemCpuTimeMetric {
  @doc("Metric name")
  name: "system.cpu.time";

  @doc("Metric unit (seconds)")
  unit: "s";

  @doc("CPU state")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.System.CpuState)
  cpuState: SystemCpuState;

  @doc("CPU logical number")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.System.CpuLogicalNumber)
  cpuLogicalNumber?: int32;
}

@doc("System CPU frequency metric")
model SystemCpuFrequencyMetric {
  @doc("Metric name")
  name: "system.cpu.frequency";

  @doc("Metric unit (Hz)")
  unit: "Hz";

  @doc("CPU logical number")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.System.CpuLogicalNumber)
  cpuLogicalNumber?: int32;
}

@doc("System memory usage metric")
model SystemMemoryUsageMetric {
  @doc("Metric name")
  name: "system.memory.usage";

  @doc("Metric unit (bytes)")
  unit: "By";

  @doc("Memory state")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.System.MemoryState)
  memoryState: SystemMemoryState;
}

@doc("System memory utilization metric")
model SystemMemoryUtilizationMetric {
  @doc("Metric name")
  name: "system.memory.utilization";

  @doc("Metric unit (ratio)")
  unit: "1";

  @doc("Memory state")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.System.MemoryState)
  memoryState: SystemMemoryState;
}

@doc("System disk IO metric")
model SystemDiskIoMetric {
  @doc("Metric name")
  name: "system.disk.io";

  @doc("Metric unit (bytes)")
  unit: "By";

  @doc("Disk device")
  @encodedName("application/json", "system.disk.device")
  diskDevice: string;

  @doc("IO direction")
  @encodedName("application/json", "system.disk.direction")
  diskDirection: string;
}

@doc("System disk operations metric")
model SystemDiskOperationsMetric {
  @doc("Metric name")
  name: "system.disk.operations";

  @doc("Metric unit")
  unit: "{operation}";

  @doc("Disk device")
  @encodedName("application/json", "system.disk.device")
  diskDevice: string;

  @doc("IO direction")
  @encodedName("application/json", "system.disk.direction")
  diskDirection: string;
}

@doc("System disk IO time metric")
model SystemDiskIoTimeMetric {
  @doc("Metric name")
  name: "system.disk.io_time";

  @doc("Metric unit (seconds)")
  unit: "s";

  @doc("Disk device")
  @encodedName("application/json", "system.disk.device")
  diskDevice: string;
}

@doc("System filesystem usage metric")
model SystemFilesystemUsageMetric {
  @doc("Metric name")
  name: "system.filesystem.usage";

  @doc("Metric unit (bytes)")
  unit: "By";

  @doc("Filesystem device")
  @encodedName("application/json", "system.filesystem.device")
  device: string;

  @doc("Filesystem mount point")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.System.FilesystemMountpoint)
  mountpoint: string;

  @doc("Filesystem type")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.System.FilesystemType)
  fsType: string;

  @doc("Filesystem state")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.System.FilesystemState)
  state: SystemFilesystemState;
}

@doc("System network IO metric")
model SystemNetworkIoMetric {
  @doc("Metric name")
  name: "system.network.io";

  @doc("Metric unit (bytes)")
  unit: "By";

  @doc("Network device")
  @encodedName("application/json", "system.network.device")
  networkDevice: string;

  @doc("IO direction")
  @encodedName("application/json", "system.network.direction")
  networkDirection: string;
}

@doc("System network connections metric")
model SystemNetworkConnectionsMetric {
  @doc("Metric name")
  name: "system.network.connections";

  @doc("Metric unit")
  unit: "{connection}";

  @doc("Network protocol")
  @encodedName("application/json", "system.network.protocol")
  protocol: string;

  @doc("Network state")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Network.ConnectionState)
  state: SystemNetworkState;
}

@doc("System paging usage metric")
model SystemPagingUsageMetric {
  @doc("Metric name")
  name: "system.paging.usage";

  @doc("Metric unit (bytes)")
  unit: "By";

  @doc("Paging state")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.System.PagingState)
  pagingState: SystemPagingState;

  @doc("Paging device")
  @encodedName("application/json", "system.paging.device")
  device?: string;
}

@doc("System paging operations metric")
model SystemPagingOperationsMetric {
  @doc("Metric name")
  name: "system.paging.operations";

  @doc("Metric unit")
  unit: "{operation}";

  @doc("Paging type")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.System.PagingType)
  pagingType: SystemPagingType;

  @doc("Paging direction")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.System.PagingDirection)
  pagingDirection: string;
}

@doc("System process count metric")
model SystemProcessCountMetric {
  @doc("Metric name")
  name: "system.process.count";

  @doc("Metric unit")
  unit: "{process}";

  @doc("Process status")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.System.ProcessStatus)
  processStatus: SystemProcessStatus;
}

// =============================================================================
// System Enumerations
// =============================================================================

@doc("System CPU states")
enum SystemCpuState {
  @doc("User mode")
  user: "user",

  @doc("System mode")
  system: "system",

  @doc("Nice mode")
  nice: "nice",

  @doc("Idle")
  idle: "idle",

  @doc("I/O wait")
  iowait: "iowait",

  @doc("Interrupt")
  interrupt: "interrupt",

  @doc("Steal")
  steal: "steal",
}

@doc("System memory states")
enum SystemMemoryState {
  @doc("Used memory")
  used: "used",

  @doc("Free memory")
  free: "free",

  @doc("Buffered memory")
  buffered: "buffered",

  @doc("Cached memory")
  cached: "cached",

  @doc("Shared memory")
  shared: "shared",
}

@doc("System filesystem states")
enum SystemFilesystemState {
  @doc("Used space")
  used: "used",

  @doc("Free space")
  free: "free",

  @doc("Reserved space")
  reserved: "reserved",
}

@doc("System network states")
enum SystemNetworkState {
  @doc("CLOSE state")
  close: "close",

  @doc("CLOSE_WAIT state")
  closeWait: "close_wait",

  @doc("CLOSING state")
  closing: "closing",

  @doc("DELETE state")
  delete: "delete",

  @doc("ESTABLISHED state")
  established: "established",

  @doc("FIN_WAIT_1 state")
  finWait1: "fin_wait_1",

  @doc("FIN_WAIT_2 state")
  finWait2: "fin_wait_2",

  @doc("LAST_ACK state")
  lastAck: "last_ack",

  @doc("LISTEN state")
  listen: "listen",

  @doc("SYN_RECV state")
  synRecv: "syn_recv",

  @doc("SYN_SENT state")
  synSent: "syn_sent",

  @doc("TIME_WAIT state")
  timeWait: "time_wait",
}

@doc("System paging states")
enum SystemPagingState {
  @doc("Used")
  used: "used",

  @doc("Free")
  free: "free",
}

@doc("System paging types")
enum SystemPagingType {
  @doc("Major page fault")
  major: "major",

  @doc("Minor page fault")
  minor: "minor",
}

@doc("System process status")
enum SystemProcessStatus {
  @doc("Running")
  running: "running",

  @doc("Sleeping")
  sleeping: "sleeping",

  @doc("Stopped")
  stopped: "stopped",

  @doc("Defunct/zombie")
  defunct: "defunct",
}
