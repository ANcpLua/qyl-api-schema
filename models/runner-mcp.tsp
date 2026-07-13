import "@typespec/openapi3";

using TypeSpec.OpenAPI;

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

@doc("Metadata shared by every MCP content variant.")
model RunnerMcpContentMetadata {
  annotations?: Record<unknown>;
  @encodedName("application/json", "_meta")
  metadata?: Record<unknown>;
}

@doc("Text provided to or returned by an MCP model or tool.")
model RunnerMcpTextContent extends RunnerMcpContentMetadata {
  type: "text";
  text: string;
}

@doc("Base64-encoded image content.")
model RunnerMcpImageContent extends RunnerMcpContentMetadata {
  type: "image";
  data: bytes;
  mimeType: string;
}

@doc("Base64-encoded audio content.")
model RunnerMcpAudioContent extends RunnerMcpContentMetadata {
  type: "audio";
  data: bytes;
  mimeType: string;
}

@doc("A resource embedded in MCP content.")
model RunnerMcpEmbeddedResourceContent extends RunnerMcpContentMetadata {
  type: "resource";
  resource: RunnerMcpResourceContent;
}

@doc("A link to a resource that an MCP server can read.")
model RunnerMcpResourceLinkContent extends RunnerMcpContentMetadata {
  type: "resource_link";
  uri: url;
  name: string;
  title?: string;
  description?: string;
  mimeType?: string;
  @minValue(0)
  size?: int64;
  icons?: RunnerMcpIcon[];
}

@doc("An MCP sampling request to invoke a tool.")
model RunnerMcpToolUseContent extends RunnerMcpContentMetadata {
  type: "tool_use";
  id: string;
  name: string;
  input: unknown;
}

@doc("The result of an MCP sampling tool invocation.")
model RunnerMcpToolResultContent extends RunnerMcpContentMetadata {
  type: "tool_result";
  toolUseId: string;
  content: RunnerMcpContent[];
  structuredContent?: Record<unknown>;
  isError?: boolean;
}

@doc("One MCP content item. The type literal selects the required variant fields.")
@oneOf
union RunnerMcpContent {
  text: RunnerMcpTextContent,
  image: RunnerMcpImageContent,
  audio: RunnerMcpAudioContent,
  embeddedResource: RunnerMcpEmbeddedResourceContent,
  resourceLink: RunnerMcpResourceLinkContent,
  toolUse: RunnerMcpToolUseContent,
  toolResult: RunnerMcpToolResultContent,
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

@doc("Metadata shared by MCP text and blob resources.")
model RunnerMcpResourceContentMetadata {
  uri: url;
  mimeType?: string;
  @encodedName("application/json", "_meta")
  metadata?: Record<unknown>;
}

@doc("Text resource content returned by an MCP server.")
model RunnerMcpTextResourceContent extends RunnerMcpResourceContentMetadata {
  text: string;
}

@doc("Base64-encoded resource content returned by an MCP server.")
model RunnerMcpBlobResourceContent extends RunnerMcpResourceContentMetadata {
  blob: bytes;
}

@doc("Exactly one MCP text or blob resource variant.")
@oneOf
union RunnerMcpResourceContent {
  text: RunnerMcpTextResourceContent,
  blob: RunnerMcpBlobResourceContent,
}

@doc("Stable qyl projection of an MCP resources/read result.")
model RunnerMcpResourceReadResponse {
  contents: RunnerMcpResourceContent[];
  @encodedName("application/json", "_meta")
  metadata?: Record<unknown>;
}
