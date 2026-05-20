# Flu Surveillance ETL

Python pipeline: **fetch public health data → store raw → clean → CSV files for Power BI**.

Repo: https://github.com/SeanHK-CS/flu-surveillance-etl

**Optional DE extension:** PostgreSQL star schema + Airflow on branch [`feature/de-warehouse`](https://github.com/SeanHK-CS/flu-surveillance-etl/tree/feature/de-warehouse).

**Archive:** Original AI-generated project on [`archive/v1-ai-slop`](https://github.com/SeanHK-CS/flu-surveillance-etl/tree/archive/v1-ai-slop).

## Quick start (fork this repo)

### Path A — No API calls (≈1 minute)

```powershell
git clone https://github.com/SeanHK-CS/flu-surveillance-etl.git
cd flu-surveillance-etl
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python scripts/use_samples.py
python scripts/validate_curated.py
```

Import `data/curated/*.csv` in Power BI.

### Path B — Full live pipeline (≈1–2 minutes)

Requires internet:

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

## Flow

```
CDC API  ──► data/raw/cdc/     ──┐
                                 ├──► data/curated/*.csv ──► Power BI
HHS CSV  ──► data/raw/hhs/     ──┘
```

## Prerequisites

- Python 3.10+
- Internet (Path B)
- [Power BI Desktop](https://powerbi.microsoft.com/desktop/) (optional)

## Outputs

| File | Typical size | Use |
|------|----------------|-----|
| `data/curated/flu_weekly.csv` | ~115 rows | Weekly ILI % by state |
| `data/curated/hospital_daily.csv` | ~25,000 rows | Daily hospital utilization |
| `data/samples/*_sample.csv` | ≤100 rows | Offline demo (Path A) |

**Dictionary:** [`data/DATA_DICTIONARY.md`](data/DATA_DICTIONARY.md)

## Config (`.env`)

| Variable | Default | Meaning |
|----------|---------|---------|
| `FLUVIEW_STATES` | `ca,ny,tx,il,fl` | CDC state codes |
| `FLUVIEW_EPIWEEKS` | `202448-202518` | Week range (YYYYWW-YYYYWW) |
| `HHS_ROW_LIMIT` | `25000` | Max HHS rows per download |

## Data sources & caveats

- **CDC FluView** — Weekly outpatient ILI ([API](https://cmu-delphi.github.io/delphi-epidata/api/fluview.html))
- **HHS hospital capacity** — COVID-era metrics; **reporting ended May 2024** ([dataset](https://healthdata.gov/Hospital/COVID-19-Reported-Patient-Impact-and-Hospital-Capa/g62h-syeh))

Use separate Power BI pages for weekly flu vs daily hospital data.

## Project structure

```
├── ingest/           # fetch_cdc.py, fetch_hhs.py
├── transform/        # build_curated.py
├── scripts/          # validate_curated.py, smoke_test.py, use_samples.py
├── data/samples/     # committed demo CSVs
├── data/raw|curated/ # gitignored; created by pipeline
└── run_pipeline.ps1
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| CDC API error | Check `FLUVIEW_EPIWEEKS`; use `202448-202518` |
| HHS timeout | Lower `HHS_ROW_LIMIT` in `.env` |
| No curated files | Run `.\run_pipeline.ps1` or `python scripts/use_samples.py` |
| Postgres / warehouse | `git checkout feature/de-warehouse` — see `docs/DE_WAREHOUSE.md` |

## Verify

```powershell
python scripts/smoke_test.py
```

Expected: `CSV SMOKE TEST PASSED`.
