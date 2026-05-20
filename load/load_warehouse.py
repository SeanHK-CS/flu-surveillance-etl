"""
Load curated CSVs into PostgreSQL star schema (staging -> dimensions/facts -> analytics views).

Requires: POSTGRES_URL, curated CSVs from transform.build_curated
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

from ingest.paths import CURATED_DIR, PROJECT_ROOT

load_dotenv()

POSTGRES_URL = os.getenv(
    "POSTGRES_URL",
    "postgresql://postgres:fluwarehouse123@localhost:5432/flu_warehouse",
)

SQL_DIR = PROJECT_ROOT / "sql" / "warehouse"


def run_sql_files(engine, files: list[str]) -> None:
    for name in files:
        path = SQL_DIR / name
        sql = path.read_text(encoding="utf-8")
        print(f"Running {name}...")
        with engine.begin() as conn:
            conn.execute(text(sql))


def load_staging(engine) -> None:
    flu_path = CURATED_DIR / "flu_weekly.csv"
    hosp_path = CURATED_DIR / "hospital_daily.csv"
    if not flu_path.exists() or not hosp_path.exists():
        raise FileNotFoundError("Run pipeline first: missing data/curated/*.csv")

    flu = pd.read_csv(flu_path)
    hosp = pd.read_csv(hosp_path)
    flu["week_ending"] = pd.to_datetime(flu["week_ending"]).dt.date
    hosp["report_date"] = pd.to_datetime(hosp["report_date"]).dt.date

    with engine.begin() as conn:
        conn.execute(text("TRUNCATE staging.stg_flu_weekly"))
        conn.execute(text("TRUNCATE staging.stg_hospital_daily"))
        flu.to_sql("stg_flu_weekly", conn, schema="staging", if_exists="append", index=False)
        hosp.to_sql("stg_hospital_daily", conn, schema="staging", if_exists="append", index=False)

    print(f"Loaded staging: {len(flu)} flu rows, {len(hosp)} hospital rows")


def print_counts(engine) -> None:
    queries = {
        "dim_location": "SELECT COUNT(*) FROM dimensions.dim_location",
        "dim_date": "SELECT COUNT(*) FROM dimensions.dim_date",
        "fact_flu_weekly": "SELECT COUNT(*) FROM facts.fact_flu_weekly",
        "fact_hospital_daily": "SELECT COUNT(*) FROM facts.fact_hospital_daily",
    }
    with engine.connect() as conn:
        for label, q in queries.items():
            n = conn.execute(text(q)).scalar()
            print(f"  {label}: {n}")


def main() -> None:
    try:
        engine = create_engine(POSTGRES_URL)
        run_sql_files(
            engine,
            [
                "01_schemas.sql",
                "02_dimensions.sql",
                "03_staging.sql",
                "04_facts.sql",
            ],
        )
        load_staging(engine)
        run_sql_files(engine, ["05_transform.sql", "06_analytics_views.sql"])
        print("\nWarehouse load complete. Row counts:")
        print_counts(engine)
        print("\nPower BI: connect to analytics.flu_weekly and analytics.hospital_daily")
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
