# Analytics Platform Design Discussion

This document discusses general design choices. It is not a deployment inventory, operating runbook, or security assessment of an employer system.

## Ingestion boundaries

A connector can reduce custom integration work when its capabilities fit a source. A table-level extraction task can instead make scheduling and failures easier to reason about when a source needs special handling. In either approach, document which mechanism owns each dataset and how a failed load is recovered.

The [example DAG](../examples/airflow/example_source_table_ingestion_dag.py) illustrates a full refresh into an existing target table. It reads the selected rows into memory and is intentionally small. It does not implement incremental watermarks, streaming ingestion, schema migration, or a complete retry and recovery design. Those choices depend on the workload.

## Modeling boundaries

A raw landing layer, light staging transformations, and business-facing marts separate responsibilities. The dbt examples use generic customer and order records to demonstrate naming, typing, aggregation, and model references. Materialization and indexing should be selected through workload-specific testing.

## Data-quality checks

The dbt examples include key constraints, relationships, value checks, and a comparison of order counts across layers. They are starting points, not proof of comprehensive coverage. In particular, the reconciliation query compares matching customer keys; a stronger check would also detect missing keys on either side. Source freshness requires an ingestion timestamp supplied by the reader's load process or target-table defaults.

## Scheduling and operation

An orchestrator can coordinate ingestion and transformation while dbt manages dependencies between its models. Simple external scheduling is another option, with different observability and retry trade-offs. Choose deliberately and document ownership, failure handling, and alerting.

The Compose examples are configuration sketches. A deployable environment needs dependency validation, secret handling, access controls, tested backup and recovery procedures, and resource planning. Hosting topology and capacity should follow requirements; no employer configuration is specified here.

## Access and maintainability

Useful general principles include separate service identities, permissions scoped to responsibilities, separation of application metadata from analytical data, and reviewed configuration changes. A proxy example illustrates routing syntax, not a complete secure network design. Infrastructure-as-code and restore exercises help make an environment reproducible and recoverable.
