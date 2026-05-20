CREATE TABLE IF NOT EXISTS staging.stg_flu_weekly (
    epiweek INTEGER,
    week_ending DATE,
    state VARCHAR(10),
    ili_pct DOUBLE PRECISION,
    wili_pct DOUBLE PRECISION,
    ili_cases INTEGER,
    patient_visits INTEGER
);

CREATE TABLE IF NOT EXISTS staging.stg_hospital_daily (
    report_date DATE,
    state VARCHAR(10),
    inpatient_beds INTEGER,
    inpatient_beds_used INTEGER,
    bed_utilization_pct DOUBLE PRECISION
);
