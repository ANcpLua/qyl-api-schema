import "@ancplua/typespec-emit-csharp";

using Qyl.Api.Schema.Emit.CSharp;

@csharpNamespace("Qyl.Api.Contracts.Test")
namespace Qyl.Api.Contracts.Test;

@csharpRecord
model Point {
  x: int32;
  y: int32;
  label?: string;
}

@csharpEnum
enum Color {
  Red,
  Green,
  Blue,
}
