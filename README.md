# Flu Surveillance ETL

Python pipeline: **fetch public health data → store raw → clean → CSV files for Power BI**.

## Flow

```
CDC API  ──► data/raw/cdc/     ──┐
                                 ├──► data/curated/*.csv ──► Power BI
HHS CSV  ──► data/raw/hhs/     ──┘
```

## Prerequisites

- Python 3.10+
- Internet access (for full pipeline run)
- [Power BI Desktop](https://powerbi.microsoft.com/desktop/) (optional, for dashboards)

## Setup

```powershell
git clone <your-repo-url>
cd disease-trends
python -m venv .venv
.\.venv\Scripts\Activate.ps1   # Mac/Linux: source .venv/bin/activate
pip install -r requirements.txt
copy .env.example .env         # optional
```

## Run pipeline

```powershell
.\run_pipeline.ps1
```

Mac/Linux:

```bash
chmod +x run_pipeline.sh
./run_pipeline.sh
```

Or step by step:

```powershell
python -m ingest.fetch_cdc
python -m ingest.fetch_hhs
python -m transform.build_curated
python scripts/validate_curated.py
```

## Outputs for analysts

| File | Rows (typical) | Power BI |
|------|----------------|----------|
| `data/curated/flu_weekly.csv` | ~115 | Weekly ILI % by state |
| `data/curated/hospital_daily.csv` | ~25,000 | Daily hospital utilization |
| `data/samples/*_sample.csv` | ≤100 each | Quick demo without API calls |

**Column definitions:** [`data/DATA_DICTIONARY.md`](data/DATA_DICTIONARY.md)  
**Power BI steps:** [`powerbi/README.md`](powerbi/README.md)

## Config (`.env`)

| Variable | Default | Meaning |
|----------|---------|---------|
| `FLUVIEW_STATES` | `ca,ny,tx,il,fl` | CDC state codes |
| `FLUVIEW_EPIWEEKS` | `202448-202518` | Week range (YYYYWW-YYYYWW) |
| `HHS_ROW_LIMIT` | `25000` | Max HHS rows per download |

## Data sources & caveats

- **CDC FluView** — Weekly outpatient ILI surveillance ([API docs](https://cmu-delphi.github.io/delphi-epidata/api/fluview.html))
- **HHS hospital capacity** — COVID-era state hospital metrics; **reporting ended May 2024** ([dataset](https://healthdata.gov/Hospital/COVID-19-Reported-Patient-Impact-and-Hospital-Capa/g62h-syeh))

Flu and hospital files may cover **different date ranges**. Use separate report pages in Power BI.

## Project structure

```
├── ingest/           # fetch_cdc.py, fetch_hhs.py
├── transform/        # build_curated.py
├── scripts/          # validate_curated.py
├── data/raw/         # bronze (gitignored)
├── data/curated/     # gold CSVs (gitignored; regenerate locally)
├── data/samples/     # small demo files (committed)
├── powerbi/
└── run_pipeline.ps1
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| CDC API error | Check `FLUVIEW_EPIWEEKS` format; use `202448-202518` |
| HHS timeout | Lower `HHS_ROW_LIMIT` in `.env` |
| No curated files | Run `python scripts/validate_curated.py` after pipeline |
| Power BI only | Import `data/samples/*.csv` — no pipeline needed |
