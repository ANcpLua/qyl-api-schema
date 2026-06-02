import { setTypeSpecNamespace } from "@typespec/compiler";
import { $csharpEnum, $csharpNamespace, $csharpRecord } from "./decorators.js";

setTypeSpecNamespace("Qyl.Api.Schema.Emit.CSharp", $csharpNamespace, $csharpRecord, $csharpEnum);

export { $lib } from "./lib.js";
export { $csharpEnum, $csharpNamespace, $csharpRecord } from "./decorators.js";
export { $onEmit } from "./emitter.js";
