import { setTypeSpecNamespace } from "@typespec/compiler";
import { $csharpBrand, $csharpEnum, $csharpNamespace, $csharpPolymorphic, $csharpRecord } from "./decorators.js";

setTypeSpecNamespace("Qyl.Api.Schema.Emit.CSharp", $csharpNamespace, $csharpRecord, $csharpBrand, $csharpEnum, $csharpPolymorphic);

export { $lib } from "./lib.js";
export { $csharpBrand, $csharpEnum, $csharpNamespace, $csharpPolymorphic, $csharpRecord } from "./decorators.js";
export { $onEmit } from "./emitter.js";
