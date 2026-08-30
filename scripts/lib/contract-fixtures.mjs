// Ajv harness for the published JSON Schema, shared by the fixture corpus in
// verify-contract-fixtures.mjs and the Zod parity gate in
// verify-zod-contracts.mjs.
//
// The corpus stays where it is; this module only compiles validators and records
// the verdict every fixture is asserted against. A second checker then replays
// the recording instead of keeping its own copy of the fixtures, so a fixture
// added to the corpus is automatically also a parity case and the two cannot
// drift into disagreeing about the same wire shape.
import { readFile } from "node:fs/promises";
import Ajv2020 from "ajv/dist/2020.js";

export const contractSchemaPath = "generated/json-schema/qyl-api-schema.json";
export const contractSchema = JSON.parse(await readFile(contractSchemaPath, "utf8"));

const definitions = contractSchema.$defs ?? {};

// Formats are validated by the emitting toolchain and by the consumers that
// build typed validators; Ajv here checks structure, so an unimplemented format
// must not turn into a silent pass or a hard failure.
const ajv = new Ajv2020({ allErrors: true, strict: true, validateFormats: false });
ajv.addKeyword({ keyword: "x-csharp-struct", schemaType: "boolean" });
ajv.addKeyword({ keyword: "x-csharp-type", schemaType: "string" });
ajv.addKeyword({ keyword: "discriminator", schemaType: "object" });

const definitionOfValidator = new WeakMap();

/**
 * Every fixture asserted through {@link assertValid} / {@link assertInvalid}, in
 * corpus order, as `{ definition, fixture, valid, label }`.
 */
export const exercisedFixtures = [];

/** Compile a self-contained schema document that is not a published definition. */
export function compileStandalone(schema) {
  return ajv.compile(schema);
}

export function validatorFor(definition) {
  const validate = ajv.compile({
    $schema: contractSchema.$schema,
    $defs: definitions,
    $ref: `#/$defs/${definition}`,
  });
  definitionOfValidator.set(validate, definition);
  return validate;
}

function record(validate, fixture, label, valid) {
  const definition = definitionOfValidator.get(validate);
  // A standalone document has no published definition name, so a replaying
  // checker has nothing to look the fixture up by. Those cases stay local to the
  // corpus.
  if (definition === undefined) return;
  // Several fixtures are mutated after being asserted to build the next case;
  // the recording must keep the shape that was actually judged.
  exercisedFixtures.push({ definition, fixture: structuredClone(fixture), valid, label });
}

export function assertValid(validate, fixture, label) {
  record(validate, fixture, label, true);
  if (!validate(fixture)) {
    throw new Error(`${label} must validate: ${ajv.errorsText(validate.errors, { separator: "\n" })}`);
  }
}

export function assertInvalid(validate, fixture, label) {
  record(validate, fixture, label, false);
  if (validate(fixture)) throw new Error(`${label} must be rejected.`);
}
