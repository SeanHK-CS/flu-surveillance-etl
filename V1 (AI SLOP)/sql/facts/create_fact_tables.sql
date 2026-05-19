-- Fact Tables for Influenza Surveillance Data Warehouse
-- These tables store measurable facts (metrics) linked to dimension tables
-- Designed with incremental load support to prevent duplicate data

-- ============================================================================
-- FACT_FLU_CASES_WEEKLY - Weekly aggregated influenza case data
-- ============================================================================
-- Stores weekly aggregated metrics: cases, hospitalizations, deaths
-- Grain: One row per date_id, location_id, disease_id combination per week

CREATE TABLE IF NOT EXISTS facts.fact_flu_cases_weekly (
    fact_id BIGSERIAL PRIMARY KEY,
    -- Foreign keys to dimension tables
    date_id INTEGER NOT NULL REFERENCES dimensions.dim_date(date_id),
    location_id INTEGER NOT NULL REFERENCES dimensions.dim_location(location_id),
    disease_id INTEGER NOT NULL REFERENCES dimensions.dim_disease(disease_id),
    source_id INTEGER NOT NULL REFERENCES dimensions.dim_source(source_id),
    -- Fact measures
    cases INTEGER DEFAULT 0,
    positive_cases INTEGER DEFAULT 0,
    total_tests INTEGER DEFAULT 0,
    percent_positive DECIMAL(5, 2),
    hospitalizations INTEGER DEFAULT 0,
    deaths INTEGER DEFAULT 0,
    -- Additional metrics
    cases_7day_avg DECIMAL(10, 2),
    cases_30day_avg DECIMAL(10, 2),
    hospitalization_rate DECIMAL(10, 4),  -- per 100,000 population
    death_rate DECIMAL(10, 4),  -- per 100,000 population
    -- Metadata
    data_quality_score DECIMAL(3, 2),  -- 0.00 to 1.00
    is_estimated BOOLEAN DEFAULT FALSE,
    notes TEXT,
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Constraints
    CONSTRAINT uq_flu_cases_weekly UNIQUE (date_id, location_id, disease_id, source_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_fact_flu_cases_date ON facts.fact_flu_cases_weekly(date_id);
CREATE INDEX IF NOT EXISTS idx_fact_flu_cases_location ON facts.fact_flu_cases_weekly(location_id);
CREATE INDEX IF NOT EXISTS idx_fact_flu_cases_disease ON facts.fact_flu_cases_weekly(disease_id);
CREATE INDEX IF NOT EXISTS idx_fact_flu_cases_source ON facts.fact_flu_cases_weekly(source_id);
CREATE INDEX IF NOT EXISTS idx_fact_flu_cases_updated ON facts.fact_flu_cases_weekly(updated_timestamp);

-- Composite index for common queries
CREATE INDEX IF NOT EXISTS idx_fact_flu_cases_composite ON facts.fact_flu_cases_weekly(date_id, location_id, disease_id);

-- ============================================================================
-- FACT_FLU_HOSPITALIZATIONS_DAILY - Daily hospital utilization data
-- ============================================================================
-- Stores daily hospital metrics: admissions, ICU usage, bed capacity
-- Grain: One row per date_id, location_id, disease_id combination per day

CREATE TABLE IF NOT EXISTS facts.fact_flu_hospitalizations_daily (
    fact_id BIGSERIAL PRIMARY KEY,
    -- Foreign keys to dimension tables
    date_id INTEGER NOT NULL REFERENCES dimensions.dim_date(date_id),
    location_id INTEGER NOT NULL REFERENCES dimensions.dim_location(location_id),
    disease_id INTEGER NOT NULL REFERENCES dimensions.dim_disease(disease_id),
    source_id INTEGER NOT NULL REFERENCES dimensions.dim_source(source_id),
    -- Fact measures - Admissions
    admissions INTEGER DEFAULT 0,
    adult_admissions INTEGER DEFAULT 0,
    pediatric_admissions INTEGER DEFAULT 0,
    confirmed_admissions INTEGER DEFAULT 0,
    suspected_admissions INTEGER DEFAULT 0,
    -- Fact measures - ICU Usage
    icu_patients INTEGER DEFAULT 0,
    icu_adult_patients INTEGER DEFAULT 0,
    icu_pediatric_patients INTEGER DEFAULT 0,
    icu_confirmed_patients INTEGER DEFAULT 0,
    icu_suspected_patients INTEGER DEFAULT 0,
    -- Fact measures - Bed Capacity
    total_beds INTEGER DEFAULT 0,
    occupied_beds INTEGER DEFAULT 0,
    available_beds INTEGER DEFAULT 0,
    bed_utilization_rate DECIMAL(5, 2),  -- percentage
    -- Fact measures - ICU Capacity
    total_icu_beds INTEGER DEFAULT 0,
    occupied_icu_beds INTEGER DEFAULT 0,
    available_icu_beds INTEGER DEFAULT 0,
    icu_utilization_rate DECIMAL(5, 2),  -- percentage
    -- Calculated metrics
    admissions_7day_avg DECIMAL(10, 2),
    admissions_30day_avg DECIMAL(10, 2),
    icu_usage_7day_avg DECIMAL(10, 2),
    -- Metadata
    data_quality_score DECIMAL(3, 2),
    is_estimated BOOLEAN DEFAULT FALSE,
    has_missing_data BOOLEAN DEFAULT FALSE,
    notes TEXT,
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Constraints
    CONSTRAINT uq_flu_hosp_daily UNIQUE (date_id, location_id, disease_id, source_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_fact_hosp_date ON facts.fact_flu_hospitalizations_daily(date_id);
CREATE INDEX IF NOT EXISTS idx_fact_hosp_location ON facts.fact_flu_hospitalizations_daily(location_id);
CREATE INDEX IF NOT EXISTS idx_fact_hosp_disease ON facts.fact_flu_hospitalizations_daily(disease_id);
CREATE INDEX IF NOT EXISTS idx_fact_hosp_source ON facts.fact_flu_hospitalizations_daily(source_id);
CREATE INDEX IF NOT EXISTS idx_fact_hosp_updated ON facts.fact_flu_hospitalizations_daily(updated_timestamp);

-- Composite index for common queries
CREATE INDEX IF NOT EXISTS idx_fact_hosp_composite ON facts.fact_flu_hospitalizations_daily(date_id, location_id, disease_id);

-- ============================================================================
-- FACT_SEARCH_INTEREST_DAILY - Daily Google Trends search interest data
-- ============================================================================
-- Stores daily search interest metrics for flu-related terms by state
-- Grain: One row per date_id, location_id, source_id combination per day

CREATE TABLE IF NOT EXISTS facts.fact_search_interest_daily (
    fact_id BIGSERIAL PRIMARY KEY,
    -- Foreign keys to dimension tables
    date_id INTEGER NOT NULL REFERENCES dimensions.dim_date(date_id),
    location_id INTEGER NOT NULL REFERENCES dimensions.dim_location(location_id),
    source_id INTEGER NOT NULL REFERENCES dimensions.dim_source(source_id),
    -- Fact measures
    search_interest INTEGER DEFAULT 0,  -- Google Trends interest score (0-100)
    search_interest_7day_avg DECIMAL(10, 2),
    search_interest_30day_avg DECIMAL(10, 2),
    search_terms TEXT,  -- Comma-separated list of search terms
    -- Trend indicators
    trend_flag VARCHAR(20),  -- 'rising', 'stable', 'declining'
    percent_change_7day DECIMAL(5, 2),  -- Percent change from 7 days ago
    percent_change_30day DECIMAL(5, 2),  -- Percent change from 30 days ago
    -- Metadata
    data_quality_score DECIMAL(3, 2),
    is_estimated BOOLEAN DEFAULT FALSE,
    notes TEXT,
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Constraints
    CONSTRAINT uq_search_interest_daily UNIQUE (date_id, location_id, source_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_fact_search_date ON facts.fact_search_interest_daily(date_id);
CREATE INDEX IF NOT EXISTS idx_fact_search_location ON facts.fact_search_interest_daily(location_id);
CREATE INDEX IF NOT EXISTS idx_fact_search_source ON facts.fact_search_interest_daily(source_id);
CREATE INDEX IF NOT EXISTS idx_fact_search_updated ON facts.fact_search_interest_daily(updated_timestamp);
CREATE INDEX IF NOT EXISTS idx_fact_search_trend ON facts.fact_search_interest_daily(trend_flag);

-- Composite index for common queries
CREATE INDEX IF NOT EXISTS idx_fact_search_composite ON facts.fact_search_interest_daily(date_id, location_id);

-- ============================================================================
-- Comments for documentation
-- ============================================================================

COMMENT ON TABLE facts.fact_flu_cases_weekly IS 'Weekly aggregated influenza case data with cases, hospitalizations, and deaths';
COMMENT ON TABLE facts.fact_flu_hospitalizations_daily IS 'Daily hospital utilization data with admissions, ICU usage, and bed capacity';

COMMENT ON COLUMN facts.fact_flu_cases_weekly.date_id IS 'Foreign key to dim_date - represents the week ending date';
COMMENT ON COLUMN facts.fact_flu_cases_weekly.location_id IS 'Foreign key to dim_location - geographic location';
COMMENT ON COLUMN facts.fact_flu_cases_weekly.disease_id IS 'Foreign key to dim_disease - disease type (e.g., Influenza A, B)';
COMMENT ON COLUMN facts.fact_flu_cases_weekly.source_id IS 'Foreign key to dim_source - data source (e.g., CDC FluView)';

COMMENT ON COLUMN facts.fact_flu_hospitalizations_daily.date_id IS 'Foreign key to dim_date - represents the specific day';
COMMENT ON COLUMN facts.fact_flu_hospitalizations_daily.location_id IS 'Foreign key to dim_location - geographic location';
COMMENT ON COLUMN facts.fact_flu_hospitalizations_daily.disease_id IS 'Foreign key to dim_disease - disease type';
COMMENT ON COLUMN facts.fact_flu_hospitalizations_daily.source_id IS 'Foreign key to dim_source - data source (e.g., HHS Hospital Utilization)';
