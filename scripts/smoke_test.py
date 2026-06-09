"""
End-to-end smoke test after pipeline run. Exit 1 on failure.

Usage:
  python scripts/smoke_test.py           # CSV validation only
  python scripts/smoke_test.py --warehouse   # also check Postgres analytics views
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

load_dotenv()

POSTGRES_URL = os.getenv(
    "POSTGRES_URL",
    "postgresql://postgres:fluwarehouse123@localhost:5432/flu_warehouse",
)


def validate_csvs() -> None:
    from scripts.validate_curated import main as validate_main

    validate_main()


def validate_warehouse() -> None:
    from sqlalchemy import create_engine, text

    engine = create_engine(POSTGRES_URL)
    checks = {
        "analytics.flu_weekly": "SELECT COUNT(*) FROM analytics.flu_weekly",
        "analytics.hospital_daily": "SELECT COUNT(*) FROM analytics.hospital_daily",
    }
    with engine.connect() as conn:
        for name, sql in checks.items():
            try:
                n = conn.execute(text(sql)).scalar()
            except Exception as exc:
                raise RuntimeError(f"{name}: {exc}") from exc
            if not n:
                raise RuntimeError(f"{name}: zero rows")
            print(f"  {name}: {n:,} rows")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--warehouse",
        action="store_true",
        help="Also verify Postgres analytics views",
    )
    args = parser.parse_args()

    print("=== CSV validation ===")
    validate_csvs()

    if args.warehouse:
        print("\n=== Warehouse validation ===")
        validate_warehouse()
        print("WAREHOUSE SMOKE TEST PASSED")
    else:
        print("\nCSV SMOKE TEST PASSED (add --warehouse after load)")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as exc:
        print(f"SMOKE TEST FAILED: {exc}", file=sys.stderr)
        sys.exit(1)
