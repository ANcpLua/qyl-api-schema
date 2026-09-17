# Next contract release

Two items ride together; neither is worth a version on its own.

## Identity is one definition in both languages

`attributeIdentity` in `src/runtime` is hand-written canonical JSON with sorted keys. The collector's `OtlpAttributeValue.ToStableString` and `ToIdentityString` are a second, different format. Demo and live series identity therefore still disagree on the C# side.

Change: the C# emitter emits `ToStableString()` beside the `AttributeValue` converter from the same union node, with the same canonical form the TypeScript runtime uses (sorted keys, the wire encoding). The collector deletes `ToStableString`/`ToIdentityString` and calls the generated one. The npm probe already checks `attributeIdentity`; the .NET probe gains the same fixture, and both must agree byte for byte.

## Peer floors

`package.json` peer ranges are `^1.16.0` / `^0.86.0` on `main` (commit `46d4c86`), unreleased. They publish with this release.
