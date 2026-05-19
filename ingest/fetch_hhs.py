"""
Bronze: fetch HHS hospital capacity/utilization CSV (limited rows).

Dataset: COVID-19 hospital capacity by state (reporting ended May 2024).
Use for pipeline practice; not current flu-specific admissions.
"""
from __future__ import annotations

import os
import sys
from datetime import datetime

import pandas as pd
import requests
from dotenv import load_dotenv

from ingest.paths import raw_run_dir

load_dotenv()

HHS_URL = "https://healthdata.gov/resource/g62h-syeh.csv"
ROW_LIMIT = int(os.getenv("HHS_ROW_LIMIT", "25000"))


def fetch() -> pd.DataFrame:
    params = {"$limit": str(ROW_LIMIT), "$order": "date DESC"}
    print(f"Fetching HHS hospital data (limit={ROW_LIMIT})")

    response = requests.get(
        HHS_URL,
        params=params,
        timeout=300,
        headers={"User-Agent": "flu-surveillance/2.0"},
    )
    response.raise_for_status()

    df = pd.read_csv(
        __import__("io").StringIO(response.text),
        low_memory=False,
    )
    if df.empty:
        raise RuntimeError("HHS download returned zero rows")

    out_dir = raw_run_dir("hhs")
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    csv_path = out_dir / f"hospital_{stamp}.csv"
    df.to_csv(csv_path, index=False)

    print(f"Saved {len(df)} rows, {len(df.columns)} columns")
    print(f"  {csv_path}")
    return df


def main() -> None:
    try:
        fetch()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
