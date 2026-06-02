import "@ancplua/typespec-emit-ts-types";

using Qyl.Api.Schema.Emit.TsTypes;

@tsBrand
scalar TraceId extends string;

model TraceRef {
  id: TraceId;
  name: string;
  ts?: utcDateTime;
}

enum Status {
  ok: "ok",
  error: "error",
}
