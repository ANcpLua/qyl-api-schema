import "../dist/index.js";

using TypeSpec.Reflection;

namespace Qyl.Api.Schema.Emit.CSharp;

extern dec csharpNamespace(target: Model | Enum | Namespace, ns: valueof string);
extern dec csharpRecord(target: Model);
extern dec csharpBrand(target: Scalar);
extern dec csharpEnum(target: Enum | Union);
extern dec csharpPolymorphic(target: Union, discriminator?: valueof string);
