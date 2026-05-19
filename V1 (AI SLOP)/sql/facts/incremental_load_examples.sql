-- Example SQL Statements for Incremental Loading
-- These examples show how to use the incremental load functions
-- and direct INSERT ... ON CONFLICT statements

-- ============================================================================
-- Example 1: Using the load_flu_cases_weekly function
-- ============================================================================

-- Load a single weekly record
SELECT facts.load_flu_cases_weekly(
    p_date_id := 20240101,  -- Date ID for the week
    p_location_id := 1,      -- Location ID (e.g., California)
    p_disease_id := 1,      -- Disease ID (e.g., Influenza)
    p_source_id := 1,       -- Source ID (e.g., CDC FluView)
    p_cases := 1500,
    p_positive_cases := 450,
    p_total_tests := 5000,
    p_percent_positive := 9.0,
    p_hospitalizations := 120,
    p_deaths := 5
);

-- ============================================================================
-- Example 2: Direct INSERT with ON CONFLICT (Alternative approach)
-- ============================================================================

-- This approach is useful for bulk loading from staging tables
INSERT INTO facts.fact_flu_cases_weekly (
    date_id,
    location_id,
    disease_id,
    source_id,
    cases,
    positive_cases,
    total_tests,
    percent_positive,
    hospitalizations,
    deaths,
    updated_timestamp
)
SELECT
    d.date_id,
    l.location_id,
    di.disease_id,
    s.source_id,
    COALESCE(stg.total_specimens, 0) as cases,
    COALESCE(stg.positive_specimens, 0) as positive_cases,
    COALESCE(stg.total_specimens, 0) as total_tests,
    stg.percent_positive,
    0 as hospitalizations,
    0 as deaths,
    CURRENT_TIMESTAMP
FROM staging.fluview_raw stg
JOIN dimensions.dim_date d 
    ON d.year = stg.year 
    AND d.week_number = stg.week
JOIN dimensions.dim_location l 
    ON l.state_code = stg.state 
    AND l.location_type = 'state'
JOIN dimensions.dim_disease di 
    ON di.disease_code = 'FLU'
JOIN dimensions.dim_source s 
    ON s.source_code = 'cdc_fluview'
WHERE stg.load_timestamp >= CURRENT_DATE - INTERVAL '7 days'
ON CONFLICT (date_id, location_id, disease_id, source_id)
DO UPDATE SET
    cases = EXCLUDED.cases,
    positive_cases = EXCLUDED.positive_cases,
    total_tests = EXCLUDED.total_tests,
    percent_positive = EXCLUDED.percent_positive,
    updated_timestamp = CURRENT_TIMESTAMP;

-- ============================================================================
-- Example 3: Using the batch load function
-- ============================================================================

-- Load all data from staging for the last 7 days
SELECT * FROM facts.load_flu_cases_weekly_from_staging(
    p_start_date := CURRENT_DATE - INTERVAL '7 days',
    p_end_date := CURRENT_DATE
);

-- Load all data from staging (no date filter)
SELECT * FROM facts.load_flu_cases_weekly_from_staging();

-- ============================================================================
-- Example 4: Load daily hospitalizations using function
-- ============================================================================

SELECT facts.load_flu_hospitalizations_daily(
    p_date_id := 20240115,
    p_location_id := 5,
    p_disease_id := 1,
    p_source_id := 3,  -- HHS source
    p_admissions := 250,
    p_adult_admissions := 200,
    p_pediatric_admissions := 50,
    p_icu_patients := 45,
    p_total_beds := 1000,
    p_occupied_beds := 850,
    p_bed_utilization_rate := 85.0,
    p_total_icu_beds := 100,
    p_occupied_icu_beds := 90,
    p_icu_utilization_rate := 90.0
);

-- ============================================================================
-- Example 5: Direct INSERT for daily hospitalizations
-- ============================================================================

INSERT INTO facts.fact_flu_hospitalizations_daily (
    date_id,
    location_id,
    disease_id,
    source_id,
    admissions,
    adult_admissions,
    total_beds,
    occupied_beds,
    bed_utilization_rate,
    total_icu_beds,
    occupied_icu_beds,
    icu_utilization_rate,
    updated_timestamp
)
SELECT
    d.date_id,
    l.location_id,
    di.disease_id,
    s.source_id,
    COALESCE(hhs.total_adult_patients_hospitalized_confirmed_and_suspected_covid, 0),
    COALESCE(hhs.total_adult_patients_hospitalized_confirmed_and_suspected_covid, 0),
    COALESCE(hhs.inpatient_beds, 0),
    COALESCE(hhs.inpatient_beds_occupied, 0),
    CASE 
        WHEN hhs.inpatient_beds > 0 
        THEN (hhs.inpatient_beds_occupied::DECIMAL / hhs.inpatient_beds) * 100
        ELSE NULL
    END,
    COALESCE(hhs.total_staffed_adult_icu_beds, 0),
    COALESCE(hhs.total_staffed_adult_icu_beds_occupied, 0),
    CASE 
        WHEN hhs.total_staffed_adult_icu_beds > 0 
        THEN (hhs.total_staffed_adult_icu_beds_occupied::DECIMAL / hhs.total_staffed_adult_icu_beds) * 100
        ELSE NULL
    END,
    CURRENT_TIMESTAMP
