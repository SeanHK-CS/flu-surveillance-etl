"""
Bronze: fetch CDC FluView (ILI) data and save raw JSON + CSV.

API docs: https://cmu-delphi.github.io/delphi-epidata/api/fluview.html
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime

import pandas as pd
import requests
from dotenv import load_dotenv

from ingest.paths import raw_run_dir

load_dotenv()

API_URL = "https://api.delphi.cmu.edu/epidata/fluview/"
STATES = os.getenv("FLUVIEW_STATES", "ca,ny,tx,il,fl")
EPIWEEKS = os.getenv("FLUVIEW_EPIWEEKS", "202448-202518")


def fetch() -> pd.DataFrame:
    params = {"regions": STATES, "epiweeks": EPIWEEKS}
    print(f"Fetching CDC FluView: regions={STATES}, epiweeks={EPIWEEKS}")

    response = requests.get(API_URL, params=params, timeout=120)
    response.raise_for_status()
    payload = response.json()

    if payload.get("result") != 1:
        raise RuntimeError(payload.get("message", "CDC API returned no data"))

    rows = payload.get("epidata", [])
    if not rows:
        raise RuntimeError("CDC API returned zero rows")

    out_dir = raw_run_dir("cdc")
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    json_path = out_dir / f"fluview_{stamp}.json"
    csv_path = out_dir / f"fluview_{stamp}.csv"

    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, default=str)

    df = pd.DataFrame(rows)
    df.to_csv(csv_path, index=False)

    print(f"Saved {len(df)} rows")
    print(f"  {json_path}")
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
