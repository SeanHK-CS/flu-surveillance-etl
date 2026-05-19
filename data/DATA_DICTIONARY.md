# Data dictionary (Power BI / analyst reference)

## flu_weekly.csv

| Column | Type | Description |
|--------|------|-------------|
| `epiweek` | int | CDC epidemiological week (YYYYWW) |
| `week_ending` | date | Saturday ending that epi week |
| `state` | text | US state code (CA, NY, …) |
| `ili_pct` | number | % of visits with influenza-like illness |
| `wili_pct` | number | Population-weighted ILI % |
| `ili_cases` | int | Count of ILI cases |
| `patient_visits` | int | Total patients in surveillance network |

**Grain:** one row per state per week  
**Source:** CDC FluView via Delphi Epidata API

---

## hospital_daily.csv

| Column | Type | Description |
|--------|------|-------------|
| `report_date` | date | Reporting date |
| `state` | text | US state or territory code |
| `inpatient_beds` | int | Inpatient beds |
| `inpatient_beds_used` | int | Inpatient beds in use |
| `bed_utilization_pct` | number | Used beds / total beds × 100 |
| `icu_covid_patients` | number | ICU patients with COVID (may be null) |
| `covid_admissions` | int | Confirmed COVID admissions prior day |
| `covid_admissions_suspected` | number | Suspected COVID admissions (may be null) |

**Grain:** one row per state per day  
**Source:** HHS hospital capacity dataset (COVID-era; reporting ended May 2024)

---

## Important for dashboards

- **Do not blend** flu_weekly and hospital_daily on one axis without aligning grain (week vs day).
- Date ranges may **not overlap** — flu file is recent season; hospital file is historical sample from API limit.
- Use `data/samples/` for a quick Power BI test without running ingest.
