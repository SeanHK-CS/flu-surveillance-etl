"""
Daily Airflow DAG — flu surveillance pipeline (feature/de-warehouse).

Schedule: daily at 06:00 UTC
Tasks: ingest CDC -> ingest HHS -> build curated CSVs -> load warehouse -> validate

Set AIRFLOW_HOME and copy this file to your Airflow dags folder, or run from repo:
  airflow dags test flu_surveillance_daily 2026-01-01
"""
from __future__ import annotations

import os
from datetime import datetime, timedelta
from pathlib import Path

from airflow import DAG
from airflow.operators.bash import BashOperator

REPO = Path(__file__).resolve().parents[1]
PYTHON = os.getenv("FLU_PIPELINE_PYTHON", "python")

default_args = {
    "owner": "flu-surveillance",
    "depends_on_past": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=10),
}

with DAG(
    dag_id="flu_surveillance_daily",
    default_args=default_args,
    description="CDC + HHS ingest, curated CSVs, Postgres warehouse",
    schedule_interval="0 6 * * *",
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=["flu", "cdc", "hhs", "warehouse"],
) as dag:
    fetch_cdc = BashOperator(
        task_id="fetch_cdc",
        bash_command=f"cd {REPO} && {PYTHON} -m ingest.fetch_cdc",
    )
    fetch_hhs = BashOperator(
        task_id="fetch_hhs",
        bash_command=f"cd {REPO} && {PYTHON} -m ingest.fetch_hhs",
    )
    build_curated = BashOperator(
        task_id="build_curated",
        bash_command=f"cd {REPO} && {PYTHON} -m transform.build_curated",
    )
    load_warehouse = BashOperator(
        task_id="load_warehouse",
        bash_command=f"cd {REPO} && {PYTHON} -m load.load_warehouse",
    )
    validate = BashOperator(
        task_id="validate_curated",
        bash_command=f"cd {REPO} && {PYTHON} scripts/validate_curated.py",
    )

    fetch_cdc >> fetch_hhs >> build_curated >> load_warehouse >> validate
