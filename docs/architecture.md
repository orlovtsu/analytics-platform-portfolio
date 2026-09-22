# Architecture Notes

This document expands on the README with the reasoning behind each decision, written from the perspective of a single data engineer operating the platform for a small analytics team.

## Design constraints

- **One person, one host.** No dedicated platform team, so operational simplicity beats theoretical elegance. Kubernetes was deliberately not used — Docker Compose per service is enough, easy to reason about, and easy to hand off.
- **Legacy source systems.** The main operational data source is an on-prem-style MSSQL reporting database that predates the analytics platform. Off-the-shelf connectors don't cover every table well, so some ingestion had to be hand-written.
- **Fixed infra budget.** A single right-sized VM (8 vCPU / 32 GB RAM) runs the entire stack. Every service is either containerized or a native systemd/cron job, sized to coexist on one box.

## Why a hybrid ingestion layer

Two ingestion mechanisms run side by side, on purpose:

1. **Connector-based (Airbyte)** for sources where a maintained connector exists and "just works" — lower maintenance cost, standard monitoring, built-in schema drift handling.
2. **Custom Airflow TaskFlow DAGs**, generated one-per-source-table, for the legacy MSSQL system where:
   - incremental logic needed to be table-specific (different watermark columns, different volumes),
   - schedules needed to differ per table (some hourly, some daily),
   - visibility into failures needed to be per-table in the Airflow UI rather than buried inside a connector's sync log.

Both write into a `raw` schema in the warehouse, keeping a single landing zone regardless of which mechanism loaded the data. See [`examples/airflow/example_source_table_ingestion_dag.py`](../examples/airflow/example_source_table_ingestion_dag.py) for the DAG pattern — each file is deliberately small and declarative (source connection, source table, target table) so the ~200 of them stay easy to review and regenerate from a template.

**Trade-off acknowledged:** running two ingestion tools means two places to monitor and two failure modes to reason about. The mitigation is a clear ownership rule — table-by-table, documented which mechanism is authoritative — rather than trying to unify them prematurely.

## Why Airflow 3.x with CeleryExecutor

- `dag-processor` is split out from the scheduler (new in Airflow 3.x), so a DAG-parsing slowdown from ~200 files never blocks scheduling itself.
- CeleryExecutor over LocalExecutor because the host has room to run several workers in parallel and Celery's retry/visibility semantics are well understood.
- `DAGS_ARE_PAUSED_AT_CREATION: true` — new DAGs never start firing before someone has reviewed them in the UI. Small setting, prevents a whole class of "oops, it back-filled six months of history" incidents.

## Why dbt with a staging → marts layering

- `staging`: 1:1 with raw source tables, light typing/renaming only, materialized as tables (not views) — because downstream marts query them repeatedly and the source Postgres instance is shared with ingestion writes, so avoiding repeated re-computation from raw matters more than saving disk.
- `marts`: business-level, aggregated/joined models consumed directly by BI. Each mart owns its own schema-per-layer convention via a custom `generate_schema_name` macro, so warehouse permissions can be granted per layer (BI tools get read-only on `marts`, never on `raw`).
- Scheduled via cron (hourly + daily wrapper scripts) rather than Airflow, on the theory that dbt's own DAG resolution already handles inter-model dependencies — a dedicated Airflow DAG would just be reimplementing what `dbt run` does internally. (A reasonable alternative is wrapping `dbt run` in a single Airflow task for unified alerting; noted as a possible next step.)

## Where data-quality tests live, and why

Tests are placed at the layer where a defect would first become detectable, not all bolted onto the mart at the end:

- **Sources** (`sources.yml`): `unique`/`not_null` on natural keys, plus a `freshness` check against the ingestion schedule. This catches "the daily load silently stopped running" before anyone notices the dashboard just looks unusually stable.
- **Staging** (`models/staging/schema.yml`): the same key tests re-asserted after typing/renaming, plus a `relationships` test across the two staging models. A source-system change (e.g. a deleted customer) that would otherwise surface as a mysteriously shrinking mart is caught one layer earlier, closer to its actual cause.
- **Marts** (`models/marts/schema.yml`): tests that only make sense once data is business-shaped — grain (`unique` on the mart's primary entity), value ranges, and a cross-column invariant (`first_order_at <= most_recent_order_at`) expressed with `dbt_utils.expression_is_true` rather than a bespoke SQL file, since it doesn't need one.
- **Singular tests** (`tests/`): reserved for checks a generic test can't express — here, a row-count reconciliation between `stg_orders` and the mart, to catch a join silently fanning out or dropping rows during aggregation.

The general rule: a generic (schema-level) test until the assertion needs more than one model or a real cross-column expression, and a singular SQL test only past that point — keeps `schema.yml` files scannable instead of every test escalating to hand-written SQL by default.

## Why a single Postgres instance, not a dedicated warehouse product

At the current data volume, a well-indexed Postgres instance comfortably serves both the transformation workload and BI query patterns. The separation that matters more than "which product" is **schema-level isolation with role-based access**:

- `raw*` — write access limited to the ingestion tools only.
- `staging` / `marts` — written only by the dbt service account, read by BI.
- BI and analyst access is granted per-schema, and analyst logins are backed by the company's existing Active Directory via LDAP bind — no separate password to manage for that population.
- The orchestrator's own metadata database (Airflow) is a **completely separate Postgres instance**, so an Airflow migration or metadata bug can never touch analytics data.

## Why nginx + Cloudflare Tunnel at the edge

Every internal web UI (BI tool, orchestrator UI, ingestion tool UI) sits behind a single nginx reverse proxy doing TLS termination and subdomain-based routing to a local port. This keeps certificate management and access logging in one place instead of duplicated per service. A tunnel client (Cloudflare Tunnel) is used to expose services without opening inbound firewall ports directly on the VM, which also gets you DDoS protection and access policies at the edge for free.

## What I'd change next

- Move ingestion mechanism selection (Airbyte vs. custom DAG) into a documented, table-level ownership map instead of tribal knowledge.
- Wrap the dbt cron jobs in a thin Airflow DAG for unified alerting/observability alongside ingestion, without duplicating dbt's own dependency graph.
- Move all secrets (LDAP bind credentials, connection strings) out of service config files and into a managed secrets store.
- Add infrastructure-as-code (Terraform/Ansible) for the host configuration itself, since right now it's a single hand-maintained VM and a single point of failure for the whole analytics function.
