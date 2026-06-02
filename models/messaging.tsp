// =============================================================================
// ANcpLua v2.0 - Messaging Semantic Conventions (OTel v1.40)
// =============================================================================
// Message broker and queue telemetry attributes.
// =============================================================================

import "../common/types.tsp";

using Qyl.Api.Contracts.Common;

namespace Qyl.Api.Contracts.Domains.Transport.Messaging;

// =============================================================================
// Messaging Span Attributes
// =============================================================================

@doc("Messaging span attributes")
model MessagingAttributes {
  @doc("The messaging system (e.g., kafka, rabbitmq, aws_sqs)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.System)
  system: MessagingSystem;

  @doc("Message destination name (queue or topic)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.DestinationName)
  destinationName?: string;

  @doc("Destination kind (queue or topic)")
  @encodedName("application/json", "messaging.destination.kind")
  destinationKind?: MessagingDestinationKind;

  @doc("Whether the destination is temporary")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.DestinationTemporary)
  destinationTemporary?: boolean;

  @doc("Whether the destination is anonymous")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.DestinationAnonymous)
  destinationAnonymous?: boolean;

  @doc("Partition number (for partitioned systems)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.DestinationPartitionId)
  destinationPartitionId?: string;

  @doc("Destination template (e.g., for subscription patterns)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.DestinationTemplate)
  destinationTemplate?: string;

  @doc("Message ID")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.MessageId)
  messageId?: string;

  @doc("Conversation/correlation ID")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.MessageConversationId)
  messageConversationId?: string;

  @doc("Message body size in bytes")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.MessageBodySize)
  messageBodySize?: ByteSize;

  @doc("Total message size including metadata")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.MessageEnvelopeSize)
  messageEnvelopeSize?: ByteSize;

  @doc("Messaging operation type")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.OperationType)
  operationType?: MessagingOperationType;

  @doc("Operation name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.OperationName)
  operationName?: string;

  @doc("Batch message count")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.BatchMessageCount)
  batchMessageCount?: int32;

  @doc("Consumer group name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.ConsumerGroupName)
  consumerGroupName?: string;

  @doc("Consumer ID")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.ClientId)
  clientId?: string;

  // ---------------------------------------------------------------------------
  // Kafka-Specific Attributes
  // ---------------------------------------------------------------------------

  @doc("Kafka consumer group")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.KafkaConsumerGroup)
  kafkaConsumerGroup?: string;

  @doc("Kafka message key")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.KafkaMessageKey)
  kafkaMessageKey?: string;

  @doc("Kafka message offset")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.KafkaMessageOffset)
  kafkaMessageOffset?: int64;

  @doc("Kafka message tombstone")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.KafkaMessageTombstone)
  kafkaMessageTombstone?: boolean;

  // ---------------------------------------------------------------------------
  // RabbitMQ-Specific Attributes
  // ---------------------------------------------------------------------------

  @doc("RabbitMQ delivery tag")
  @encodedName("application/json", "messaging.rabbitmq.delivery_tag")
  rabbitmqDeliveryTag?: int64;

  @doc("RabbitMQ routing key")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.RabbitmqDestinationRoutingKey)
  rabbitmqRoutingKey?: string;

  // ---------------------------------------------------------------------------
  // AWS SQS/SNS-Specific Attributes
  // ---------------------------------------------------------------------------

  @doc("AWS SQS message group ID")
  @encodedName("application/json", "messaging.aws_sqs.message.group_id")
  awsSqsMessageGroupId?: string;

  @doc("AWS SQS message deduplication ID")
  @encodedName("application/json", "messaging.aws_sqs.message.deduplication_id")
  awsSqsMessageDeduplicationId?: string;

  // ---------------------------------------------------------------------------
  // Azure Service Bus-Specific Attributes
  // ---------------------------------------------------------------------------

  @doc("Azure Service Bus message enqueued time")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.ServicebusMessageEnqueuedTime)
  servicebusEnqueuedTime?: utcDateTime;
}

