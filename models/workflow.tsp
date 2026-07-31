import "../common/types.tsp";

using Qyl.Api.Contracts.Common;

namespace Qyl.Api.Contracts.Workflow;

@doc("Stable identifier of one observed Codex workflow run.")
@minLength(1)
@maxLength(128)
scalar WorkflowRunId extends string;

@doc("Opaque incarnation identifier for one workflow run's projected state.")
@pattern("^[0-9a-f]{12}4[0-9a-f]{3}[89ab][0-9a-f]{15}$")
@minLength(32)
@maxLength(32)
scalar WorkflowGeneration extends string;

@doc("Opaque workflow-run list continuation scoped to the project and status filter. Reuse it unchanged; clients must not parse or construct it.")
@minLength(1)
@maxLength(512)
scalar WorkflowRunCursor extends string;

@doc("Stable identifier of one workflow attempt.")
@minLength(1)
@maxLength(128)
scalar WorkflowAttemptId extends string;

@doc("Stable identifier of one agent within a workflow run.")
@minLength(1)
@maxLength(128)
scalar WorkflowAgentId extends string;

@doc("Stable identifier of one tool call within a workflow run.")
@minLength(1)
@maxLength(128)
scalar WorkflowToolCallId extends string;

@doc("Stable identifier of one immutable journal event.")
@minLength(1)
@maxLength(160)
scalar WorkflowEventId extends string;

@doc("Stable identifier of one run-level control command.")
@minLength(1)
@maxLength(128)
scalar WorkflowCommandId extends string;

@doc("Stable identifier of one graph node. Canonical tuples structurally distinguish run scope from attempt scope, escape colon as \\c and backslash as \\\\, and never infer scope from a literal component value. A canonical identifier over 192 Unicode scalar values is replaced by its kind, a tilde, and the full lowercase 64-hex SHA-256 of the length-prefixed canonical tuple.")
@minLength(1)
@maxLength(192)
scalar WorkflowNodeId extends string;

@doc("Stable identifier of one graph edge. Endpoint tuples preserve the nodes' structural run-versus-attempt scope and ordinal component boundaries, escape colon as \\c and backslash as \\\\, and never infer scope from a literal component value. A canonical identifier over 192 Unicode scalar values is replaced by its edge kind, a tilde, and the full lowercase 64-hex SHA-256 of the length-prefixed canonical tuple.")
@minLength(1)
@maxLength(192)
scalar WorkflowEdgeId extends string;

@doc("Opaque node-page continuation scoped to one workflow run and generation. Reuse it unchanged; clients must not parse or construct it.")
@minLength(1)
@maxLength(1536)
scalar WorkflowNodeCursor extends string;

@doc("Opaque edge-page continuation scoped to one workflow run and generation. Reuse it unchanged; clients must not parse or construct it.")
@minLength(1)
@maxLength(1536)
scalar WorkflowEdgeCursor extends string;

@doc("Content-addressed reference to a captured workflow payload.")
@pattern("^sha256:[a-f0-9]{64}$")
@minLength(71)
@maxLength(71)
scalar WorkflowContentRef extends string;

@doc("Unsigned source or collector journal sequence encoded without JavaScript precision loss.")
@minValue(0)
@encode(string)
scalar WorkflowSequence extends uint64;

@doc("Collector-assigned position in the authoritative workflow journal, encoded without JavaScript precision loss.")
@minValue(0)
@encode(string)
scalar WorkflowJournalPosition extends uint64;

@doc("Current lifecycle of a workflow run.")
enum WorkflowRunStatus {
  active: "active",
  completed: "completed",
  failed: "failed",
  interrupted: "interrupted",
}

@doc("Current lifecycle of one workflow attempt.")
enum WorkflowAttemptStatus {
  pending: "pending",
  running: "running",
  succeeded: "succeeded",
  failed: "failed",
  interrupted: "interrupted",
}

@doc("Current lifecycle of an observed workflow agent.")
enum WorkflowAgentStatus {
  pending: "pending",
  running: "running",
  waiting: "waiting",
  succeeded: "succeeded",
  failed: "failed",
  interrupted: "interrupted",
}

