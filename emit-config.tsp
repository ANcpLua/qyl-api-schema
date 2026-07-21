// Build-only routing for the C# and TypeScript contract emitters.

import "@ancplua/typespec-emit-csharp";
import "@ancplua/typespec-emit-ts-types";
import "./main.tsp";

using Qyl.Api.Schema.Emit.CSharp;
using Qyl.Api.Schema.Emit.TsTypes;

@@csharpNamespace(Qyl.Api.Contracts, "Qyl.Api.Contracts");
@@csharpNamespace(Qyl.Api.Contracts.Streaming, "Qyl.Api.Contracts.Streaming");
@@csharpNamespace(Qyl.Api.Contracts.Health, "Qyl.Api.Contracts.Health");
@@csharpNamespace(Qyl.Api.Contracts.Mcp.Tools, "Qyl.Api.Contracts.Mcp.Tools");
@@csharpNamespace(Qyl.Api.Contracts.Runner, "Qyl.Api.Contracts.Runner");
@@csharpNamespace(Qyl.Api.Contracts.Runner.Mcp, "Qyl.Api.Contracts.Runner.Mcp");
@@csharpPolymorphic(
  Qyl.Api.Contracts.Runner.Mcp.RunnerMcpServerConfiguration,
  "transport"
);
@@csharpPolymorphic(
  Qyl.Api.Contracts.Runner.Mcp.RunnerMcpTestAssertion,
  "kind"
);
@@csharpPolymorphic(
  Qyl.Api.Contracts.Runner.Mcp.RunnerMcpEvaluationExportPayload,
  "format"
);

@@csharpNamespace(Qyl.Api.Contracts.Common, "Qyl.Api.Contracts.Common");
@@csharpNamespace(
  Qyl.Api.Contracts.Common.Errors,
  "Qyl.Api.Contracts.Common.Errors"
);
@@csharpNamespace(
  Qyl.Api.Contracts.Common.Pagination,
  "Qyl.Api.Contracts.Common.Pagination"
);

@@csharpNamespace(
  Qyl.Api.Contracts.Domains.Observe.Session,
  "Qyl.Api.Contracts.Domains.Observe.Session"
);

@@csharpNamespace(Qyl.Api.Contracts.OTel, "Qyl.Api.Contracts.OTel");
@@csharpNamespace(Qyl.Api.Contracts.OTel.Enums, "Qyl.Api.Contracts.OTel.Enums");
@@csharpNamespace(Qyl.Api.Contracts.OTel.Logs, "Qyl.Api.Contracts.OTel.Logs");
@@csharpNamespace(
  Qyl.Api.Contracts.OTel.Resource,
  "Qyl.Api.Contracts.OTel.Resource"
);
@@csharpNamespace(
  Qyl.Api.Contracts.OTel.Traces,
  "Qyl.Api.Contracts.OTel.Traces"
);

@@tsBrand(Qyl.Api.Contracts.Common.TraceId);
@@tsBrand(Qyl.Api.Contracts.Common.SpanId);
@@tsBrand(Qyl.Api.Contracts.Common.SessionId);
@@tsBrand(Qyl.Api.Contracts.Common.UserId);
@@tsBrand(Qyl.Api.Contracts.Runner.Mcp.RunnerMcpSessionId);
@@tsBrand(Qyl.Api.Contracts.Runner.Mcp.RunnerMcpWorkspaceId);
@@tsBrand(Qyl.Api.Contracts.Runner.Mcp.RunnerMcpServerId);
@@tsBrand(Qyl.Api.Contracts.Runner.Mcp.RunnerMcpExecutionId);
@@tsBrand(Qyl.Api.Contracts.Runner.Mcp.RunnerMcpTestCaseId);
@@tsBrand(Qyl.Api.Contracts.Runner.Mcp.RunnerMcpSuiteId);
@@tsBrand(Qyl.Api.Contracts.Runner.Mcp.RunnerMcpEvaluationRunId);
@@tsBrand(Qyl.Api.Contracts.Runner.Mcp.RunnerMcpEvaluationExportId);
