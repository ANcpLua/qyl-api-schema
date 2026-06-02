// =============================================================================
// ANcpLua v2.0 - Database Semantic Conventions (OTel v1.40)
// =============================================================================
// Database telemetry attributes with 45+ DBMS types.
// =============================================================================

import "@typespec/versioning";
import "../common/types.tsp";

using TypeSpec.Versioning;
using Qyl.Api.Contracts.Common;

@versioned(DbVersions)
namespace Qyl.Api.Contracts.Domains.Data.Db;

// =============================================================================
// Version History
// =============================================================================

@doc("Database semantic convention versions")
enum DbVersions {
  @doc("Legacy DB semconv")
  v1_20: "1.20.0",

  @doc("Stable DB semconv with namespace")
  v1_24: "1.24.0",

  @doc("DB semconv v1.38")
  v1_38: "1.38.0",

  @doc("Current DB semconv")
  v1_39: "1.39.0",
}

// =============================================================================
// Database Span Attributes (Complete OTel v1.40)
// =============================================================================

@doc("Database span attributes following OTel Semantic Conventions v1.40")
model DbAttributes {
  // ---------------------------------------------------------------------------
  // System & Connection
  // ---------------------------------------------------------------------------

  @doc("Database management system identifier")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.SystemName)
  systemName: DbSystem;

  @doc("Database namespace (database name, schema, etc.)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.Namespace)
  `namespace`?: string;

  @doc("Database operation name (query, insert, delete, etc.)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.OperationName)
  operationName?: DbOperationName;

  @doc("Batch size (number of statements in batch)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.OperationBatchSize)
  batchSize?: int32;

  // ---------------------------------------------------------------------------
  // Query Details
  // ---------------------------------------------------------------------------

  @doc("Database statement (query text, may be sanitized)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.QueryText)
  queryText?: string;

  @doc("Parameterized query template")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.QuerySummary)
  querySummary?: string;

  @doc("Query parameters (for prepared statements). Keys map to db.query.parameter.<key>")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.QueryParameter)
  queryParameters?: Record<string>;

  // ---------------------------------------------------------------------------
  // Collection/Table Information
  // ---------------------------------------------------------------------------

  @doc("Table name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.CollectionName)
  collectionName?: string;

  // ---------------------------------------------------------------------------
  // Response Metrics
  // ---------------------------------------------------------------------------

  @doc("Number of rows affected/returned")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.ResponseReturnedRows)
  returnedRows?: int64;

  @doc("Status code from database")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.ResponseStatusCode)
  responseStatusCode?: string;

  // ---------------------------------------------------------------------------
  // Server Information
  // ---------------------------------------------------------------------------

  @doc("Database server address")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Server.Address)
  serverAddress?: string;

  @doc("Database server port")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Server.Port)
  serverPort?: Port;

  // ---------------------------------------------------------------------------
  // Connection Pool
  // ---------------------------------------------------------------------------

  @doc("Connection pool name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.ClientConnectionPoolName)
  connectionPoolName?: string;

  @doc("Connection state")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.ClientConnectionState)
  connectionState?: DbConnectionState;

  // ---------------------------------------------------------------------------
  // Deprecated Attributes (for migration)
  // ---------------------------------------------------------------------------

  @doc("Database name (deprecated - use db.namespace)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.Name)
  @removed(DbVersions.v1_24)
  dbName?: string;

  @doc("Database statement (deprecated - use db.query.text)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.Statement)
  @removed(DbVersions.v1_24)
  statement?: string;

  @doc("Database operation (deprecated - use db.operation.name)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.Operation)
  @removed(DbVersions.v1_24)
  operation?: string;

  @doc("Database user (deprecated)")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.User)
  @removed(DbVersions.v1_24)
  user?: string;
}

// =============================================================================
// Database System Enumeration (45+ DBMS Types)
// =============================================================================

@doc("Database management system identifiers")
enum DbSystem {
  // ---------------------------------------------------------------------------
  // Relational Databases
  // ---------------------------------------------------------------------------

  @doc("PostgreSQL")
  postgresql: "postgresql",

  @doc("MySQL / MariaDB")
  mysql: "mysql",

  @doc("MariaDB")
  mariadb: "mariadb",

  @doc("Microsoft SQL Server")
  mssql: "mssql",

  @doc("Oracle Database")
  oracle: "oracle",

  @doc("IBM DB2")
  db2: "db2",

  @doc("SQLite")
  sqlite: "sqlite",

  @doc("SAP HANA")
  hana: "hana",

  @doc("SAP MaxDB")
  maxdb: "maxdb",

  @doc("SAP SQL Anywhere")
  sqlanywhere: "sqlanywhere",

  @doc("Teradata")
  teradata: "teradata",

  @doc("Sybase")
  sybase: "sybase",

  @doc("Informix")
  informix: "informix",

  @doc("Firebird")
  firebird: "firebird",

  @doc("Interbase")
  interbase: "interbase",

  @doc("H2 Database")
  h2: "h2",

  @doc("HSQLDB")
  hsqldb: "hsqldb",

  @doc("Apache Derby")
  derby: "derby",

  @doc("CockroachDB")
  cockroachdb: "cockroachdb",

  @doc("TiDB")
  tidb: "tidb",

  @doc("YugabyteDB")
  yugabyte: "yugabyte",

  @doc("Vitess")
  vitess: "vitess",

  @doc("ClickHouse")
  clickhouse: "clickhouse",

  @doc("Snowflake")
  snowflake: "snowflake",

  @doc("Amazon Redshift")
  redshift: "redshift",

  @doc("Google BigQuery")
  bigquery: "bigquery",

  @doc("Azure Synapse")
  synapse: "synapse",

  @doc("Databricks")
  databricks: "databricks",

  @doc("Presto")
  presto: "presto",

  @doc("Trino")
  trino: "trino",

  @doc("Apache Hive")
  hive: "hive",

  @doc("Apache Spark SQL")
  sparksql: "sparksql",

  @doc("Apache Impala")
  impala: "impala",

  @doc("Apache Drill")
  drill: "drill",

  @doc("DuckDB")
  duckdb: "duckdb",

  @doc("Vertica")
  vertica: "vertica",

  @doc("Greenplum")
  greenplum: "greenplum",

  @doc("Netezza")
  netezza: "netezza",

  // ---------------------------------------------------------------------------
  // NoSQL Document Databases
  // ---------------------------------------------------------------------------

  @doc("MongoDB")
  mongodb: "mongodb",

  @doc("Couchbase")
  couchbase: "couchbase",

  @doc("CouchDB")
  couchdb: "couchdb",

  @doc("Amazon DocumentDB")
  documentdb: "documentdb",

  @doc("Azure Cosmos DB")
  cosmosdb: "cosmosdb",

  @doc("Google Cloud Firestore")
  firestore: "firestore",

  @doc("RavenDB")
  ravendb: "ravendb",

  @doc("ArangoDB")
  arangodb: "arangodb",

  // ---------------------------------------------------------------------------
  // Key-Value Stores
  // ---------------------------------------------------------------------------

  @doc("Redis")
  redis: "redis",

  @doc("Valkey")
  valkey: "valkey",

  @doc("KeyDB")
  keydb: "keydb",

  @doc("Memcached")
  memcached: "memcached",

  @doc("Amazon DynamoDB")
  dynamodb: "dynamodb",

  @doc("Azure Table Storage")
  azuretable: "azuretable",

  @doc("Hazelcast")
  hazelcast: "hazelcast",

  @doc("etcd")
  etcd: "etcd",

  @doc("Apache Ignite")
  ignite: "ignite",

  @doc("RocksDB")
  rocksdb: "rocksdb",

  @doc("LevelDB")
  leveldb: "leveldb",

  @doc("Berkeley DB")
  berkeleydb: "berkeleydb",

  // ---------------------------------------------------------------------------
  // Wide-Column Stores
  // ---------------------------------------------------------------------------

  @doc("Apache Cassandra")
  cassandra: "cassandra",

  @doc("ScyllaDB")
  scylla: "scylla",

  @doc("Apache HBase")
  hbase: "hbase",

  @doc("Google Cloud Bigtable")
  bigtable: "bigtable",

  // ---------------------------------------------------------------------------
  // Graph Databases
  // ---------------------------------------------------------------------------

  @doc("Neo4j")
  neo4j: "neo4j",

  @doc("Amazon Neptune")
  neptune: "neptune",

  @doc("ArangoDB (graph mode)")
  arangodbGraph: "arangodb_graph",

  @doc("JanusGraph")
  janusgraph: "janusgraph",

  @doc("TigerGraph")
  tigergraph: "tigergraph",

  @doc("Dgraph")
  dgraph: "dgraph",

  // ---------------------------------------------------------------------------
  // Time-Series Databases
  // ---------------------------------------------------------------------------

  @doc("InfluxDB")
  influxdb: "influxdb",

  @doc("TimescaleDB")
  timescaledb: "timescaledb",

  @doc("Prometheus")
  prometheus: "prometheus",

  @doc("QuestDB")
  questdb: "questdb",

  @doc("Amazon Timestream")
  timestream: "timestream",

  @doc("Apache Druid")
  druid: "druid",

  @doc("VictoriaMetrics")
  victoriametrics: "victoriametrics",

  // ---------------------------------------------------------------------------
  // Search Engines
  // ---------------------------------------------------------------------------

  @doc("Elasticsearch")
  elasticsearch: "elasticsearch",

  @doc("OpenSearch")
  opensearch: "opensearch",

  @doc("Apache Solr")
  solr: "solr",

  @doc("Splunk")
  splunk: "splunk",

  @doc("Meilisearch")
  meilisearch: "meilisearch",

  @doc("Typesense")
  typesense: "typesense",

  @doc("Algolia")
  algolia: "algolia",

  // ---------------------------------------------------------------------------
  // Vector Databases
  // ---------------------------------------------------------------------------

  @doc("Pinecone")
  pinecone: "pinecone",

  @doc("Milvus")
  milvus: "milvus",

  @doc("Weaviate")
  weaviate: "weaviate",

  @doc("Qdrant")
  qdrant: "qdrant",

  @doc("Chroma")
  chroma: "chroma",

  @doc("pgvector (PostgreSQL extension)")
  pgvector: "pgvector",

  // ---------------------------------------------------------------------------
  // Embedded & File-Based
  // ---------------------------------------------------------------------------

  @doc("Microsoft Access")
  msaccess: "msaccess",

  @doc("FileMaker")
  filemaker: "filemaker",

  @doc("FoxPro")
  foxpro: "foxpro",

  @doc("dBase")
  dbase: "dbase",

  // ---------------------------------------------------------------------------
  // Other
  // ---------------------------------------------------------------------------

  @doc("ODBC (generic)")
  odbc: "odbc",

  @doc("JDBC (generic)")
  jdbc: "jdbc",

  @doc("Other/unknown database system")
  other: "other",
}

// =============================================================================
// Database Operation Names
// =============================================================================

@doc("Database operation names")
enum DbOperationName {
  @doc("SELECT query")
  select: "SELECT",

  @doc("INSERT query")
  insert: "INSERT",

  @doc("UPDATE query")
  update: "UPDATE",

  @doc("DELETE query")
  delete: "DELETE",

  @doc("CREATE operation")
  create: "CREATE",

  @doc("DROP operation")
  drop: "DROP",

  @doc("ALTER operation")
  alter: "ALTER",

  @doc("TRUNCATE operation")
  truncate: "TRUNCATE",

  @doc("EXECUTE stored procedure")
  execute: "EXECUTE",

  @doc("CALL stored procedure")
  call: "CALL",

  @doc("BEGIN transaction")
  begin: "BEGIN",

  @doc("COMMIT transaction")
  commit: "COMMIT",

  @doc("ROLLBACK transaction")
  rollback: "ROLLBACK",

  @doc("SAVEPOINT in transaction")
  savepoint: "SAVEPOINT",

  // NoSQL Operations
  @doc("Find/query operation")
  find: "find",

  @doc("Find one operation")
  findOne: "findOne",

  @doc("Insert one operation")
  insertOne: "insertOne",

  @doc("Insert many operation")
  insertMany: "insertMany",

  @doc("Update one operation")
  updateOne: "updateOne",

  @doc("Update many operation")
  updateMany: "updateMany",

  @doc("Delete one operation")
  deleteOne: "deleteOne",

  @doc("Delete many operation")
  deleteMany: "deleteMany",

  @doc("Aggregate operation")
  aggregate: "aggregate",

  @doc("Count operation")
  count: "count",

  @doc("Get operation")
  get: "GET",

  @doc("Set operation")
  set: "SET",

  @doc("Delete operation")
  del: "DEL",

  @doc("Ping operation")
  ping: "PING",
}

// =============================================================================
// Database Connection States
// =============================================================================

@doc("Database connection states")
enum DbConnectionState {
  @doc("Connection is idle in pool")
  idle: "idle",

  @doc("Connection is in use")
  used: "used",
}

// =============================================================================
// Database Metrics
// =============================================================================

@doc("Database client operation duration metric")
model DbClientOperationDurationMetric {
  @doc("Metric name")
  name: "db.client.operation.duration";

  @doc("Metric unit (seconds)")
  unit: "s";

  @doc("Database system")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.SystemName)
  systemName: DbSystem;

  @doc("Database namespace")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.Namespace)
  `namespace`?: string;

  @doc("Operation name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.OperationName)
  operationName: DbOperationName;

  @doc("Collection/table name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.CollectionName)
  collectionName?: string;

  @doc("Error type if failed")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Error.Type)
  errorType?: string;
}

