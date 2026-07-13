namespace Qyl.Api.Contracts.Runner.Mcp;

@doc("Stable qyl projection of an MCP tool advertised by a runner resource.")
model RunnerMcpTool {
  name: string;
  title?: string;
  description?: string;
  inputSchema: Record<unknown>;
  outputSchema?: Record<unknown>;
  annotations?: Record<unknown>;
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
}

@doc("One MCP content item projected onto a stable qyl JSON shape.")
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
  resource?: Record<unknown>;
  annotations?: Record<unknown>;
  @encodedName("application/json", "_meta")
  metadata?: Record<unknown>;
}

@doc("Stable qyl projection of an MCP tool-call result.")
model RunnerMcpToolCallResponse {
  content: RunnerMcpContent[];
  structuredContent?: Record<unknown>;
  isError: boolean;
  @encodedName("application/json", "_meta")
  metadata?: Record<unknown>;
}

@doc("Resource URI accepted by the runner's MCP projection.")
model RunnerMcpResourceReadRequest {
  uri: url;
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
