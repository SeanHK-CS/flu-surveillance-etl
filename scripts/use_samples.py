"""
Copy committed sample CSVs into data/curated/ for offline demo (no API calls).

Usage: python scripts/use_samples.py
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SAMPLES = ROOT / "data" / "samples"
CURATED = ROOT / "data" / "curated"

MAPPING = {
    "flu_weekly_sample.csv": "flu_weekly.csv",
    "hospital_daily_sample.csv": "hospital_daily.csv",
}


def main() -> None:
    CURATED.mkdir(parents=True, exist_ok=True)
    for src_name, dest_name in MAPPING.items():
        src = SAMPLES / src_name
        dest = CURATED / dest_name
        if not src.exists():
            print(f"Missing {src}", file=sys.stderr)
            sys.exit(1)
        shutil.copy2(src, dest)
        print(f"Copied {src.name} -> {dest}")
    print("\nRun: python scripts/validate_curated.py")
    print("Power BI: import data/curated/*.csv or data/samples/*.csv")


if __name__ == "__main__":
    main()
