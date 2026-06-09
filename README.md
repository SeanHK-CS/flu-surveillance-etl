# Flu Surveillance ETL

An end-to-end analytics pipeline that ingests U.S. influenza and hospital-utilization
data from two public health sources, loads it into a PostgreSQL star-schema warehouse,
and exposes it for analysis in Power BI. Orchestrated by an Airflow DAG.

## What it does

```
CDC FluView API ─┐
                 ├─► raw ─► curated CSVs ─► PostgreSQL star schema ─► Power BI / analytics views
HHS Hospital  ───┘
```

- **Two sources:** CDC FluView (weekly outpatient ILI surveillance) and HHS hospital
  utilization reports, both pulled from live APIs.
- **PostgreSQL star schema:** three dimension tables (`dim_source`, `dim_location`,
  `dim_date`) and two fact tables (`fact_flu_weekly`, `fact_hospital_daily`), connected
  by foreign keys, with analytics views on top.
- **Airflow DAG:** `flu_surveillance_daily` orchestrates the pipeline with a daily
  schedule and automatic retries (2 retries, 10-minute delay).
- **Idempotent loads:** dimensions upsert via `ON CONFLICT`; facts reload via
  truncate-and-insert, so reruns are safe.
- **Validation step:** checks for null keys, duplicate keys, date parsing, and
  non-empty output, plus warehouse row-count smoke tests.

## Warehouse contents (typical run)

| Table | Rows | Notes |
|---|---|---|
| `dim_source` | 2 | cdc_fluview, hhs_hospital |
| `dim_location` | 54 | US states and territories |
| `dim_date` | 486 | unique dates across both sources |
| `fact_flu_weekly` | 115 | 5 states by 23 weeks |
| `fact_hospital_daily` | 25,000 | daily hospital utilization |

## Prerequisites

- Python 3.10+
- PostgreSQL (local or Docker; the warehouse load expects a reachable instance on 5432)
- Apache Airflow (optional; install via the official constraints file to run the DAG)
- Power BI Desktop (optional, for dashboards)

## Setup

```
git clone <repo-url>
cd flu-surveillance-etl
python -m venv .venv
source .venv/bin/activate        # Windows: .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
cp .env.example .env             # set DB connection + source params
```

## Run

CSV pipeline only (no database required):

```
python -m ingest.fetch_cdc
python -m ingest.fetch_hhs
python -m transform.build_curated
python scripts/validate_curated.py
```

Full pipeline through the warehouse (requires Postgres):

```
./run_pipeline_warehouse.sh      # or .\run_pipeline_warehouse.ps1
python scripts/smoke_test.py --warehouse
```

## Notes and caveats

- **Ingest is full-fetch each run**, not incremental. Warehouse dimensions are
  incremental via `ON CONFLICT`; facts are reloaded.
- HHS hospital reporting ended May 2024, so flu and hospital files may cover different
  date ranges. Use separate report pages in Power BI.
- The Airflow DAG parses and registers; it is configured for daily scheduling but is
  not deployed to a running scheduler in this repo.

## License

MIT
