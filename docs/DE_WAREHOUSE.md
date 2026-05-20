# Data engineering warehouse branch (`feature/de-warehouse`)

Extends V2 with **PostgreSQL star schema** + **Airflow** (no Google Trends).

## Architecture

```
CDC / HHS APIs
    -> data/raw/
    -> data/curated/*.csv     (bronze/silver — same as main)
    -> PostgreSQL:
         staging.stg_*
         dimensions.dim_*
         facts.fact_*
         analytics.* views     (gold for Power BI DirectQuery)
```

## Setup

```powershell
git checkout feature/de-warehouse
pip install -r requirements.txt
.\docker\start_postgres.ps1   # sets POSTGRES_URL; requires Docker Desktop
.\run_pipeline_warehouse.ps1
python scripts/smoke_test.py --warehouse
```

Mac/Linux:

```bash
chmod +x docker/start_postgres.sh run_pipeline_warehouse.sh
./docker/start_postgres.sh
export POSTGRES_URL="postgresql://postgres:fluwarehouse123@localhost:5432/flu_warehouse"
./run_pipeline_warehouse.sh
```

## Star schema

| Layer | Objects |
|-------|---------|
| **Staging** | `staging.stg_flu_weekly`, `staging.stg_hospital_daily` |
| **Dimensions** | `dim_date`, `dim_location`, `dim_source` |
| **Facts** | `fact_flu_weekly`, `fact_hospital_daily` |
| **Analytics** | `analytics.flu_weekly`, `analytics.hospital_daily` (views) |

## Power BI

Connect with **Get data → PostgreSQL**, load:

- `analytics.flu_weekly`
- `analytics.hospital_daily`

Do not merge on one page without respecting week vs day grain.

## Airflow

1. Install: `pip install apache-airflow`
2. `set AIRFLOW_HOME=C:\path\to\airflow_home`
3. `airflow db init` (first time only)
4. Copy or symlink `dags/flu_etl_dag.py` into `%AIRFLOW_HOME%\dags`
5. `airflow dags test flu_surveillance_daily 2026-01-01`

## Branches

| Branch | Purpose |
|--------|---------|
| `main` | Simple CSV pipeline + Power BI samples |
| `archive/v1-ai-slop` | Original AI project (reference only) |
| `feature/de-warehouse` | This document |
