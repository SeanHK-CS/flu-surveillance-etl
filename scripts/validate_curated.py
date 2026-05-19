"""
Validate curated CSVs after pipeline run. Exit code 1 if checks fail.
Usage: python scripts/validate_curated.py
"""
from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
CURATED = ROOT / "data" / "curated"
SAMPLES = ROOT / "data" / "samples"

FLU_COLS = [
    "epiweek",
    "week_ending",
    "state",
    "ili_pct",
    "wili_pct",
    "ili_cases",
    "patient_visits",
]
HOSP_COLS = [
    "report_date",
    "state",
    "inpatient_beds",
    "inpatient_beds_used",
    "bed_utilization_pct",
    "icu_covid_patients",
    "covid_admissions",
    "covid_admissions_suspected",
]


def check_file(path: Path, required_cols: list[str], date_col: str, key_cols: list[str]) -> list[str]:
    errors: list[str] = []
    if not path.exists():
        return [f"Missing file: {path}"]

    df = pd.read_csv(path)
    if len(df) == 0:
        errors.append(f"{path.name}: zero rows")

    missing = [c for c in required_cols if c not in df.columns]
    if missing:
        errors.append(f"{path.name}: missing columns {missing}")

    if date_col in df.columns:
        parsed = pd.to_datetime(df[date_col], errors="coerce")
        if parsed.isna().any():
            errors.append(f"{path.name}: invalid dates in {date_col}")
        if parsed.isna().all():
            errors.append(f"{path.name}: all dates invalid")

    if all(c in df.columns for c in key_cols):
        dups = df.duplicated(subset=key_cols, keep=False).sum()
        if dups:
            errors.append(f"{path.name}: {dups} duplicate rows on {key_cols}")

    if "state" in df.columns and df["state"].isna().any():
        errors.append(f"{path.name}: null state values")

    return errors


def main() -> None:
    all_errors: list[str] = []

    all_errors.extend(
        check_file(CURATED / "flu_weekly.csv", FLU_COLS, "week_ending", ["epiweek", "state"])
    )
    all_errors.extend(
        check_file(
            CURATED / "hospital_daily.csv",
            HOSP_COLS,
            "report_date",
            ["report_date", "state"],
        )
    )

    for sample in ["flu_weekly_sample.csv", "hospital_daily_sample.csv"]:
        p = SAMPLES / sample
        if not p.exists():
            all_errors.append(f"Missing sample: {p}")

    if all_errors:
        print("VALIDATION FAILED:")
        for e in all_errors:
            print(f"  - {e}")
        sys.exit(1)

    flu = pd.read_csv(CURATED / "flu_weekly.csv")
    hosp = pd.read_csv(CURATED / "hospital_daily.csv")
    print("VALIDATION PASSED")
    print(f"  flu_weekly.csv:        {len(flu):,} rows, {flu['state'].nunique()} states")
    print(f"  hospital_daily.csv:    {len(hosp):,} rows, {hosp['state'].nunique()} states")
    print(f"  flu date range:        {flu['week_ending'].min()} -> {flu['week_ending'].max()}")
    print(f"  hospital date range:   {hosp['report_date'].min()} -> {hosp['report_date'].max()}")
    print("\nPower BI: Get Data -> Text/CSV -> select files in data/curated/")


if __name__ == "__main__":
    main()