@doc("Current lifecycle of an observed tool call.")
enum WorkflowToolCallStatus {
  requested: "requested",
  running: "running",
  succeeded: "succeeded",
  failed: "failed",
  rejected: "rejected",
}

@doc("Kinds of execution node in the deterministic workflow graph.")
enum WorkflowNodeKind {
  run: "run",
  attempt: "attempt",
  turn: "turn",
  agent: "agent",
  toolCall: "tool_call",
  message: "message",
  wait: "wait",
  gate: "gate",
  resource: "resource",
}

@doc("Semantic relationship represented by a workflow graph edge.")
enum WorkflowEdgeKind {
  data: "data",
  control: "control",
  conflict: "conflict",
  resource: "resource",
  gate: "gate",
  temporal: "temporal",
}

@doc("Immutable journal event kinds accepted from a Codex observer.")
enum WorkflowJournalEventKind {
  runCreated: "run_created",
  runCompleted: "run_completed",
  threadStarted: "thread_started",
  threadResumed: "thread_resumed",
  turnStarted: "turn_started",
  turnCompleted: "turn_completed",
  turnInterrupted: "turn_interrupted",
  attemptStarted: "attempt_started",
  attemptCompleted: "attempt_completed",
  agentSpawned: "agent_spawned",
  agentStarted: "agent_started",
  agentCompleted: "agent_completed",
  messageSent: "message_sent",
  messageReceived: "message_received",
  waitStarted: "wait_started",
  waitCompleted: "wait_completed",
  joined: "joined",
  itemStarted: "item_started",
  itemCompleted: "item_completed",
  toolStarted: "tool_started",
  toolCompleted: "tool_completed",
  approvalRequested: "approval_requested",
  approvalResolved: "approval_resolved",
  contentCaptured: "content_captured",
  fileWritten: "file_written",
  controlRequested: "control_requested",
  controlAccepted: "control_accepted",
  controlApplied: "control_applied",
  controlRejected: "control_rejected",
  controlFailed: "control_failed",
}

@doc("Control operation supported by the Codex app-server boundary.")
enum WorkflowControlAction {
  steer: "steer",
  interrupt: "interrupt",
  resume: "resume",
}

@doc("Durable lifecycle of a workflow control command.")
enum WorkflowControlStatus {
  requested: "requested",
  accepted: "accepted",
  applied: "applied",
  rejected: "rejected",
  failed: "failed",
}

@doc("Encoding used when lazily returning captured workflow content.")
enum WorkflowContentEncoding {
  utf8: "utf8",
  base64: "base64",
}

@doc("A valid committed projection that can be served to readers.")
model CommittedWorkflowProjectionStatus {
  state: "committed";
  generation: WorkflowGeneration;

  @encodedName("application/json", "journal_position")
  journalPosition: WorkflowJournalPosition;
}

@doc("The requested generation is being reconstructed from its authoritative journal.")
model RebuildingWorkflowProjectionStatus {
  state: "rebuilding";
  generation: WorkflowGeneration;

  @encodedName("application/json", "target_journal_position")
  targetJournalPosition: WorkflowJournalPosition;

  @encodedName("application/json", "retry_after_ms")
  @minValue(1)
  retryAfterMs: int32;
}

@doc("Projection work is temporarily unavailable after a retryable storage failure.")
model UnavailableWorkflowProjectionStatus {
  state: "unavailable";
  generation?: WorkflowGeneration;

  @encodedName("application/json", "retry_after_ms")
  @minValue(1)
  retryAfterMs: int32;
}

@doc("Derived projection state is corrupt or incompatible and cannot currently be served.")
model CorruptWorkflowProjectionStatus {
  state: "corrupt";
  generation?: WorkflowGeneration;
  reason: "corrupt_derived_state" | "incompatible_derived_state";
}

@doc("Closed public availability state for one workflow projection. Storage paths, hashes, fingerprints, and database errors remain private.")
union WorkflowProjectionStatus {
  committed: CommittedWorkflowProjectionStatus,
  rebuilding: RebuildingWorkflowProjectionStatus,
  unavailable: UnavailableWorkflowProjectionStatus,
  corrupt: CorruptWorkflowProjectionStatus,
}