// =============================================================================
// Messaging Enumerations
// =============================================================================

@doc("Messaging systems")
enum MessagingSystem {
  @doc("Apache Kafka")
  kafka: "kafka",

  @doc("RabbitMQ")
  rabbitmq: "rabbitmq",

  @doc("Amazon SQS")
  awsSqs: "aws_sqs",

  @doc("Amazon SNS")
  awsSns: "aws_sns",

  @doc("Azure Service Bus")
  azureServiceBus: "azure_servicebus",

  @doc("Azure Event Hubs")
  azureEventHubs: "azure_eventhubs",

  @doc("Google Cloud Pub/Sub")
  gcpPubsub: "gcp_pubsub",

  @doc("Apache ActiveMQ")
  activemq: "activemq",

  @doc("Apache ActiveMQ Artemis")
  activemqArtemis: "activemq_artemis",

  @doc("Redis Pub/Sub")
  redisPubsub: "redis_pubsub",

  @doc("Redis Streams")
  redisStreams: "redis_streams",

  @doc("NATS")
  nats: "nats",

  @doc("Pulsar")
  pulsar: "pulsar",

  @doc("JMS")
  jms: "jms",

  @doc("IBM MQ")
  ibmmq: "ibmmq",

  @doc("RocketMQ")
  rocketmq: "rocketmq",
}

@doc("Messaging destination kinds")
enum MessagingDestinationKind {
  @doc("Queue (point-to-point)")
  queue: "queue",

  @doc("Topic (publish-subscribe)")
  topic: "topic",
}

@doc("Messaging operation types")
enum MessagingOperationType {
  @doc("Message publish/send")
  publish: "publish",

  @doc("Message receive (non-blocking)")
  receive: "receive",

  @doc("Message process (blocking consumer)")
  process: "process",

  @doc("Create destination")
  create: "create",

  @doc("Settle/acknowledge message")
  settle: "settle",
}

@doc("Message delivery guarantees")
enum MessagingDeliveryGuarantee {
  @doc("At most once delivery")
  atMostOnce: "at_most_once",

  @doc("At least once delivery")
  atLeastOnce: "at_least_once",

  @doc("Exactly once delivery")
  exactlyOnce: "exactly_once",
}

// =============================================================================
// Messaging Metrics
// =============================================================================

@doc("Messaging publish duration metric")
model MessagingPublishDurationMetric {
  @doc("Metric name")
  name: "messaging.publish.duration";

  @doc("Metric unit (seconds)")
  unit: "s";

  @doc("Messaging system")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.System)
  system: MessagingSystem;

  @doc("Destination name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.DestinationName)
  destinationName: string;
}

@doc("Messaging receive duration metric")
model MessagingReceiveDurationMetric {
  @doc("Metric name")
  name: "messaging.receive.duration";

  @doc("Metric unit (seconds)")
  unit: "s";

  @doc("Messaging system")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.System)
  system: MessagingSystem;

  @doc("Destination name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.DestinationName)
  destinationName: string;

  @doc("Consumer group")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.ConsumerGroupName)
  consumerGroupName?: string;
}

@doc("Messaging process duration metric")
model MessagingProcessDurationMetric {
  @doc("Metric name")
  name: "messaging.process.duration";

  @doc("Metric unit (seconds)")
  unit: "s";

  @doc("Messaging system")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.System)
  system: MessagingSystem;

  @doc("Destination name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.DestinationName)
  destinationName: string;
}

@doc("Messaging publish messages metric")
model MessagingPublishMessagesMetric {
  @doc("Metric name")
  name: "messaging.publish.messages";

  @doc("Metric unit")
  unit: "{message}";

  @doc("Messaging system")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.System)
  system: MessagingSystem;

  @doc("Destination name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Messaging.DestinationName)
  destinationName: string;
}
