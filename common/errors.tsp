// =============================================================================
// ANcpLua v2.0 - Error Models
// =============================================================================
// Standardized error responses following RFC 7807 Problem Details.
// =============================================================================

import "@typespec/http";

using TypeSpec.Http;

namespace Qyl.Api.Contracts.Common.Errors;

// =============================================================================
// RFC 7807 Problem Details Base
// =============================================================================

@doc("RFC 7807 Problem Details for HTTP APIs")
@error
model ProblemDetails {
  @doc("A URI reference identifying the problem type")
  @encodedName("application/json", "type")
  problemType: url = "about:blank";

  @doc("A short, human-readable summary of the problem type")
  title: string;

  @doc("The HTTP status code (informational only, actual code set by subtype)")
  status: int32;

  @doc("A human-readable explanation specific to this occurrence")
  detail?: string;

  @doc("A URI reference identifying the specific occurrence")
  instance?: url;

  @doc("Trace ID for correlation")
  @encodedName("application/json", "trace_id")
  @header("X-Trace-Id")
  traceId?: string;

  @doc("Request ID for support")
  @encodedName("application/json", "request_id")
  @header("X-Request-Id")
  requestId?: string;

  @doc("Timestamp of the error")
  timestamp?: utcDateTime;
}

// =============================================================================
// Specific Error Types
// =============================================================================

@doc("Resource not found (404)")
@error
model NotFoundError extends ProblemDetails {
  @statusCode _: 404;
  title: "Not Found";

  @doc("The type of resource that was not found")
  @encodedName("application/json", "resource_type")
  resourceType?: string;

  @doc("The identifier that was not found")
  @encodedName("application/json", "resource_id")
  resourceId?: string;
}

@doc("Bad request - validation failed (400)")
@error
model ValidationError extends ProblemDetails {
  @statusCode _: 400;
  title: "Validation Failed";

  @doc("List of validation errors")
  errors: ValidationErrorDetail[];
}

@doc("Individual validation error detail")
model ValidationErrorDetail {
  @doc("The field/property that failed validation")
  field: string;

  @doc("The error message")
  message: string;

  @doc("The validation rule that failed")
  code: string;

  @doc("The rejected value (if safe to include)")
  @encodedName("application/json", "rejected_value")
  rejectedValue?: string;
}

@doc("Unauthorized - authentication required (401)")
@error
model UnauthorizedError extends ProblemDetails {
  @statusCode _: 401;
  title: "Unauthorized";

  @doc("Authentication scheme expected")
  @header("WWW-Authenticate")
  @encodedName("application/json", "www_authenticate")
  wwwAuthenticate?: string;
}

@doc("Forbidden - insufficient permissions (403)")
@error
model ForbiddenError extends ProblemDetails {
  @statusCode _: 403;
  title: "Forbidden";

  @doc("Required permission that is missing")
  @encodedName("application/json", "required_permission")
  requiredPermission?: string;
}

@doc("Conflict - resource state conflict (409)")
@error
model ConflictError extends ProblemDetails {
  @statusCode _: 409;
  title: "Conflict";

  @doc("The conflicting resource ID")
  @encodedName("application/json", "conflicting_resource")
  conflictingResource?: string;
}

@doc("Rate limited - too many requests (429)")
@error
model RateLimitError extends ProblemDetails {
  @statusCode _: 429;
  title: "Too Many Requests";

  @doc("Seconds until the rate limit resets")
  @header("Retry-After")
  @encodedName("application/json", "retry_after")
  retryAfter: int32;

  @doc("Maximum requests allowed per window")
  @header("X-RateLimit-Limit")
  @encodedName("application/json", "rate_limit")
  rateLimit?: int32;

  @doc("Remaining requests in current window")
  @header("X-RateLimit-Remaining")
  @encodedName("application/json", "rate_limit_remaining")
  rateLimitRemaining?: int32;
}

@doc("Internal server error (500)")
@error
model InternalServerError extends ProblemDetails {
  @statusCode _: 500;
  title: "Internal Server Error";

  @doc("Error code for support reference")
  @encodedName("application/json", "error_code")
  errorCode?: string;
}

@doc("Service unavailable (503)")
@error
model ServiceUnavailableError extends ProblemDetails {
  @statusCode _: 503;
  title: "Service Unavailable";

  @doc("Expected availability time")
  @header("Retry-After")
  @encodedName("application/json", "retry_after")
  retryAfter?: int32;

  @doc("Reason for unavailability")
  reason?: "maintenance" | "overloaded" | "dependency_failure";
}

// =============================================================================
// Error Response Union
// =============================================================================

@doc("Standard error response types")
union ApiError {
  @doc("Resource not found")
  notFound: NotFoundError,

  @doc("Validation failed")
  validation: ValidationError,

  @doc("Authentication required")
  unauthorized: UnauthorizedError,

  @doc("Permission denied")
  forbidden: ForbiddenError,

  @doc("Resource conflict")
  conflict: ConflictError,

  @doc("Rate limit exceeded")
  rateLimit: RateLimitError,

  @doc("Server error")
  serverError: InternalServerError,

  @doc("Service unavailable")
  unavailable: ServiceUnavailableError,
}
