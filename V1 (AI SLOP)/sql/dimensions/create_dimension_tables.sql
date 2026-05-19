-- Dimension Tables for Influenza Surveillance Data Warehouse
-- These tables provide reference data for fact tables in a star schema design
-- Designed to be extensible for other diseases and future data sources

-- ============================================================================
-- DIM_DATE - Date dimension table
-- ============================================================================
-- Provides date-related attributes for time-based analysis
-- Supports daily, weekly, monthly, and yearly aggregations

CREATE TABLE IF NOT EXISTS dimensions.dim_date (
    date_id INTEGER PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    day_of_week INTEGER NOT NULL,  -- 1=Monday, 7=Sunday
    day_name VARCHAR(10) NOT NULL,  -- Monday, Tuesday, etc.
    day_of_month INTEGER NOT NULL,
    day_of_year INTEGER NOT NULL,
    week_number INTEGER NOT NULL,  -- ISO week number (1-53)
    week_start_date DATE NOT NULL,  -- Monday of the week
    week_end_date DATE NOT NULL,  -- Sunday of the week
    epiweek INTEGER,  -- CDC epiweek format (YYYYWW)
    month INTEGER NOT NULL,  -- 1-12
    month_name VARCHAR(10) NOT NULL,  -- January, February, etc.
    month_abbreviation VARCHAR(3) NOT NULL,  -- Jan, Feb, etc.
    quarter INTEGER NOT NULL,  -- 1-4
    quarter_name VARCHAR(2) NOT NULL,  -- Q1, Q2, Q3, Q4
    year INTEGER NOT NULL,
    year_quarter VARCHAR(7) NOT NULL,  -- 2024-Q1
    year_month VARCHAR(7) NOT NULL,  -- 2024-01
    is_weekend BOOLEAN NOT NULL,
    is_holiday BOOLEAN DEFAULT FALSE,
    holiday_name VARCHAR(50),
    flu_season VARCHAR(20),  -- e.g., "2023-2024"
    flu_season_week INTEGER,  -- Week within flu season (typically starts week 40)
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_dim_date_full_date ON dimensions.dim_date(full_date);
CREATE INDEX IF NOT EXISTS idx_dim_date_year_month ON dimensions.dim_date(year, month);
CREATE INDEX IF NOT EXISTS idx_dim_date_year_week ON dimensions.dim_date(year, week_number);
CREATE INDEX IF NOT EXISTS idx_dim_date_epiweek ON dimensions.dim_date(epiweek);
CREATE INDEX IF NOT EXISTS idx_dim_date_flu_season ON dimensions.dim_date(flu_season, flu_season_week);

-- ============================================================================
-- DIM_LOCATION - Location dimension table
-- ============================================================================
-- Provides geographic hierarchy for location-based analysis
-- Extensible to support countries, counties, cities, etc.

CREATE TABLE IF NOT EXISTS dimensions.dim_location (
    location_id SERIAL PRIMARY KEY,
    location_type VARCHAR(50) NOT NULL,  -- 'country', 'state', 'region', 'county', 'city'
    location_code VARCHAR(50) NOT NULL,  -- State code, FIPS code, etc.
    location_name VARCHAR(100) NOT NULL,
    -- Geographic hierarchy
    country_code VARCHAR(3),  -- ISO country code (USA, CAN, etc.)
    country_name VARCHAR(100),
    state_code VARCHAR(2),  -- US state abbreviation (AL, AK, etc.)
    state_name VARCHAR(100),
    state_fips VARCHAR(2),  -- FIPS state code
    region_code VARCHAR(10),  -- HHS region, Census region, etc.
    region_name VARCHAR(100),
    region_type VARCHAR(50),  -- 'hhs', 'census', 'cdc', etc.
    -- Additional attributes
    population INTEGER,  -- Population count (if available)
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    timezone VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,  -- For soft deletes
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Constraints
    CONSTRAINT uq_location_code_type UNIQUE (location_code, location_type)
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_dim_location_state_code ON dimensions.dim_location(state_code);
CREATE INDEX IF NOT EXISTS idx_dim_location_state_fips ON dimensions.dim_location(state_fips);
CREATE INDEX IF NOT EXISTS idx_dim_location_region_code ON dimensions.dim_location(region_code);
CREATE INDEX IF NOT EXISTS idx_dim_location_country_code ON dimensions.dim_location(country_code);
CREATE INDEX IF NOT EXISTS idx_dim_location_type ON dimensions.dim_location(location_type);

-- ============================================================================
-- DIM_DISEASE - Disease dimension table
-- ============================================================================
-- Provides disease classification for multi-disease surveillance
-- Extensible to support any disease or health condition

CREATE TABLE IF NOT EXISTS dimensions.dim_disease (
    disease_id SERIAL PRIMARY KEY,
    disease_code VARCHAR(50) NOT NULL UNIQUE,  -- ICD-10 code, disease abbreviation, etc.
    disease_name VARCHAR(200) NOT NULL,
    disease_category VARCHAR(100),  -- 'respiratory', 'infectious', 'chronic', etc.
    disease_type VARCHAR(100),  -- 'influenza', 'covid-19', 'rsv', etc.
    -- Disease classification
    icd10_code VARCHAR(20),  -- ICD-10 classification code
    icd10_description VARCHAR(500),
    -- Surveillance attributes
    is_reportable BOOLEAN DEFAULT TRUE,  -- Is this a reportable disease?
    surveillance_type VARCHAR(50),  -- 'syndromic', 'laboratory', 'clinical', etc.
    -- Additional metadata
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_dim_disease_code ON dimensions.dim_disease(disease_code);
CREATE INDEX IF NOT EXISTS idx_dim_disease_category ON dimensions.dim_disease(disease_category);
CREATE INDEX IF NOT EXISTS idx_dim_disease_type ON dimensions.dim_disease(disease_type);
CREATE INDEX IF NOT EXISTS idx_dim_disease_icd10 ON dimensions.dim_disease(icd10_code);

-- ============================================================================
-- DIM_SOURCE - Data source dimension table
-- ============================================================================
-- Provides data source classification for multi-source surveillance
-- Extensible to support any data source

CREATE TABLE IF NOT EXISTS dimensions.dim_source (
    source_id SERIAL PRIMARY KEY,
    source_code VARCHAR(50) NOT NULL UNIQUE,  -- Short identifier (e.g., 'cdc_fluview', 'hhs_hosp')
    source_name VARCHAR(200) NOT NULL,  -- Full name (e.g., 'CDC FluView', 'HHS Hospital Utilization')
    source_type VARCHAR(50) NOT NULL,  -- 'api', 'csv', 'database', 'file', etc.
    source_category VARCHAR(100),  -- 'government', 'healthcare', 'laboratory', 'research', etc.
    -- Source details
    organization VARCHAR(200),  -- Organization name (CDC, WHO, HHS, etc.)
    api_endpoint VARCHAR(500),  -- API endpoint URL if applicable
    data_format VARCHAR(50),  -- 'json', 'csv', 'xml', etc.
    update_frequency VARCHAR(50),  -- 'daily', 'weekly', 'monthly', 'real-time', etc.
    -- Data quality attributes
    data_quality_score DECIMAL(3, 2),  -- 0.00 to 1.00
    reliability_level VARCHAR(20),  -- 'high', 'medium', 'low'
    -- Additional metadata
    description TEXT,
    contact_info VARCHAR(500),
    documentation_url VARCHAR(500),
    is_active BOOLEAN DEFAULT TRUE,
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_dim_source_code ON dimensions.dim_source(source_code);
CREATE INDEX IF NOT EXISTS idx_dim_source_type ON dimensions.dim_source(source_type);
CREATE INDEX IF NOT EXISTS idx_dim_source_category ON dimensions.dim_source(source_category);
CREATE INDEX IF NOT EXISTS idx_dim_source_organization ON dimensions.dim_source(organization);

-- ============================================================================
-- Comments for documentation
-- ============================================================================

COMMENT ON TABLE dimensions.dim_date IS 'Date dimension table providing time-based attributes for analysis';
COMMENT ON TABLE dimensions.dim_location IS 'Location dimension table providing geographic hierarchy and attributes';
COMMENT ON TABLE dimensions.dim_disease IS 'Disease dimension table providing disease classification and metadata';
COMMENT ON TABLE dimensions.dim_source IS 'Data source dimension table providing source classification and metadata';

COMMENT ON COLUMN dimensions.dim_date.epiweek IS 'CDC epidemiological week format: YYYYWW (e.g., 202440)';
COMMENT ON COLUMN dimensions.dim_date.flu_season IS 'Influenza season identifier (e.g., 2023-2024)';
COMMENT ON COLUMN dimensions.dim_location.location_type IS 'Type of location: country, state, region, county, city';
COMMENT ON COLUMN dimensions.dim_location.state_fips IS 'FIPS state code for matching with CDC data';
COMMENT ON COLUMN dimensions.dim_disease.disease_code IS 'Unique disease identifier (e.g., FLU, COVID19, RSV)';
COMMENT ON COLUMN dimensions.dim_source.source_code IS 'Unique source identifier (e.g., cdc_fluview, hhs_hosp)';
