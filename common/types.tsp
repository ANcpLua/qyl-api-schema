// =============================================================================
// qyl common types and scalars
// =============================================================================
// Foundational types used across qyl API contracts and OTel-compatible models.
// OpenTelemetry semantic-convention references are pinned to core v1.43.0
// (GenAI keys come from the dedicated GenAI registry since the 1.42 split).
// =============================================================================

import "@typespec/openapi";

using TypeSpec.OpenAPI;

namespace Qyl.Api.Contracts.Common;

// =============================================================================
// Identifier Scalars - Strongly Typed IDs
// =============================================================================
// The semantic-conventions pin lives in the generated keys header and is
// machine-checked; a hand-maintained enum of upstream releases would only drift.

@doc("Unique trace identifier (32 lowercase hex characters)")
@pattern("^[a-f0-9]{32}$")
@minLength(32)
@maxLength(32)
@example("0af7651916cd43dd8448eb211c80319c")
@TypeSpec.OpenAPI.extension("x-csharp-struct", true)
@TypeSpec.OpenAPI.extension("x-csharp-type", "TraceId")
scalar TraceId extends string;

@doc("Unique span identifier (16 lowercase hex characters)")
@pattern("^[a-f0-9]{16}$")
@minLength(16)
@maxLength(16)
@example("b7ad6b7169203331")
@TypeSpec.OpenAPI.extension("x-csharp-struct", true)
@TypeSpec.OpenAPI.extension("x-csharp-type", "SpanId")
scalar SpanId extends string;

@doc("W3C Trace Context traceparent header format")
@pattern("^[0-9a-f]{2}-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}$")
@example("00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01")
scalar TraceParent extends string;

@doc("W3C Trace Context tracestate header (vendor-specific key-value pairs)")
@example("rojo=00f067aa0ba902b7,congo=t61rcWkgMzE")
scalar TraceState extends string;

@doc("Unique session identifier")
@minLength(1)
@maxLength(128)
@TypeSpec.OpenAPI.extension("x-csharp-struct", true)
@TypeSpec.OpenAPI.extension("x-csharp-type", "SessionId")
scalar SessionId extends string;

@doc("User identifier (pseudonymized for privacy)")
@minLength(1)
@maxLength(256)
scalar UserId extends string;

// =============================================================================
// Temporal Scalars - Timestamps & Durations
// =============================================================================

@doc("ISO 8601 timestamp with nanosecond precision (RFC 3339)")
@encode(DateTimeKnownEncoding.rfc3339)
scalar Timestamp extends utcDateTime;

@doc("Unsigned Unix timestamp in nanoseconds since epoch")
@minValue(0)
@TypeSpec.OpenAPI.extension("x-csharp-type", "ulong")
scalar UnixNanos extends uint64;

@doc("Duration in nanoseconds")
@minValue(0)
@TypeSpec.OpenAPI.extension("x-csharp-type", "ulong")
scalar DurationNs extends uint64;

@doc("Duration in milliseconds")
@minValue(0)
@TypeSpec.OpenAPI.extension("x-csharp-type", "double")
scalar DurationMs extends float64;

@doc("Duration in seconds")
@minValue(0)
scalar DurationS extends float64;

@doc("ISO 8601 duration format (e.g., PT1H30M)")
@encode(DurationKnownEncoding.ISO8601)
scalar IsoDuration extends duration;

// =============================================================================
// Network Scalars - IP Addresses & Ports
// =============================================================================

@doc("IPv4 address in dotted-decimal notation")
@pattern("^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$")
@example("192.168.1.1")
scalar IPv4Address extends string;

@doc("IPv6 address in standard notation")
@example("2001:0db8:85a3:0000:0000:8a2e:0370:7334")
scalar IPv6Address extends string;

@doc("IP address (IPv4 or IPv6)")
scalar IpAddress extends string;

@doc("Network port number (1-65535)")
@minValue(1)
@maxValue(65535)
@TypeSpec.OpenAPI.extension("x-csharp-type", "int")
scalar Port extends int32;

@doc("MAC address in colon-separated hex notation")
@pattern("^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$")
@example("00:1A:2B:3C:4D:5E")
scalar MacAddress extends string;

// =============================================================================
// Size & Count Scalars
// =============================================================================

@doc("Size in bytes")
@minValue(0)
@TypeSpec.OpenAPI.extension("x-csharp-type", "long")
scalar ByteSize extends int64;

@doc("Token count (for LLM operations)")
@minValue(0)
@TypeSpec.OpenAPI.extension("x-csharp-type", "long")
scalar TokenCount extends int64;

@doc("Generic non-negative counter")
@minValue(0)
@TypeSpec.OpenAPI.extension("x-csharp-type", "long")
scalar Count extends int64;

@doc("Percentage value (0.0 to 100.0)")
@minValue(0.0)
@maxValue(100.0)
@TypeSpec.OpenAPI.extension("x-csharp-type", "double")
scalar Percentage extends float64;

@doc("Ratio value (0.0 to 1.0)")
@minValue(0.0)
@maxValue(1.0)
@TypeSpec.OpenAPI.extension("x-csharp-type", "double")
scalar Ratio extends float64;

// =============================================================================
// GenAI-Specific Scalars
// =============================================================================

@doc("Cost in USD (floating point)")
@minValue(0)
@TypeSpec.OpenAPI.extension("x-csharp-type", "double")
scalar CostUsd extends float64;

