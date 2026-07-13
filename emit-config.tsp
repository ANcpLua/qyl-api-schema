// Build-only routing for the C# and TypeScript contract emitters.

import "@ancplua/typespec-emit-csharp";
import "@ancplua/typespec-emit-ts-types";
import "./main.tsp";

using Qyl.Api.Schema.Emit.CSharp;
using Qyl.Api.Schema.Emit.TsTypes;

@@csharpNamespace(Qyl.Api.Contracts, "Qyl.Api.Contracts");
@@csharpNamespace(Qyl.Api.Contracts.Streaming, "Qyl.Api.Contracts.Streaming");
@@csharpNamespace(Qyl.Api.Contracts.Health, "Qyl.Api.Contracts.Health");
@@csharpNamespace(Qyl.Api.Contracts.Runner, "Qyl.Api.Contracts.Runner");
@@csharpNamespace(Qyl.Api.Contracts.Runner.Mcp, "Qyl.Api.Contracts.Runner.Mcp");

@@csharpNamespace(Qyl.Api.Contracts.Common, "Qyl.Api.Contracts.Common");
@@csharpNamespace(Qyl.Api.Contracts.Common.Errors, "Qyl.Api.Contracts.Common.Errors");
@@csharpNamespace(Qyl.Api.Contracts.Common.Pagination, "Qyl.Api.Contracts.Common.Pagination");

@@csharpNamespace(Qyl.Api.Contracts.Domains.Observe.Session, "Qyl.Api.Contracts.Domains.Observe.Session");

@@csharpNamespace(Qyl.Api.Contracts.OTel, "Qyl.Api.Contracts.OTel");
@@csharpNamespace(Qyl.Api.Contracts.OTel.Enums, "Qyl.Api.Contracts.OTel.Enums");
@@csharpNamespace(Qyl.Api.Contracts.OTel.Logs, "Qyl.Api.Contracts.OTel.Logs");
@@csharpNamespace(Qyl.Api.Contracts.OTel.Profiles, "Qyl.Api.Contracts.OTel.Profiles");
@@csharpNamespace(Qyl.Api.Contracts.OTel.Resource, "Qyl.Api.Contracts.OTel.Resource");
@@csharpNamespace(Qyl.Api.Contracts.OTel.Traces, "Qyl.Api.Contracts.OTel.Traces");

@@tsBrand(Qyl.Api.Contracts.Common.TraceId);
@@tsBrand(Qyl.Api.Contracts.Common.SpanId);
@@tsBrand(Qyl.Api.Contracts.Common.SessionId);
@@tsBrand(Qyl.Api.Contracts.Common.UserId);
