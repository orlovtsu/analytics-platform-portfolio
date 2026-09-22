# Analytics Engineering - Patterns and Examples

Generic examples and design discussions covering ingestion, orchestration, transformation, storage, and BI. These materials are informed by my professional experience and illustrate general engineering concepts; they do not document any employer's current deployment or operational results.

## What you can inspect

- [Design discussion](docs/architecture.md): ingestion choices, modeling layers, data quality, and operational considerations.
- [Airflow example](examples/airflow/example_source_table_ingestion_dag.py): a small, full-refresh extract/load pattern with generic source and target names.
- [dbt examples](examples/dbt/): staging and mart models, schema tests, and a reconciliation query.
- [Container examples](examples/docker-compose/): illustrative service configuration, requiring adaptation before use.
- [Reverse-proxy example](examples/nginx/reverse-proxy.conf): a placeholder configuration for a local test environment.
- [BI engineering discussion](docs/case-study-metabase-pivot-patch.md): reasoning about result limits, resource use, and validation.

## Scope

This is an illustrative collection, not a complete runnable platform. The examples require connections, test data, dependency configuration, and operational controls supplied by the reader. They are not production recommendations or evidence of production scale, model performance, infrastructure capacity, business volumes, or financial outcomes.

Example names such as `orders`, `customers`, and `source_system` are generic. The examples do not include customer records, employer connection details, or employer-specific schemas. Descriptions of design alternatives should not be interpreted as descriptions of an employer's infrastructure or security controls.

## License

Code samples are provided under the [MIT License](LICENSE). Refer to each third-party project's own license for its software.