@doc("Temperature setting for LLM requests (0.0-2.0)")
@minValue(0)
@maxValue(2)
@TypeSpec.OpenAPI.extension("x-csharp-type", "double")
scalar Temperature extends float64;

// =============================================================================
// Semantic Scalars - Special Purpose Types
// =============================================================================

@doc("SHA-256 hash in lowercase hex")
@pattern("^[a-f0-9]{64}$")
@minLength(64)
@maxLength(64)
scalar Sha256Hash extends string;

@doc("Semantic version string (e.g., 1.2.3)")
@pattern("^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)(?:-((?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\\.(?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\\+([0-9a-zA-Z-]+(?:\\.[0-9a-zA-Z-]+)*))?$")
@example("2.1.0")
scalar SemVer extends string;

@doc("URL string (absolute)")
@format("uri")
scalar UrlString extends string;

@doc("URL path component")
@example("/api/v1/users")
scalar UrlPath extends string;

@doc("URL query string (without leading ?)")
@example("page=1&limit=100")
scalar UrlQuery extends string;

@doc("HTTP method name (uppercase)")
@example("GET")
scalar HttpMethod extends string;

@doc("MIME content type")
@example("application/json")
scalar ContentType extends string;

@doc("User agent string")
@example("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
scalar UserAgent extends string;

@doc("Language/locale code (BCP 47)")
@pattern("^[a-z]{2,3}(-[A-Z]{2})?$")
@example("en-US")
scalar LanguageCode extends string;

// =============================================================================
// OpenTelemetry Attribute Value Types
// =============================================================================

@doc("Base64 bytes projected by qyl without colliding with an ordinary string attribute.")
model AttributeBytesValue {
  type: "bytes";
  base64: bytes;
}

@doc("An OTLP signed 64-bit attribute integer encoded without JavaScript precision loss.")
@encode(string)
@TypeSpec.OpenAPI.extension("x-csharp-type", "long")
scalar AttributeInt64 extends int64;

@doc("An OTLP attribute double encoded as a JSON number when finite or a canonical named string when non-finite.")
union AttributeDouble {
  finite: float64,
  nan: "NaN",
  positiveInfinity: "Infinity",
  negativeInfinity: "-Infinity",
}

@doc("Tagged OTLP signed 64-bit integer attribute.")
model AttributeIntValue {
  type: "int";
  value: AttributeInt64;
}

@doc("Tagged OTLP double attribute.")
model AttributeDoubleValue {
  type: "double";
  value: AttributeDouble;
}

@doc("Tagged recursive OTLP key-value-list, distinct from other object-shaped attribute variants.")
model AttributeKeyValueListValue {
  type: "kvlist";
  values: Record<AttributeValue>;
}

@doc("Lossless JSON projection of an OpenTelemetry AnyValue attribute.")
union AttributeValue {
  @doc("Empty AnyValue")
  emptyValue: null,

  @doc("String value")
  stringValue: string,

  @doc("Boolean value")
  boolValue: boolean,

  @doc("Lossless 64-bit integer value")
  intValue: AttributeIntValue,

  @doc("Lossless finite or non-finite 64-bit floating point value")
  doubleValue: AttributeDoubleValue,

  @doc("Bytes value projected as an explicit tagged object")
  bytesValue: AttributeBytesValue,

  @doc("Nested and heterogeneous array value")
  arrayValue: AttributeValue[],

  @doc("Recursive key-value-list value")
  keyValueListValue: AttributeKeyValueListValue,
}

@doc("Key-value attribute pair following OTel conventions")
model Attribute {
  @doc("Attribute key (dot-separated namespace)")
  @minLength(1)
  @maxLength(256)
  key: string;

  @doc("Attribute value")
  value: AttributeValue;
}

@doc("Collection of attributes")
model Attributes {
  @doc("List of key-value attributes")
  items: Attribute[];
}

@doc("A non-empty Resource attribute key referenced by an OpenTelemetry entity.")
@minLength(1)
scalar EntityAttributeKey extends string;

@doc("A reference to an OpenTelemetry entity described by attributes on the containing Resource.")
model EntityRef {
  @doc("Schema URL applying to the entity and its referenced Resource attributes, when known.")
  @encodedName("application/json", "schema_url")
  schemaUrl?: string;

  @doc("Stable non-empty entity type, such as service or host.")
  @minLength(1)
  type: string;

  @doc("Non-empty set of Resource attribute keys that identify the entity.")
  @encodedName("application/json", "id_keys")
  @minItems(1)
  idKeys: EntityAttributeKey[];

  @doc("Resource attribute keys that describe but do not identify the entity.")
  @encodedName("application/json", "description_keys")
  descriptionKeys?: EntityAttributeKey[];
}

// =============================================================================
// Instrumentation Scope
// =============================================================================

@doc("Instrumentation scope identifying the library/component emitting telemetry")
model InstrumentationScope {
  @doc("Name of the instrumentation scope (library name)")
  @encodedName("application/json", "name")
  scopeName: string;

  @doc("Version of the instrumentation scope")
  @encodedName("application/json", "version")
  scopeVersion?: SemVer;

  @doc("Additional attributes for the scope")
  @encodedName("application/json", "attributes")
  scopeAttributes?: Attribute[];

  @doc("Dropped attributes count")
  @encodedName("application/json", "dropped_attributes_count")
  droppedAttributesCount?: Count;
}
