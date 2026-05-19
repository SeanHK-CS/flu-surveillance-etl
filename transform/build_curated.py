"""
Silver/Gold: read latest raw files and write analyst-ready CSVs for Power BI.

Outputs:
  data/curated/flu_weekly.csv
  data/curated/hospital_daily.csv
  data/samples/  (small copies for quick demo without re-running ingest)
"""
from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd

from ingest.paths import CURATED_DIR, PROJECT_ROOT, RAW_DIR

SAMPLES_DIR = PROJECT_ROOT / "data" / "samples"
CURATED_DIR.mkdir(parents=True, exist_ok=True)
SAMPLES_DIR.mkdir(parents=True, exist_ok=True)


def latest_csv(source: str) -> Path:
    folder = RAW_DIR / source
    if not folder.exists():
        raise FileNotFoundError(
            f"No raw data for '{source}'. Run: python -m ingest.fetch_{source}"
        )

    files = sorted(folder.rglob("*.csv"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not files:
        raise FileNotFoundError(f"No CSV files under {folder}")
    return files[0]


def epiweek_to_date(epiweek: int) -> pd.Timestamp:
    """Convert CDC epiweek (YYYYWW) to week-ending Saturday."""
    s = str(int(epiweek))
    year, week = int(s[:4]), int(s[4:])
    return pd.to_datetime(f"{year}-W{week:02d}-6", format="%G-W%V-%u")


def _write_csv(df: pd.DataFrame, dest: Path, sample_name: str) -> None:
    df.to_csv(dest, index=False, date_format="%Y-%m-%d")
    sample_path = SAMPLES_DIR / sample_name
    df.head(min(100, len(df))).to_csv(sample_path, index=False, date_format="%Y-%m-%d")
    print(f"Wrote {len(df)} rows -> {dest}")
    print(f"  sample ({min(100, len(df))} rows) -> {sample_path}")


def build_flu_weekly() -> pd.DataFrame:
    path = latest_csv("cdc")
    print(f"Cleaning CDC: {path}")
    df = pd.read_csv(path)

    df["epiweek"] = pd.to_numeric(df["epiweek"], errors="coerce").astype("Int64")
    df["week_ending"] = df["epiweek"].apply(
        lambda x: epiweek_to_date(x) if pd.notna(x) else pd.NaT
    )
    df["state"] = df["region"].astype(str).str.upper().str.strip()
    df["ili_pct"] = pd.to_numeric(df.get("ili"), errors="coerce").round(3)
    df["wili_pct"] = pd.to_numeric(df.get("wili"), errors="coerce").round(3)
    df["ili_cases"] = pd.to_numeric(df.get("num_ili"), errors="coerce")
    df["patient_visits"] = pd.to_numeric(df.get("num_patients"), errors="coerce")

    out = df[
        [
            "epiweek",
            "week_ending",
            "state",
            "ili_pct",
            "wili_pct",
            "ili_cases",
            "patient_visits",
        ]
    ].dropna(subset=["epiweek", "state", "week_ending"])
    out = out.drop_duplicates(subset=["epiweek", "state"], keep="last")
    out = out.sort_values(["state", "week_ending"])
    out["week_ending"] = pd.to_datetime(out["week_ending"]).dt.strftime("%Y-%m-%d")

    _write_csv(out, CURATED_DIR / "flu_weekly.csv", "flu_weekly_sample.csv")
    return out


def build_hospital_daily() -> pd.DataFrame:
    path = latest_csv("hhs")
    print(f"Cleaning HHS: {path}")
    df = pd.read_csv(path, low_memory=False)

    df["report_date"] = pd.to_datetime(df["date"], errors="coerce")
    df["state"] = df["state"].astype(str).str.upper().str.strip()

    for col in [
        "inpatient_beds",
        "inpatient_beds_used",
        "staffed_icu_adult_patients_confirmed_and_suspected_covid",
        "previous_day_admission_adult_covid_confirmed",
        "previous_day_admission_adult_covid_suspected",
    ]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    if "inpatient_beds" in df.columns and "inpatient_beds_used" in df.columns:
        df["bed_utilization_pct"] = (
            100.0 * df["inpatient_beds_used"] / df["inpatient_beds"].replace(0, pd.NA)
        ).round(2)

    out = pd.DataFrame(
        {
            "report_date": df["report_date"],
            "state": df["state"],
            "inpatient_beds": df.get("inpatient_beds"),
            "inpatient_beds_used": df.get("inpatient_beds_used"),
            "bed_utilization_pct": df.get("bed_utilization_pct"),
            "icu_covid_patients": df.get(
                "staffed_icu_adult_patients_confirmed_and_suspected_covid"
            ),
            "covid_admissions": df.get("previous_day_admission_adult_covid_confirmed"),
            "covid_admissions_suspected": df.get(
                "previous_day_admission_adult_covid_suspected"
            ),
        }
    )
    out = out.dropna(subset=["report_date", "state"])
    out = out.drop_duplicates(subset=["report_date", "state"], keep="last")
    out = out.sort_values(["state", "report_date"])
    out["report_date"] = pd.to_datetime(out["report_date"]).dt.strftime("%Y-%m-%d")

    _write_csv(out, CURATED_DIR / "hospital_daily.csv", "hospital_daily_sample.csv")
    return out


def main() -> None:
    try:
        flu = build_flu_weekly()
        hosp = build_hospital_daily()
        print("\nCurated files ready for Power BI:")
        print(f"  {CURATED_DIR / 'flu_weekly.csv'}")
        print(f"  {CURATED_DIR / 'hospital_daily.csv'}")
        print(f"\nFlu: {len(flu)} rows, {flu['state'].nunique()} states, "
              f"{flu['week_ending'].min()} to {flu['week_ending'].max()}")
        print(f"Hospital: {len(hosp)} rows, {hosp['state'].nunique()} states, "
              f"{hosp['report_date'].min()} to {hosp['report_date'].max()}")
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