@doc("One immutable workflow run.")
model WorkflowRun {
  @encodedName("application/json", "run_id")
  runId: WorkflowRunId;

  generation: WorkflowGeneration;

  @encodedName("application/json", "thread_id")
  threadId?: string;

  title?: string;
  status: WorkflowRunStatus;

  @encodedName("application/json", "started_at")
  startedAt: utcDateTime;

  @encodedName("application/json", "ended_at")
  endedAt?: utcDateTime;

  @encodedName("application/json", "latest_journal_sequence")
  latestJournalSequence: WorkflowJournalPosition;

  @encodedName("application/json", "active_attempt_id")
  activeAttemptId?: WorkflowAttemptId;

  metadata?: Record<unknown>;
}

@doc("Request to create an observed workflow run before appending journal events.")
model WorkflowRunCreateRequest {
  @encodedName("application/json", "run_id")
  runId: WorkflowRunId;

  @encodedName("application/json", "thread_id")
  threadId?: string;

  title?: string;

  @encodedName("application/json", "started_at")
  startedAt: utcDateTime;

  metadata?: Record<unknown>;
}

@doc("Cursor page of workflow runs.")
model WorkflowRunPage {
  items: WorkflowRun[];

  @encodedName("application/json", "next_cursor")
  nextCursor?: WorkflowRunCursor;

  @encodedName("application/json", "has_more")
  hasMore: boolean;
}

@doc("One captured payload supplied with an append batch.")
model WorkflowContentChunk {
  @encodedName("application/json", "content_ref")
  contentRef: WorkflowContentRef;

  @encodedName("application/json", "content_type")
  contentType: ContentType;

  encoding: WorkflowContentEncoding;

  @doc("UTF-8 text or base64 bytes, according to encoding.")
  @maxLength(1398104)
  content: string;
}

@doc("One source-ordered immutable journal event awaiting collector sequence assignment.")
model WorkflowEventAppend {
  @encodedName("application/json", "event_id")
  eventId: WorkflowEventId;

  @encodedName("application/json", "source_sequence")
  sourceSequence: WorkflowSequence;

  timestamp: utcDateTime;
  kind: WorkflowJournalEventKind;

  @encodedName("application/json", "thread_id")
  threadId?: string;

  @encodedName("application/json", "turn_id")
  turnId?: string;

  @encodedName("application/json", "attempt_id")
  attemptId?: WorkflowAttemptId;

  @encodedName("application/json", "agent_id")
  agentId?: WorkflowAgentId;

  @encodedName("application/json", "parent_agent_id")
  parentAgentId?: WorkflowAgentId;

  @encodedName("application/json", "receiver_agent_id")
  receiverAgentId?: WorkflowAgentId;

  @encodedName("application/json", "tool_call_id")
  toolCallId?: WorkflowToolCallId;

  @encodedName("application/json", "content_refs")
  @maxItems(64)
  contentRefs?: WorkflowContentRef[];

  data?: Record<unknown>;
}

@doc("Idempotent append batch from one observer client.")
model WorkflowEventBatchAppendRequest {
  @encodedName("application/json", "client_id")
  @minLength(1)
  @maxLength(128)
  clientId: string;

  @minItems(1)
  @maxItems(500)
  events: WorkflowEventAppend[];

  @maxItems(500)
  content?: WorkflowContentChunk[];
}

@doc("Collector acknowledgement for an idempotent workflow-event append.")
model WorkflowEventBatchAppendResponse {
  @encodedName("application/json", "accepted_count")
  @minValue(0)
  acceptedCount: int32;

  @encodedName("application/json", "duplicate_count")
  @minValue(0)
  duplicateCount: int32;

  @encodedName("application/json", "acknowledged_source_sequence")
  acknowledgedSourceSequence: WorkflowSequence;

  @encodedName("application/json", "first_journal_sequence")
  firstJournalSequence?: WorkflowJournalPosition;

  @encodedName("application/json", "last_journal_sequence")
  lastJournalSequence?: WorkflowJournalPosition;
}