@doc("Database connection pool size metric")
model DbConnectionPoolSizeMetric {
  @doc("Metric name")
  name: "db.client.connection.count";

  @doc("Metric unit")
  unit: "{connection}";

  @doc("Database system")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.SystemName)
  systemName: DbSystem;

  @doc("Pool name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.ClientConnectionPoolName)
  poolName: string;

  @doc("Connection state")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.ClientConnectionState)
  state: DbConnectionState;
}

@doc("Database connection create time metric")
model DbConnectionCreateTimeMetric {
  @doc("Metric name")
  name: "db.client.connection.create_time";

  @doc("Metric unit (seconds)")
  unit: "s";

  @doc("Database system")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.SystemName)
  systemName: DbSystem;

  @doc("Pool name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.ClientConnectionPoolName)
  poolName: string;
}

@doc("Database connection wait time metric")
model DbConnectionWaitTimeMetric {
  @doc("Metric name")
  name: "db.client.connection.wait_time";

  @doc("Metric unit (seconds)")
  unit: "s";

  @doc("Database system")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.SystemName)
  systemName: DbSystem;

  @doc("Pool name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.ClientConnectionPoolName)
  poolName: string;
}

@doc("Database connection use time metric")
model DbConnectionUseTimeMetric {
  @doc("Metric name")
  name: "db.client.connection.use_time";

  @doc("Metric unit (seconds)")
  unit: "s";

  @doc("Database system")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.SystemName)
  systemName: DbSystem;

  @doc("Pool name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.ClientConnectionPoolName)
  poolName: string;
}

