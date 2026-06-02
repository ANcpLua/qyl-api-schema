import { setTypeSpecNamespace } from "@typespec/compiler";
import { $duckdbColumn, $duckdbIndex, $duckdbPrimaryKey, $duckdbRowTimestamp, $duckdbTable, $duckdbType } from "./decorators.js";

setTypeSpecNamespace(
  "Qyl.Api.Schema.Emit.DuckDb",
  $duckdbTable,
  $duckdbColumn,
  $duckdbType,
  $duckdbPrimaryKey,
  $duckdbIndex,
  $duckdbRowTimestamp,
);

export { $lib } from "./lib.js";
export { $duckdbColumn, $duckdbIndex, $duckdbPrimaryKey, $duckdbRowTimestamp, $duckdbTable, $duckdbType } from "./decorators.js";
export { $onEmit } from "./emitter.js";