@doc("One immutable event after collector journal sequence assignment.")
model WorkflowJournalEvent extends WorkflowEventAppend {
  @encodedName("application/json", "run_id")
  runId: WorkflowRunId;

  @encodedName("application/json", "client_id")
  clientId: string;

  @encodedName("application/json", "journal_sequence")
  journalSequence: WorkflowJournalPosition;
}

@doc("A bounded page of workflow journal events.")
model WorkflowEventPage {
  events: WorkflowJournalEvent[];

  @encodedName("application/json", "next_sequence")
  nextSequence: WorkflowJournalPosition;

  @encodedName("application/json", "high_water_mark")
  highWaterMark: WorkflowJournalPosition;

  @encodedName("application/json", "cursor_gap")
  cursorGap: boolean;
}

@doc("Recorded edge provenance directly observed from Codex.")
model RecordedWorkflowEdgeProvenance {
  type: "recorded";

  @encodedName("application/json", "event_ids")
  @minItems(1)
  eventIds: WorkflowEventId[];
}

@doc("Derived edge provenance with explicit evidence and confidence.")
model DerivedWorkflowEdgeProvenance {
  type: "derived";

  @encodedName("application/json", "event_ids")
  @minItems(1)
  eventIds: WorkflowEventId[];

  evidence: string;
  confidence: Ratio;
}

@doc("Provenance for one workflow graph edge.")
union WorkflowEdgeProvenance {
  recorded: RecordedWorkflowEdgeProvenance,
  derived: DerivedWorkflowEdgeProvenance,
}

@doc("One node in the deterministic workflow graph projection.")
model WorkflowGraphNode {
  @encodedName("application/json", "node_id")
  nodeId: WorkflowNodeId;

  kind: WorkflowNodeKind;
  label: string;
  status: string;

  @encodedName("application/json", "attempt_id")
  attemptId?: WorkflowAttemptId;

  @encodedName("application/json", "agent_id")
  agentId?: WorkflowAgentId;

  @encodedName("application/json", "started_at")
  startedAt?: utcDateTime;

  @encodedName("application/json", "ended_at")
  endedAt?: utcDateTime;

  @encodedName("application/json", "duration_ms")
  durationMs?: DurationMs;

  @encodedName("application/json", "content_refs")
  contentRefs?: WorkflowContentRef[];

  attributes?: Record<unknown>;
}

@doc("One typed edge in the deterministic workflow graph projection. Data, Control, and Gate edges are causal dependencies. Temporal edges describe observed order, Resource edges describe resource use, and Conflict edges describe contention; Temporal, Resource, and Conflict edges are excluded from critical-path causality.")
model WorkflowGraphEdge {
  @encodedName("application/json", "edge_id")
  edgeId: WorkflowEdgeId;

  @encodedName("application/json", "source_node_id")
  sourceNodeId: WorkflowNodeId;

  @encodedName("application/json", "target_node_id")
  targetNodeId: WorkflowNodeId;

  kind: WorkflowEdgeKind;
  provenance: WorkflowEdgeProvenance;
}

@doc("Work and critical-path statistics for a workflow graph. Every ToolCall, Wait, Gate, and duration-bearing Message or Item contributes an independently weighted interval even when it has no Agent owner. An Agent contributes its own-work fragments: its interval minus the union of precisely owned child intervals clipped to the Agent interval. Precisely owned children are Control-linked Agent and ToolCall nodes, Temporal-linked Wait nodes, Gate-linked Gate nodes, and Data-linked duration-bearing Message or Item nodes. Peak concurrency sweeps every positive independently weighted or Agent own-work fragment. Critical-path analysis uses only Data, Control, and Gate edges, condenses each causal strongly connected component, charges every component member exactly once, and expands selected component members in ordinal node-id order.")
model WorkflowGraphStatistics {
  @encodedName("application/json", "t1_ms")
  t1Ms: DurationMs;

  @encodedName("application/json", "t_infinity_ms")
  tInfinityMs: DurationMs;

  @encodedName("application/json", "wall_time_ms")
  wallTimeMs: DurationMs;

  @encodedName("application/json", "peak_concurrency")
  @minValue(0)
  peakConcurrency: int32;

  @encodedName("application/json", "worker_count")
  @minValue(1)
  workerCount: int32;

  @encodedName("application/json", "parallel_lower_bound_ms")
  parallelLowerBoundMs: DurationMs;

  @encodedName("application/json", "critical_path_node_ids")
  criticalPathNodeIds: WorkflowNodeId[];
}

