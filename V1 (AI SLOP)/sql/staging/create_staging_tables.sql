-- Staging Tables for Influenza Surveillance ETL
-- These tables store raw data before transformation

-- CDC FluView Raw Data
CREATE TABLE IF NOT EXISTS staging.fluview_raw (
    id SERIAL PRIMARY KEY,
    year INTEGER,
    week INTEGER,
    region VARCHAR(100),
    state VARCHAR(100),
    total_specimens INTEGER,
    positive_specimens INTEGER,
    percent_positive DECIMAL(5,2),
    data_source VARCHAR(50),
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- WHO FluNet Raw Data
CREATE TABLE IF NOT EXISTS staging.flunet_raw (
    id SERIAL PRIMARY KEY,
    country VARCHAR(100),
    year INTEGER,
    week INTEGER,
    specimens_tested INTEGER,
    specimens_positive INTEGER,
    percent_positive DECIMAL(5,2),
    virus_type VARCHAR(50),
    data_source VARCHAR(50),
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Laboratory Results Raw Data
CREATE TABLE IF NOT EXISTS staging.lab_results_raw (
    id SERIAL PRIMARY KEY,
    lab_id VARCHAR(50),
    test_date DATE,
    test_type VARCHAR(50),
    result VARCHAR(50),
    patient_age_group VARCHAR(20),
    region VARCHAR(100),
    data_source VARCHAR(50),
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- State Health Department Reports Raw Data
CREATE TABLE IF NOT EXISTS staging.state_reports_raw (
    id SERIAL PRIMARY KEY,
    state VARCHAR(100),
    report_date DATE,
    report_type VARCHAR(50),
    cases_reported INTEGER,
    hospitalizations INTEGER,
    deaths INTEGER,
    activity_level VARCHAR(50),
    data_source VARCHAR(50),
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- HHS Hospital Utilization Raw Data
CREATE TABLE IF NOT EXISTS staging.hhs_hospital_utilization_raw (
    id SERIAL PRIMARY KEY,
    state_fips VARCHAR(2),
    state VARCHAR(2),
    hhs_region INTEGER,
    collection_week DATE,
    week_ending DATE,
    epiweek INTEGER,
    facility_id VARCHAR(100),
    cms_certification_number VARCHAR(50),
    -- Capacity metrics
    total_adult_patients_hospitalized_confirmed_and_suspected_covid INTEGER,
    total_adult_patients_hospitalized_confirmed_covid INTEGER,
    total_pediatric_patients_hospitalized_confirmed_and_suspected_covid INTEGER,
    total_pediatric_patients_hospitalized_confirmed_covid INTEGER,
    staffed_icu_adult_patients_confirmed_and_suspected_covid INTEGER,
    staffed_icu_adult_patients_confirmed_covid INTEGER,
    -- Bed capacity
    total_staffed_adult_icu_beds INTEGER,
    total_staffed_adult_icu_beds_occupied INTEGER,
    inpatient_beds INTEGER,
    inpatient_beds_occupied INTEGER,
    inpatient_beds_used INTEGER,
    all_adult_hospital_inpatient_beds INTEGER,
    all_adult_hospital_inpatient_bed_occupied INTEGER,
    all_pediatric_inpatient_beds INTEGER,
    all_pediatric_inpatient_beds_occupied INTEGER,
    all_adult_hospital_icu_beds INTEGER,
    all_adult_hospital_icu_beds_occupied INTEGER,
    -- Metadata
    has_missing_data BOOLEAN,
    data_source VARCHAR(50) DEFAULT 'hhs_hospital_utilization',
    source_system VARCHAR(50) DEFAULT 'healthdata.gov',
    ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Google Trends Raw Data
CREATE TABLE IF NOT EXISTS staging.google_trends_raw (
    id SERIAL PRIMARY KEY,
    state_abbreviation VARCHAR(2),
    search_date DATE,
    year INTEGER,
    week_number INTEGER,
    epiweek INTEGER,
    search_interest INTEGER,  -- Google Trends interest score (0-100)
    search_terms TEXT,  -- Comma-separated list of search terms
    data_source VARCHAR(50) DEFAULT 'google_trends',
    ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_fluview_year_week ON staging.fluview_raw(year, week);
CREATE INDEX IF NOT EXISTS idx_flunet_country_year ON staging.flunet_raw(country, year);
CREATE INDEX IF NOT EXISTS idx_lab_results_date ON staging.lab_results_raw(test_date);
CREATE INDEX IF NOT EXISTS idx_state_reports_date ON staging.state_reports_raw(report_date);
CREATE INDEX IF NOT EXISTS idx_hhs_collection_week ON staging.hhs_hospital_utilization_raw(collection_week);
CREATE INDEX IF NOT EXISTS idx_hhs_state_fips ON staging.hhs_hospital_utilization_raw(state_fips);
CREATE INDEX IF NOT EXISTS idx_hhs_epiweek ON staging.hhs_hospital_utilization_raw(epiweek);
CREATE INDEX IF NOT EXISTS idx_google_trends_date ON staging.google_trends_raw(search_date);
CREATE INDEX IF NOT EXISTS idx_google_trends_state ON staging.google_trends_raw(state_abbreviation);
CREATE INDEX IF NOT EXISTS idx_google_trends_epiweek ON staging.google_trends_raw(epiweek);