FROM staging.hhs_hospital_utilization_raw hhs
JOIN dimensions.dim_date d 
    ON d.full_date = hhs.collection_week::DATE
JOIN dimensions.dim_location l 
    ON l.state_fips = hhs.state_fips 
    AND l.location_type = 'state'
JOIN dimensions.dim_disease di 
    ON di.disease_code = 'FLU'  -- or 'COVID19' depending on data
JOIN dimensions.dim_source s 
    ON s.source_code = 'hhs_hosp'
WHERE hhs.collection_week >= CURRENT_DATE - INTERVAL '7 days'
ON CONFLICT (date_id, location_id, disease_id, source_id)
DO UPDATE SET
    admissions = EXCLUDED.admissions,
    adult_admissions = EXCLUDED.adult_admissions,
    total_beds = EXCLUDED.total_beds,
    occupied_beds = EXCLUDED.occupied_beds,
    bed_utilization_rate = EXCLUDED.bed_utilization_rate,
    total_icu_beds = EXCLUDED.total_icu_beds,
    occupied_icu_beds = EXCLUDED.occupied_icu_beds,
    icu_utilization_rate = EXCLUDED.icu_utilization_rate,
    updated_timestamp = CURRENT_TIMESTAMP;

-- ============================================================================
-- Example 6: Using batch load function for hospitalizations
-- ============================================================================

SELECT * FROM facts.load_hospitalizations_daily_from_staging(
    p_start_date := CURRENT_DATE - INTERVAL '7 days',
    p_end_date := CURRENT_DATE
);

-- ============================================================================
-- Example 7: Check for duplicates before loading
-- ============================================================================

-- Query to check existing records
SELECT 
    d.full_date,
    l.state_name,
    di.disease_name,
    s.source_name,
    f.cases,
    f.hospitalizations
FROM facts.fact_flu_cases_weekly f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
JOIN dimensions.dim_disease di ON f.disease_id = di.disease_id
JOIN dimensions.dim_source s ON f.source_id = s.source_id
WHERE d.year = 2024
  AND d.week_number = 40
ORDER BY l.state_name;

-- ============================================================================
-- Example 8: Incremental load with date range
-- ============================================================================

-- Load only new/updated records from staging
INSERT INTO facts.fact_flu_cases_weekly (
    date_id, location_id, disease_id, source_id,
    cases, positive_cases, total_tests, percent_positive,
    updated_timestamp
)
SELECT
    d.date_id,
    l.location_id,
    di.disease_id,
    s.source_id,
    stg.total_specimens,
    stg.positive_specimens,
    stg.total_specimens,
    stg.percent_positive,
    CURRENT_TIMESTAMP
FROM staging.fluview_raw stg
JOIN dimensions.dim_date d ON d.year = stg.year AND d.week_number = stg.week
JOIN dimensions.dim_location l ON l.state_code = stg.state AND l.location_type = 'state'
JOIN dimensions.dim_disease di ON di.disease_code = 'FLU'
JOIN dimensions.dim_source s ON s.source_code = 'cdc_fluview'
WHERE stg.load_timestamp >= CURRENT_DATE - INTERVAL '1 day'
  AND NOT EXISTS (
      SELECT 1 FROM facts.fact_flu_cases_weekly f
      WHERE f.date_id = d.date_id
        AND f.location_id = l.location_id
        AND f.disease_id = di.disease_id
        AND f.source_id = s.source_id
        AND f.updated_timestamp >= stg.load_timestamp - INTERVAL '1 hour'
  )
ON CONFLICT (date_id, location_id, disease_id, source_id)
DO UPDATE SET
    cases = EXCLUDED.cases,
    positive_cases = EXCLUDED.positive_cases,
    total_tests = EXCLUDED.total_tests,
    percent_positive = EXCLUDED.percent_positive,
    updated_timestamp = CURRENT_TIMESTAMP
WHERE facts.fact_flu_cases_weekly.updated_timestamp < EXCLUDED.updated_timestamp;
