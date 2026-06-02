import "../dist/index.js";

using TypeSpec.Reflection;

namespace Qyl.Api.Schema.Emit.DuckDb;

extern dec duckdbTable(target: Model, name: valueof string);
extern dec duckdbColumn(target: ModelProperty, name: valueof string);
extern dec duckdbType(target: ModelProperty | Scalar, type: valueof string);
extern dec duckdbPrimaryKey(target: ModelProperty);
extern dec duckdbIndex(target: ModelProperty, name: valueof string);
extern dec duckdbRowTimestamp(target: Model);
