CREATE OR REPLACE VIEW analytics.flu_weekly AS
SELECT
    d.full_date AS week_ending,
    d.epiweek,
    l.state_code AS state,
    f.ili_pct,
    f.wili_pct,
    f.ili_cases,
    f.patient_visits,
    src.source_name
FROM facts.fact_flu_weekly f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
JOIN dimensions.dim_source src ON f.source_id = src.source_id;

CREATE OR REPLACE VIEW analytics.hospital_daily AS
SELECT
    d.full_date AS report_date,
    l.state_code AS state,
    f.inpatient_beds,
    f.inpatient_beds_used,
    f.bed_utilization_pct,
    src.source_name
FROM facts.fact_hospital_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
JOIN dimensions.dim_source src ON f.source_id = src.source_id;