@doc("Database connection pending requests metric")
model DbConnectionPendingRequestsMetric {
  @doc("Metric name")
  name: "db.client.connection.pending_requests";

  @doc("Metric unit")
  unit: "{request}";

  @doc("Database system")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.SystemName)
  systemName: DbSystem;

  @doc("Pool name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.ClientConnectionPoolName)
  poolName: string;
}

@doc("Database connection timeouts metric")
model DbConnectionTimeoutsMetric {
  @doc("Metric name")
  name: "db.client.connection.timeouts";

  @doc("Metric unit")
  unit: "{timeout}";

  @doc("Database system")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.SystemName)
  systemName: DbSystem;

  @doc("Pool name")
  @encodedName("application/json", ANcpLua.OpenTelemetry.SemanticConventions.Keys.Db.ClientConnectionPoolName)
  poolName: string;
}

// =============================================================================
// Database Statistics
// =============================================================================

@doc("Aggregated database statistics")
model DbStats {
  @doc("Total queries")
  @encodedName("application/json", "total_queries")
  totalQueries: Count;

  @doc("Total query duration in seconds")
  @encodedName("application/json", "total_duration_s")
  totalDurationS: float64;

  @doc("Average query duration in milliseconds")
  @encodedName("application/json", "avg_duration_ms")
  avgDurationMs: float64;

  @doc("Query error rate")
  @encodedName("application/json", "error_rate")
  errorRate: Ratio;

  @doc("Stats by database system")
  @encodedName("application/json", "by_system")
  bySystem?: DbSystemStats[];

  @doc("Stats by operation")
  @encodedName("application/json", "by_operation")
  byOperation?: DbOperationStats[];

  @doc("Slowest queries")
  @encodedName("application/json", "slowest_queries")
  slowestQueries?: DbSlowQuery[];
}

