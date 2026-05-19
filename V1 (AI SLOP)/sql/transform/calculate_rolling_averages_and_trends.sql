-- Calculate Rolling Averages and Trend Indicators
-- This script computes 7-day rolling averages and trend flags for fact tables
-- Updates existing fact table records with calculated metrics

-- ============================================================================
-- Function: Calculate and Update Rolling Averages for Weekly Cases
-- ============================================================================

CREATE OR REPLACE FUNCTION transform.update_rolling_averages_weekly(
    p_start_date_id INTEGER DEFAULT NULL,
    p_end_date_id INTEGER DEFAULT NULL
)
RETURNS TABLE(
    rows_updated INTEGER,
    errors INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_updated INTEGER := 0;
    v_errors INTEGER := 0;
    v_row RECORD;
    v_7day_avg DECIMAL;
    v_30day_avg DECIMAL;
    v_previous_7day_avg DECIMAL;
    v_trend VARCHAR(20);
BEGIN
    -- Update rolling averages for weekly cases
    FOR v_row IN
        SELECT 
            f.fact_id,
            f.date_id,
            f.location_id,
            f.disease_id,
            f.source_id,
            f.positive_cases,
            d.full_date
        FROM facts.fact_flu_cases_weekly f
        JOIN dimensions.dim_date d ON f.date_id = d.date_id
        WHERE (p_start_date_id IS NULL OR f.date_id >= p_start_date_id)
          AND (p_end_date_id IS NULL OR f.date_id <= p_end_date_id)
        ORDER BY f.location_id, f.disease_id, f.source_id, d.full_date
    LOOP
        BEGIN
            -- Calculate 7-day rolling average
            SELECT AVG(f2.positive_cases)::DECIMAL
            INTO v_7day_avg
            FROM facts.fact_flu_cases_weekly f2
            JOIN dimensions.dim_date d2 ON f2.date_id = d2.date_id
            WHERE f2.location_id = v_row.location_id
              AND f2.disease_id = v_row.disease_id
              AND f2.source_id = v_row.source_id
              AND d2.full_date <= v_row.full_date
              AND d2.full_date > v_row.full_date - INTERVAL '7 days';
            
            -- Calculate 30-day rolling average
            SELECT AVG(f2.positive_cases)::DECIMAL
            INTO v_30day_avg
            FROM facts.fact_flu_cases_weekly f2
            JOIN dimensions.dim_date d2 ON f2.date_id = d2.date_id
            WHERE f2.location_id = v_row.location_id
              AND f2.disease_id = v_row.disease_id
              AND f2.source_id = v_row.source_id
              AND d2.full_date <= v_row.full_date
              AND d2.full_date > v_row.full_date - INTERVAL '30 days';
            
            -- Get previous period's 7-day average (2 weeks ago) for trend calculation
            SELECT AVG(f2.positive_cases)::DECIMAL
            INTO v_previous_7day_avg
            FROM facts.fact_flu_cases_weekly f2
            JOIN dimensions.dim_date d2 ON f2.date_id = d2.date_id
            WHERE f2.location_id = v_row.location_id
              AND f2.disease_id = v_row.disease_id
              AND f2.source_id = v_row.source_id
              AND d2.full_date <= v_row.full_date - INTERVAL '14 days'
              AND d2.full_date > v_row.full_date - INTERVAL '21 days';
            
            -- Calculate trend based on 2-week change
            v_trend := transform.calculate_trend(
                p_current_value := v_7day_avg,
                p_previous_value := v_previous_7day_avg,
                p_change_threshold := 0.10  -- 10% threshold
            );
            
            -- Update the fact table
            UPDATE facts.fact_flu_cases_weekly
            SET 
                cases_7day_avg = v_7day_avg,
                cases_30day_avg = v_30day_avg,
                updated_timestamp = CURRENT_TIMESTAMP
            WHERE fact_id = v_row.fact_id;
            
            v_updated := v_updated + 1;
            
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
            RAISE NOTICE 'Error updating rolling averages for fact_id %: %', v_row.fact_id, SQLERRM;
        END;
    END LOOP;
    
    RETURN QUERY SELECT v_updated, v_errors;
END;
$$;

-- ============================================================================
-- Function: Calculate and Update Rolling Averages for Daily Hospitalizations
-- ============================================================================

CREATE OR REPLACE FUNCTION transform.update_rolling_averages_daily(
    p_start_date_id INTEGER DEFAULT NULL,
    p_end_date_id INTEGER DEFAULT NULL
)
RETURNS TABLE(
    rows_updated INTEGER,
    errors INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_updated INTEGER := 0;
    v_errors INTEGER := 0;
    v_row RECORD;
    v_7day_avg DECIMAL;
    v_30day_avg DECIMAL;
    v_previous_7day_avg DECIMAL;
    v_trend VARCHAR(20);
BEGIN
    -- Update rolling averages for daily hospitalizations
    FOR v_row IN
        SELECT 
            f.fact_id,
            f.date_id,
            f.location_id,
            f.disease_id,
            f.source_id,
            f.admissions,
            d.full_date
        FROM facts.fact_flu_hospitalizations_daily f
        JOIN dimensions.dim_date d ON f.date_id = d.date_id
        WHERE (p_start_date_id IS NULL OR f.date_id >= p_start_date_id)
          AND (p_end_date_id IS NULL OR f.date_id <= p_end_date_id)
        ORDER BY f.location_id, f.disease_id, f.source_id, d.full_date
    LOOP
        BEGIN
            -- Calculate 7-day rolling average for admissions
            SELECT AVG(f2.admissions)::DECIMAL
            INTO v_7day_avg
            FROM facts.fact_flu_hospitalizations_daily f2
            JOIN dimensions.dim_date d2 ON f2.date_id = d2.date_id
            WHERE f2.location_id = v_row.location_id
              AND f2.disease_id = v_row.disease_id
              AND f2.source_id = v_row.source_id
              AND d2.full_date <= v_row.full_date
              AND d2.full_date > v_row.full_date - INTERVAL '7 days';
            
            -- Calculate 30-day rolling average
            SELECT AVG(f2.admissions)::DECIMAL
            INTO v_30day_avg
            FROM facts.fact_flu_hospitalizations_daily f2
            JOIN dimensions.dim_date d2 ON f2.date_id = d2.date_id
            WHERE f2.location_id = v_row.location_id
              AND f2.disease_id = v_row.disease_id
              AND f2.source_id = v_row.source_id
              AND d2.full_date <= v_row.full_date
              AND d2.full_date > v_row.full_date - INTERVAL '30 days';
            
            -- Get previous period's 7-day average (2 weeks ago) for trend
            SELECT AVG(f2.admissions)::DECIMAL
            INTO v_previous_7day_avg
            FROM facts.fact_flu_hospitalizations_daily f2
            JOIN dimensions.dim_date d2 ON f2.date_id = d2.date_id
            WHERE f2.location_id = v_row.location_id
              AND f2.disease_id = v_row.disease_id
              AND f2.source_id = v_row.source_id
              AND d2.full_date <= v_row.full_date - INTERVAL '14 days'
              AND d2.full_date > v_row.full_date - INTERVAL '21 days';
            
            -- Calculate trend
            v_trend := transform.calculate_trend(
                p_current_value := v_7day_avg,
                p_previous_value := v_previous_7day_avg,
                p_change_threshold := 0.10
            );
            
            -- Update the fact table
            UPDATE facts.fact_flu_hospitalizations_daily
            SET 
                admissions_7day_avg = v_7day_avg,
                admissions_30day_avg = v_30day_avg,
                updated_timestamp = CURRENT_TIMESTAMP
            WHERE fact_id = v_row.fact_id;
            
            v_updated := v_updated + 1;
            
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
            RAISE NOTICE 'Error updating rolling averages for fact_id %: %', v_row.fact_id, SQLERRM;
        END;
    END LOOP;
    
    RETURN QUERY SELECT v_updated, v_errors;
END;
$$;

-- ============================================================================
-- Function: Add Trend Flags to Fact Tables
-- ============================================================================
-- Adds a trend_flag column and populates it based on 2-week change

-- First, add trend_flag column if it doesn't exist (for weekly cases)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'facts'
        AND table_name = 'fact_flu_cases_weekly'
        AND column_name = 'trend_flag'
    ) THEN
        ALTER TABLE facts.fact_flu_cases_weekly
        ADD COLUMN trend_flag VARCHAR(20);
    END IF;
END $$;

-- Add trend_flag column for daily hospitalizations
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'facts'
        AND table_name = 'fact_flu_hospitalizations_daily'
        AND column_name = 'trend_flag'
    ) THEN
        ALTER TABLE facts.fact_flu_hospitalizations_daily
        ADD COLUMN trend_flag VARCHAR(20);
    END IF;
