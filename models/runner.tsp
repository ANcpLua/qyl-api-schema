import "@typespec/http";

using TypeSpec.Http;

namespace Qyl.Api.Contracts.Runner;

@doc("Lifecycle state of a resource supervised by the local qyl runner.")
enum RunnerResourceLifecycle {
  pending: "pending",
  starting: "starting",
  ready: "ready",
  stopping: "stopping",
  stopped: "stopped",
  failed: "failed",
}

@doc("Kind of process or connection supervised by the local qyl runner.")
enum RunnerResourceKind {
  collector: "collector",
  project: "project",
  command: "command",
  stdio: "stdio",
  http: "http",
  inproc: "inproc",
}

@doc("Current client-visible state of one runner resource.")
model RunnerResourceState {
  name: string;
  lifecycle: RunnerResourceLifecycle;
  timestamp: utcDateTime;
  kind?: RunnerResourceKind;

  @minValue(1)
  @maxValue(65535)
  allocatedPort?: int32;

  endpoint?: url;
  lastError?: string;

  @doc("Opaque SDK server-info entity when this resource is an initialized MCP connection.")
  serverIdentity?: unknown;

  @minValue(0)
  toolCount?: int32;

  @minValue(0)
  restarts?: int32;
}

@doc("A runner lifecycle action was accepted and continues asynchronously.")
model RunnerActionAccepted {
  @statusCode statusCode: 202;
}

@doc("Origin stream for one captured child-process log line.")
enum RunnerLogStream {
  stdout: "out",
  stderr: "err",
}

@doc("One bounded child-process log line exposed by the runner.")
model RunnerLogLine {
  resource: string;
  stream: RunnerLogStream;
  line: string;
}
