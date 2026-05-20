# Flu Surveillance ETL

Python pipeline: **fetch public health data → store raw → clean → CSV files for Power BI**.

| Branch | What you get |
|--------|----------------|
| **`main`** | CSV pipeline + committed samples (fastest fork) |
| **`feature/de-warehouse`** | Above + PostgreSQL star schema + Airflow DAG |
| **`archive/v1-ai-slop`** | Original AI-generated project (reference only) |

Repo: https://github.com/SeanHK-CS/flu-surveillance-etl

## Quick start (fork this repo)

### Path A — No API calls (≈1 minute)

Power BI or CSV-only analysts:

```powershell
git clone https://github.com/SeanHK-CS/flu-surveillance-etl.git
cd flu-surveillance-etl
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python scripts/use_samples.py
python scripts/validate_curated.py
```

Import `data/curated/*.csv` in Power BI (or use `data/samples/` directly).

### Path B — Full live pipeline (≈1–2 minutes)

Requires internet (CDC + HHS APIs):

```powershell
git clone https://github.com/SeanHK-CS/flu-surveillance-etl.git
cd flu-surveillance-etl
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
.\run_pipeline.ps1
python scripts/smoke_test.py
```

Mac/Linux: `./run_pipeline.sh` then `python scripts/smoke_test.py`

### Path C — Warehouse branch (Postgres + star schema)

```powershell
git clone https://github.com/SeanHK-CS/flu-surveillance-etl.git
cd flu-surveillance-etl
git checkout feature/de-warehouse
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

**Requires [Docker Desktop](https://www.docker.com/products/docker-desktop/)** running:

```powershell
.\docker\start_postgres.ps1
.\run_pipeline_warehouse.ps1
```

Details: [`docs/DE_WAREHOUSE.md`](docs/DE_WAREHOUSE.md)

## Flow

```
CDC API  ──► data/raw/cdc/     ──┐
                                 ├──► data/curated/*.csv ──► Power BI
HHS CSV  ──► data/raw/hhs/     ──┘
```

Warehouse branch adds: curated CSVs → PostgreSQL `analytics.*` views.

## Prerequisites

- Python 3.10+
- Internet (for Path B/C live ingest)
- Docker Desktop (Path C only)
- [Power BI Desktop](https://powerbi.microsoft.com/desktop/) (optional)

## Outputs

| File | Typical size | Use |
|------|----------------|-----|
| `data/curated/flu_weekly.csv` | ~115 rows | Weekly ILI % by state |
| `data/curated/hospital_daily.csv` | ~25,000 rows | Daily hospital utilization |
| `data/samples/*_sample.csv` | ≤100 rows each | Offline demo (Path A) |

**Dictionary:** [`data/DATA_DICTIONARY.md`](data/DATA_DICTIONARY.md)  
**Power BI:** [`powerbi/BUILD_GUIDE.md`](powerbi/BUILD_GUIDE.md) (if present on your branch)

## Config (`.env`)

| Variable | Default | Meaning |
|----------|---------|---------|
| `FLUVIEW_STATES` | `ca,ny,tx,il,fl` | CDC state codes |
| `FLUVIEW_EPIWEEKS` | `202448-202518` | Week range (YYYYWW-YYYYWW) |
| `HHS_ROW_LIMIT` | `25000` | Max HHS rows per download |
| `POSTGRES_URL` | see `.env.example` | Warehouse branch only |

## Data sources & caveats

- **CDC FluView** — Weekly outpatient ILI ([API](https://cmu-delphi.github.io/delphi-epidata/api/fluview.html))
- **HHS hospital capacity** — COVID-era metrics; **reporting ended May 2024** ([dataset](https://healthdata.gov/Hospital/COVID-19-Reported-Patient-Impact-and-Hospital-Capa/g62h-syeh))

Flu is **weekly**; hospital is **daily**. Use separate Power BI pages.

## Project structure

```
├── ingest/              # fetch_cdc.py, fetch_hhs.py
├── transform/           # build_curated.py
├── load/                # load_warehouse.py (warehouse branch)
├── scripts/             # validate_curated.py, smoke_test.py, use_samples.py
├── sql/warehouse/       # star schema DDL (warehouse branch)
├── docker/              # start_postgres.ps1 / .sh
├── data/samples/        # committed demo CSVs
├── data/raw|curated/    # gitignored; created by pipeline
└── run_pipeline.ps1
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Docker ... pipe ... not found` | Start Docker Desktop, wait until `docker ps` works |
| CDC API error | Check `FLUVIEW_EPIWEEKS` format; use `202448-202518` |
| HHS timeout | Lower `HHS_ROW_LIMIT` in `.env` |
| No curated files | Run `.\run_pipeline.ps1` or `python scripts/use_samples.py` |
| Warehouse load fails | Set `POSTGRES_URL`; run `.\docker\start_postgres.ps1` first |
| Power BI only | Path A — no pipeline needed |

## Verify your install

```powershell
python scripts/smoke_test.py              # after Path B
python scripts/smoke_test.py --warehouse  # after Path C
```

Expected: `SMOKE TEST PASSED` / `WAREHOUSE SMOKE TEST PASSED`.