END $$;

-- Function to update trend flags for weekly cases
CREATE OR REPLACE FUNCTION transform.update_trend_flags_weekly(
    p_start_date_id INTEGER DEFAULT NULL,
    p_end_date_id INTEGER DEFAULT NULL
)
RETURNS TABLE(
    rows_updated INTEGER,
    errors INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_updated INTEGER := 0;
    v_errors INTEGER := 0;
    v_row RECORD;
    v_current_avg DECIMAL;
    v_previous_avg DECIMAL;
    v_trend VARCHAR(20);
BEGIN
    FOR v_row IN
        SELECT 
            f.fact_id,
            f.date_id,
            f.location_id,
            f.disease_id,
            f.source_id,
            f.cases_7day_avg,
            d.full_date
        FROM facts.fact_flu_cases_weekly f
        JOIN dimensions.dim_date d ON f.date_id = d.date_id
        WHERE (p_start_date_id IS NULL OR f.date_id >= p_start_date_id)
          AND (p_end_date_id IS NULL OR f.date_id <= p_end_date_id)
    LOOP
        BEGIN
            v_current_avg := v_row.cases_7day_avg;
            
            -- Get 7-day average from 2 weeks ago
            SELECT AVG(f2.cases_7day_avg)::DECIMAL
            INTO v_previous_avg
            FROM facts.fact_flu_cases_weekly f2
            JOIN dimensions.dim_date d2 ON f2.date_id = d2.date_id
            WHERE f2.location_id = v_row.location_id
              AND f2.disease_id = v_row.disease_id
              AND f2.source_id = v_row.source_id
              AND d2.full_date <= v_row.full_date - INTERVAL '14 days'
              AND d2.full_date > v_row.full_date - INTERVAL '21 days';
            
            -- Calculate trend
            v_trend := transform.calculate_trend(
                p_current_value := v_current_avg,
                p_previous_value := v_previous_avg,
                p_change_threshold := 0.10
            );
            
            -- Update trend flag
            UPDATE facts.fact_flu_cases_weekly
            SET trend_flag = v_trend
            WHERE fact_id = v_row.fact_id;
            
            v_updated := v_updated + 1;
            
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
        END;
    END LOOP;
    
    RETURN QUERY SELECT v_updated, v_errors;
END;
$$;

-- Function to update trend flags for daily hospitalizations
CREATE OR REPLACE FUNCTION transform.update_trend_flags_daily(
    p_start_date_id INTEGER DEFAULT NULL,
    p_end_date_id INTEGER DEFAULT NULL
)
RETURNS TABLE(
    rows_updated INTEGER,
    errors INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_updated INTEGER := 0;
    v_errors INTEGER := 0;
    v_row RECORD;
    v_current_avg DECIMAL;
    v_previous_avg DECIMAL;
    v_trend VARCHAR(20);
BEGIN
    FOR v_row IN
        SELECT 
            f.fact_id,
            f.date_id,
            f.location_id,
            f.disease_id,
            f.source_id,
            f.admissions_7day_avg,
            d.full_date
        FROM facts.fact_flu_hospitalizations_daily f
        JOIN dimensions.dim_date d ON f.date_id = d.date_id
        WHERE (p_start_date_id IS NULL OR f.date_id >= p_start_date_id)
          AND (p_end_date_id IS NULL OR f.date_id <= p_end_date_id)
    LOOP
        BEGIN
            v_current_avg := v_row.admissions_7day_avg;
            
            -- Get 7-day average from 2 weeks ago
            SELECT AVG(f2.admissions_7day_avg)::DECIMAL
            INTO v_previous_avg
            FROM facts.fact_flu_hospitalizations_daily f2
            JOIN dimensions.dim_date d2 ON f2.date_id = d2.date_id
            WHERE f2.location_id = v_row.location_id
              AND f2.disease_id = v_row.disease_id
              AND f2.source_id = v_row.source_id
              AND d2.full_date <= v_row.full_date - INTERVAL '14 days'
              AND d2.full_date > v_row.full_date - INTERVAL '21 days';
            
            -- Calculate trend
            v_trend := transform.calculate_trend(
                p_current_value := v_current_avg,
                p_previous_value := v_previous_avg,
                p_change_threshold := 0.10
            );
            
            -- Update trend flag
            UPDATE facts.fact_flu_hospitalizations_daily
            SET trend_flag = v_trend
            WHERE fact_id = v_row.fact_id;
            
            v_updated := v_updated + 1;
            
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
        END;
    END LOOP;
    
    RETURN QUERY SELECT v_updated, v_errors;
END;
$$;
