-- Utility Functions for Data Transformations
-- These functions provide reusable logic for standardization and calculations

-- ============================================================================
-- Function: Standardize Location Code
-- ============================================================================
-- Converts various location codes (state abbreviations, FIPS, etc.) to location_id
-- Handles multiple input formats and returns the standardized location_id

CREATE OR REPLACE FUNCTION transform.standardize_location(
    p_state_code VARCHAR(10) DEFAULT NULL,
    p_state_fips VARCHAR(10) DEFAULT NULL,
    p_region_code VARCHAR(10) DEFAULT NULL,
    p_location_type VARCHAR(50) DEFAULT 'state'
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_location_id INTEGER;
BEGIN
    -- Try to find location by state code first
    IF p_state_code IS NOT NULL THEN
        SELECT location_id INTO v_location_id
        FROM dimensions.dim_location
        WHERE state_code = UPPER(TRIM(p_state_code))
          AND location_type = p_location_type
        LIMIT 1;
    END IF;
    
    -- If not found, try FIPS code
    IF v_location_id IS NULL AND p_state_fips IS NOT NULL THEN
        SELECT location_id INTO v_location_id
        FROM dimensions.dim_location
        WHERE state_fips = LPAD(TRIM(p_state_fips), 2, '0')
          AND location_type = p_location_type
        LIMIT 1;
    END IF;
    
    -- If still not found, try region code
    IF v_location_id IS NULL AND p_region_code IS NOT NULL THEN
        SELECT location_id INTO v_location_id
        FROM dimensions.dim_location
        WHERE region_code = p_region_code
          AND location_type = 'region'
        LIMIT 1;
    END IF;
    
    RETURN v_location_id;
END;
$$;

-- ============================================================================
-- Function: Get Date ID from Various Date Formats
-- ============================================================================
-- Converts various date formats to date_id for dimension lookup

CREATE OR REPLACE FUNCTION transform.get_date_id(
    p_date DATE DEFAULT NULL,
    p_year INTEGER DEFAULT NULL,
    p_week INTEGER DEFAULT NULL,
    p_epiweek INTEGER DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_date_id INTEGER;
    v_target_date DATE;
BEGIN
    -- If date is provided, use it directly
    IF p_date IS NOT NULL THEN
        SELECT date_id INTO v_date_id
        FROM dimensions.dim_date
        WHERE full_date = p_date
        LIMIT 1;
    -- If year and week are provided, find the week ending date
    ELSIF p_year IS NOT NULL AND p_week IS NOT NULL THEN
        SELECT date_id INTO v_date_id
        FROM dimensions.dim_date
        WHERE year = p_year
          AND week_number = p_week
        ORDER BY full_date DESC  -- Get week ending date
        LIMIT 1;
    -- If epiweek is provided, parse it
    ELSIF p_epiweek IS NOT NULL THEN
        SELECT date_id INTO v_date_id
        FROM dimensions.dim_date
        WHERE epiweek = p_epiweek
        ORDER BY full_date DESC
        LIMIT 1;
    END IF;
    
    RETURN v_date_id;
END;
$$;

-- ============================================================================
-- Function: Calculate Trend Direction
-- ============================================================================
-- Determines trend direction (rising/stable/declining) based on 2-week change
-- Returns: 'rising', 'declining', or 'stable'

CREATE OR REPLACE FUNCTION transform.calculate_trend(
    p_current_value DECIMAL,
    p_previous_value DECIMAL,
    p_change_threshold DECIMAL DEFAULT 0.10  -- 10% change threshold
)
RETURNS VARCHAR(20)
LANGUAGE plpgsql
AS $$
DECLARE
    v_change_percent DECIMAL;
    v_trend VARCHAR(20);
BEGIN
    -- Handle NULL values
    IF p_current_value IS NULL OR p_previous_value IS NULL OR p_previous_value = 0 THEN
        RETURN 'unknown';
    END IF;
    
    -- Calculate percent change
    v_change_percent := ((p_current_value - p_previous_value) / p_previous_value) * 100;
    
    -- Determine trend
    IF v_change_percent > (p_change_threshold * 100) THEN
        v_trend := 'rising';
    ELSIF v_change_percent < (-p_change_threshold * 100) THEN
        v_trend := 'declining';
    ELSE
        v_trend := 'stable';
    END IF;
    
    RETURN v_trend;
END;
$$;

-- ============================================================================
-- Function: Calculate Rolling Average
-- ============================================================================
-- Calculates rolling average for a given date and location
-- Returns the average value over the specified number of days

CREATE OR REPLACE FUNCTION transform.calculate_rolling_avg(
    p_date_id INTEGER,
    p_location_id INTEGER,
    p_disease_id INTEGER,
    p_source_id INTEGER,
    p_metric_column VARCHAR(50),  -- 'cases', 'admissions', etc.
    p_days INTEGER DEFAULT 7,
    p_table_name VARCHAR(100) DEFAULT 'fact_flu_cases_weekly'
)
RETURNS DECIMAL
LANGUAGE plpgsql
AS $$
DECLARE
    v_avg_value DECIMAL;
    v_sql TEXT;
BEGIN
    -- Build dynamic SQL based on table and metric
    IF p_table_name = 'fact_flu_cases_weekly' THEN
        v_sql := format('
            SELECT AVG(%I)::DECIMAL
            FROM facts.fact_flu_cases_weekly f
            JOIN dimensions.dim_date d ON f.date_id = d.date_id
            WHERE f.location_id = $1
              AND f.disease_id = $2
              AND f.source_id = $3
              AND d.full_date <= (
                  SELECT full_date FROM dimensions.dim_date WHERE date_id = $4
              )
              AND d.full_date > (
                  SELECT full_date - INTERVAL ''%s days''
                  FROM dimensions.dim_date
                  WHERE date_id = $4
              )
        ', p_metric_column, p_days);
        
        EXECUTE v_sql INTO v_avg_value
        USING p_location_id, p_disease_id, p_source_id, p_date_id;
    ELSIF p_table_name = 'fact_flu_hospitalizations_daily' THEN
        v_sql := format('
            SELECT AVG(%I)::DECIMAL
            FROM facts.fact_flu_hospitalizations_daily f
            JOIN dimensions.dim_date d ON f.date_id = d.date_id
            WHERE f.location_id = $1
              AND f.disease_id = $2
              AND f.source_id = $3
              AND d.full_date <= (
                  SELECT full_date FROM dimensions.dim_date WHERE date_id = $4
              )
              AND d.full_date > (
                  SELECT full_date - INTERVAL ''%s days''
                  FROM dimensions.dim_date
                  WHERE date_id = $4
              )
        ', p_metric_column, p_days);
        
        EXECUTE v_sql INTO v_avg_value
        USING p_location_id, p_disease_id, p_source_id, p_date_id;
    END IF;
    
    RETURN COALESCE(v_avg_value, 0);
END;
$$;

-- ============================================================================
-- Function: Handle Late-Arriving Data
-- ============================================================================
-- Checks if data for a given date/location already exists and needs updating
-- Returns TRUE if update is needed, FALSE if data is current

CREATE OR REPLACE FUNCTION transform.is_late_arriving_data(
    p_date_id INTEGER,
    p_location_id INTEGER,
    p_disease_id INTEGER,
    p_source_id INTEGER,
    p_staging_load_timestamp TIMESTAMP,
    p_table_name VARCHAR(100) DEFAULT 'fact_flu_cases_weekly'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_exists BOOLEAN;
    v_current_timestamp TIMESTAMP;
BEGIN
    IF p_table_name = 'fact_flu_cases_weekly' THEN
        SELECT EXISTS(
            SELECT 1 FROM facts.fact_flu_cases_weekly
            WHERE date_id = p_date_id
              AND location_id = p_location_id
              AND disease_id = p_disease_id
              AND source_id = p_source_id
        ), updated_timestamp INTO v_exists, v_current_timestamp
        FROM facts.fact_flu_cases_weekly
        WHERE date_id = p_date_id
          AND location_id = p_location_id
          AND disease_id = p_disease_id
          AND source_id = p_source_id
        LIMIT 1;
    ELSIF p_table_name = 'fact_flu_hospitalizations_daily' THEN
        SELECT EXISTS(
            SELECT 1 FROM facts.fact_flu_hospitalizations_daily
            WHERE date_id = p_date_id
              AND location_id = p_location_id
              AND disease_id = p_disease_id
              AND source_id = p_source_id
        ), updated_timestamp INTO v_exists, v_current_timestamp
        FROM facts.fact_flu_hospitalizations_daily
        WHERE date_id = p_date_id
          AND location_id = p_location_id
          AND disease_id = p_disease_id
          AND source_id = p_source_id
        LIMIT 1;
    ELSIF p_table_name = 'fact_search_interest_daily' THEN
        -- Search interest table doesn't have disease_id
        SELECT EXISTS(
            SELECT 1 FROM facts.fact_search_interest_daily
            WHERE date_id = p_date_id
              AND location_id = p_location_id
              AND source_id = p_source_id
        ), updated_timestamp INTO v_exists, v_current_timestamp
        FROM facts.fact_search_interest_daily
        WHERE date_id = p_date_id
          AND location_id = p_location_id
          AND source_id = p_source_id
        LIMIT 1;
    END IF;
    
    -- If record exists and staging data is newer, it's late-arriving
    IF v_exists AND v_current_timestamp IS NOT NULL THEN
        RETURN p_staging_load_timestamp > v_current_timestamp;
    END IF;
    
    -- If record doesn't exist, it's new data (not late-arriving)
    RETURN FALSE;
END;
$$;
