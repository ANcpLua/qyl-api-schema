import { setTypeSpecNamespace } from "@typespec/compiler";
import { $csharpEnum, $csharpNamespace, $csharpPolymorphic, $csharpRecord } from "./decorators.js";

setTypeSpecNamespace("Qyl.Api.Schema.Emit.CSharp", $csharpNamespace, $csharpRecord, $csharpEnum, $csharpPolymorphic);

export { $lib } from "./lib.js";
export { $csharpEnum, $csharpNamespace, $csharpPolymorphic, $csharpRecord } from "./decorators.js";
export { $onEmit } from "./emitter.js";
