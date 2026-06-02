import "../dist/index.js";

using TypeSpec.Reflection;

namespace Qyl.Api.Schema.Semconv {
  /**
   * Options for `@ancpluaAttr`. All optional; the rule set only fires on what's present.
   */
  model AncpluaAttrOptions {
    cardinality?: "low" | "medium" | "high";
    stability?: "experimental" | "stable" | "deprecated";
    required?: boolean;
  }

  /**
   * Declares that a model property (or operation parameter) emits a ANcpLua-owned
   * telemetry attribute under the given key and primitive type.
   */
  extern dec ancpluaAttr(
    target: ModelProperty | Operation,
    key: valueof string,
    type: valueof "string" | "int" | "long" | "double" | "boolean" | "string[]",
    options?: valueof AncpluaAttrOptions
  );
}
