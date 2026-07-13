namespace Qyl.Api.Contracts.Runner.Mcp;

@doc("Icon metadata carried by MCP tools and resource links.")
model RunnerMcpIcon {
  src: string;
  mimeType?: string;
  sizes?: string[];
  theme?: string;
}

@doc("Task-augmentation support advertised for an MCP tool.")
enum RunnerMcpToolTaskSupport {
  forbidden: "forbidden",
  optional: "optional",
  required: "required",
}

@doc("Execution metadata advertised for an MCP tool.")
model RunnerMcpToolExecution {
  taskSupport?: RunnerMcpToolTaskSupport;
}

@doc("Stable qyl projection of an MCP tool advertised by a runner resource.")
model RunnerMcpTool {
  name: string;
  title?: string;
  description?: string;
  inputSchema: Record<unknown>;
  outputSchema?: Record<unknown>;
  annotations?: Record<unknown>;
  execution?: RunnerMcpToolExecution;
  icons?: RunnerMcpIcon[];
  @encodedName("application/json", "_meta")
  metadata?: Record<unknown>;
}

@doc("MCP tools currently advertised by a runner resource.")
model RunnerMcpToolsResponse {
  tools: RunnerMcpTool[];
  nextCursor?: string;
  @encodedName("application/json", "_meta")
  metadata?: Record<unknown>;
}

@doc("Tool call accepted by the runner's MCP projection.")
model RunnerMcpToolCallRequest {
  name: string;
  arguments?: Record<unknown>;
  task?: RunnerMcpTaskMetadata;
  @encodedName("application/json", "_meta")
  metadata?: Record<unknown>;
}

@doc("Task-augmentation metadata accepted on an MCP tool call. ttl is encoded as milliseconds.")
model RunnerMcpTaskMetadata {
  ttl?: float64;
}

@doc("One MCP content item projected onto a stable qyl JSON shape. Variant-specific required fields follow its type discriminator.")
model RunnerMcpContent {
  type: string;
  text?: string;
  data?: string;
  mimeType?: string;
  uri?: url;
  name?: string;
  title?: string;
  description?: string;
  @minValue(0)
  size?: int64;
  icons?: RunnerMcpIcon[];
  resource?: RunnerMcpResourceContent;
  id?: string;
  input?: unknown;
  toolUseId?: string;
  content?: RunnerMcpContent[];
  structuredContent?: Record<unknown>;
  isError?: boolean;
  annotations?: Record<unknown>;
  @encodedName("application/json", "_meta")
  metadata?: Record<unknown>;
}

@doc("Lifecycle state of an MCP task returned by a task-augmented tool call.")
enum RunnerMcpTaskStatus {
  working: "working",
  inputRequired: "input_required",
  completed: "completed",
  failed: "failed",
  cancelled: "cancelled",
}

@doc("Task returned by an MCP task-augmented tool call. ttl and pollInterval are encoded as milliseconds.")
model RunnerMcpTask {
  taskId: string;
  status: RunnerMcpTaskStatus;
  statusMessage?: string;
  createdAt: utcDateTime;
  lastUpdatedAt: utcDateTime;
  ttl?: float64;
  pollInterval?: float64;
}

@doc("Stable qyl projection of an MCP tool-call result.")
model RunnerMcpToolCallResponse {
  content: RunnerMcpContent[];
  structuredContent?: Record<unknown>;
  isError: boolean;
  task?: RunnerMcpTask;
  @encodedName("application/json", "_meta")
  metadata?: Record<unknown>;
}

@doc("Resource URI accepted by the runner's MCP projection.")
model RunnerMcpResourceReadRequest {
  uri: url;
  @encodedName("application/json", "_meta")
  metadata?: Record<unknown>;
}

@doc("Text or base64 resource content returned by an MCP server. Exactly one of text or blob is present.")
model RunnerMcpResourceContent {
  uri: url;
  mimeType?: string;
  text?: string;
  blob?: string;
  @encodedName("application/json", "_meta")
  metadata?: Record<unknown>;
}

@doc("Stable qyl projection of an MCP resources/read result.")
model RunnerMcpResourceReadResponse {
  contents: RunnerMcpResourceContent[];
  @encodedName("application/json", "_meta")
  metadata?: Record<unknown>;
}
