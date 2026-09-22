"""
Example of the per-source-table ingestion DAG pattern used in production.

This is a GENERIC, rebuilt-from-scratch illustration, not a copy of any real
DAG. Real production DAGs follow this exact shape (~200 of them, one per
source table), with real connection IDs, schema and table names swapped out.

Pattern: each DAG is a thin, declarative wrapper around "pull one table from
a legacy source database, land it as-is in the warehouse's raw schema".
Credentials are never hardcoded — they come from Airflow Connections, which
are backed by Airflow's configured secrets backend.
"""
from __future__ import annotations

from datetime import datetime

import psycopg2
import pymssql

from airflow.sdk import dag, task
from airflow.sdk.bases.hook import BaseHook

# --- Per-DAG configuration (this block is what actually differs between
#     the ~200 generated DAG files) -----------------------------------------
SOURCE_CONN_ID = "source_mssql_reporting_db"
TARGET_CONN_ID = "warehouse_postgres"

SOURCE_SCHEMA = "dbo"
SOURCE_TABLE = "orders"

TARGET_SCHEMA = "raw"
TARGET_TABLE = "source_orders"
# -----------------------------------------------------------------------------


def get_source_connection():
    conn = BaseHook.get_connection(SOURCE_CONN_ID)
    return pymssql.connect(
        server=conn.host,
        user=conn.login,
        password=conn.password,
        database=conn.schema,
        port=conn.port or 1433,
        login_timeout=20,
        timeout=60,
        as_dict=False,
    )


def get_target_connection():
    conn = BaseHook.get_connection(TARGET_CONN_ID)
    return psycopg2.connect(
        host=conn.host,
        user=conn.login,
        password=conn.password,
        dbname=conn.schema,
        port=conn.port or 5432,
    )


@dag(
    dag_id="example_diagnose_orders",
    schedule="@daily",
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=["ingestion", "example"],
)
def example_source_table_ingestion_dag():
    @task
    def extract_and_load() -> int:
        with get_source_connection() as src, get_target_connection() as tgt:
            with src.cursor() as src_cur:
                src_cur.execute(f"SELECT * FROM {SOURCE_SCHEMA}.{SOURCE_TABLE}")
                columns = [desc[0] for desc in src_cur.description]
                rows = src_cur.fetchall()

            with tgt.cursor() as tgt_cur:
                tgt_cur.execute(
                    f"TRUNCATE TABLE {TARGET_SCHEMA}.{TARGET_TABLE}"
                )
                placeholders = ", ".join(["%s"] * len(columns))
                tgt_cur.executemany(
                    f"INSERT INTO {TARGET_SCHEMA}.{TARGET_TABLE} "
                    f"({', '.join(columns)}) VALUES ({placeholders})",
                    rows,
                )
            tgt.commit()
            return len(rows)

    extract_and_load()


example_source_table_ingestion_dag()