@doc("Deterministic graph projection at one journal cursor.")
model WorkflowGraphSnapshot {
  run: WorkflowRun;

  @encodedName("application/json", "projection_status")
  projectionStatus: WorkflowProjectionStatus;
  nodes: WorkflowGraphNode[];
  edges: WorkflowGraphEdge[];
  statistics: WorkflowGraphStatistics;

  @encodedName("application/json", "journal_sequence")
  journalSequence: WorkflowJournalPosition;

  @encodedName("application/json", "next_node_cursor")
  @doc("Opaque node continuation for the next page. Reuse it unchanged as node_cursor on the next graph request; do not parse, construct, or modify it.")
  nextNodeCursor?: WorkflowNodeCursor;

  @encodedName("application/json", "next_edge_cursor")
  @doc("Opaque edge continuation for the next page. Reuse it unchanged as edge_cursor on the next graph request; do not parse, construct, or modify it.")
  nextEdgeCursor?: WorkflowEdgeCursor;

  @encodedName("application/json", "has_more_nodes")
  hasMoreNodes: boolean;

  @encodedName("application/json", "has_more_edges")
  hasMoreEdges: boolean;

  @encodedName("application/json", "total_node_count")
  @minValue(0)
  totalNodeCount: int32;

  @encodedName("application/json", "total_edge_count")
  @minValue(0)
  totalEdgeCount: int32;
}

@doc("Lazily retrieved captured workflow content.")
model WorkflowContent {
  @encodedName("application/json", "content_ref")
  contentRef: WorkflowContentRef;

  @encodedName("application/json", "content_type")
  contentType: ContentType;

  encoding: WorkflowContentEncoding;
  content: string;

  @encodedName("application/json", "size_bytes")
  sizeBytes: ByteSize;
}

@doc("Request to enqueue one idempotent run-level control command.")
model WorkflowControlRequest {
  action: WorkflowControlAction;

  @encodedName("application/json", "idempotency_key")
  @minLength(1)
  @maxLength(160)
  idempotencyKey: string;

  @doc("Text appended by steer or resume. Omit for interrupt.")
  @maxLength(32768)
  input?: string;
}

@doc("Durable run-level control command.")
model WorkflowControlCommand {
  @encodedName("application/json", "command_id")
  commandId: WorkflowCommandId;

  @encodedName("application/json", "run_id")
  runId: WorkflowRunId;

  action: WorkflowControlAction;
  status: WorkflowControlStatus;

  @encodedName("application/json", "idempotency_key")
  idempotencyKey: string;

  input?: string;

  @encodedName("application/json", "requested_at")
  requestedAt: utcDateTime;

  @encodedName("application/json", "updated_at")
  updatedAt: utcDateTime;

  @encodedName("application/json", "command_sequence")
  commandSequence: WorkflowSequence;

  error?: string;
}

@doc("Page of control commands polled by the launcher-owned outbound adapter.")
model WorkflowControlCommandPage {
  commands: WorkflowControlCommand[];

  @encodedName("application/json", "next_sequence")
  nextSequence: WorkflowSequence;
}

@doc("Adapter acknowledgement or terminal result for one control command.")
model WorkflowControlStatusUpdateRequest {
  status: WorkflowControlStatus;
  error?: string;

  @doc("""
    When the reported transition actually occurred at the adapter that executed
    it. The journal event minted for this transition carries this clock — the
    originating agent's — so control events order and measure consistently with
    the agent-clocked events around them; omitted, the collector's receipt time
    is the fallback.
    """)
  @encodedName("application/json", "occurred_at")
  occurredAt?: utcDateTime;
}
