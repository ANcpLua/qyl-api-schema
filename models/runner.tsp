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

@doc("Current client-visible state of one runner resource.")
model RunnerResourceState {
  name: string;
  lifecycle: RunnerResourceLifecycle;
  timestamp: utcDateTime;
  kind?: string;
  @minValue(1)
  @maxValue(65535)
  allocatedPort?: int32;
  endpoint?: url;
  lastError?: string;
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
