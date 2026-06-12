import "../dist/index.js";

using TypeSpec.Reflection;

namespace Qyl.Api.Schema.Tcg {
  /**
   * Declares the Telemetry Control Graph instance for one deployment contract.
   *
   * The value must structurally match the Control Graph v1 wire shape. The
   * emitter turns that one contract into deterministic machine artifacts for
   * the runtime verifier plus YAML/Markdown review artifacts for humans.
   */
  extern dec instance(target: Namespace, graph: valueof unknown);
}