@doc("Statistics by database system")
model DbSystemStats {
  @doc("Database system")
  system: DbSystem;

  @doc("Query count")
  @encodedName("application/json", "query_count")
  queryCount: Count;

  @doc("Average duration in milliseconds")
  @encodedName("application/json", "avg_duration_ms")
  avgDurationMs: float64;

  @doc("Error rate")
  @encodedName("application/json", "error_rate")
  errorRate: Ratio;
}

@doc("Statistics by operation type")
model DbOperationStats {
  @doc("Operation name")
  operation: DbOperationName;

  @doc("Query count")
  @encodedName("application/json", "query_count")
  queryCount: Count;

  @doc("Average duration in milliseconds")
  @encodedName("application/json", "avg_duration_ms")
  avgDurationMs: float64;
}

@doc("Slow query record")
model DbSlowQuery {
  @doc("Query text (sanitized)")
  @encodedName("application/json", "query_text")
  queryText: string;

  @doc("Duration in milliseconds")
  @encodedName("application/json", "duration_ms")
  durationMs: DurationMs;

  @doc("Database system")
  system: DbSystem;

  @doc("Database namespace")
  `namespace`?: string;

  @doc("Operation name")
  operation: DbOperationName;

  @doc("Timestamp")
  timestamp: utcDateTime;
}
