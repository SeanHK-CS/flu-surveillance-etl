-- Refresh dimensions from staging
INSERT INTO dimensions.dim_location (state_code)
SELECT DISTINCT state FROM staging.stg_flu_weekly WHERE state IS NOT NULL
ON CONFLICT (state_code) DO NOTHING;

INSERT INTO dimensions.dim_location (state_code)
SELECT DISTINCT state FROM staging.stg_hospital_daily WHERE state IS NOT NULL
ON CONFLICT (state_code) DO NOTHING;

INSERT INTO dimensions.dim_date (date_id, full_date, epiweek, year, month)
SELECT DISTINCT
    CAST(TO_CHAR(week_ending, 'YYYYMMDD') AS INTEGER),
    week_ending,
    epiweek,
    EXTRACT(YEAR FROM week_ending)::INTEGER,
    EXTRACT(MONTH FROM week_ending)::INTEGER
FROM staging.stg_flu_weekly
WHERE week_ending IS NOT NULL
ON CONFLICT (full_date) DO NOTHING;

INSERT INTO dimensions.dim_date (date_id, full_date, epiweek, year, month)
SELECT DISTINCT
    CAST(TO_CHAR(report_date, 'YYYYMMDD') AS INTEGER),
    report_date,
    NULL,
    EXTRACT(YEAR FROM report_date)::INTEGER,
    EXTRACT(MONTH FROM report_date)::INTEGER
FROM staging.stg_hospital_daily
WHERE report_date IS NOT NULL
ON CONFLICT (full_date) DO NOTHING;

-- Reload facts (idempotent for dev)
TRUNCATE facts.fact_flu_weekly, facts.fact_hospital_daily;

INSERT INTO facts.fact_flu_weekly (
    date_id, location_id, source_id,
    ili_pct, wili_pct, ili_cases, patient_visits
)
SELECT
    d.date_id,
    l.location_id,
    s.source_id,
    f.ili_pct,
    f.wili_pct,
    f.ili_cases,
    f.patient_visits
FROM staging.stg_flu_weekly f
JOIN dimensions.dim_date d ON d.full_date = f.week_ending
JOIN dimensions.dim_location l ON l.state_code = f.state
JOIN dimensions.dim_source s ON s.source_code = 'cdc_fluview';

INSERT INTO facts.fact_hospital_daily (
    date_id, location_id, source_id,
    inpatient_beds, inpatient_beds_used, bed_utilization_pct
)
SELECT
    d.date_id,
    l.location_id,
    s.source_id,
    h.inpatient_beds,
    h.inpatient_beds_used,
    h.bed_utilization_pct
FROM staging.stg_hospital_daily h
JOIN dimensions.dim_date d ON d.full_date = h.report_date
JOIN dimensions.dim_location l ON l.state_code = h.state
JOIN dimensions.dim_source s ON s.source_code = 'hhs_hospital';
