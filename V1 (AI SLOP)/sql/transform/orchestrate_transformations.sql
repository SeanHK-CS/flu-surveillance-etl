-- Orchestration Script for All Transformations
-- This script coordinates the execution of all transformation steps
-- Run this script to perform the complete ETL transformation pipeline

-- ============================================================================
-- Main Orchestration Function
-- ============================================================================
-- Executes all transformation steps in the correct order:
-- 1. Transform CDC FluView staging to facts
-- 2. Transform HHS staging to facts
-- 3. Calculate rolling averages
-- 4. Calculate trend flags

CREATE OR REPLACE FUNCTION transform.run_all_transformations(
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_dry_run BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(
    step_name VARCHAR(100),
    rows_processed INTEGER,
    rows_inserted INTEGER,
    rows_updated INTEGER,
    rows_skipped INTEGER,
    errors INTEGER,
    execution_time INTERVAL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_result RECORD;
BEGIN
    -- Step 1: Transform CDC FluView data
    v_start_time := clock_timestamp();
    SELECT * INTO v_result
    FROM transform.load_cdc_fluview_to_facts(
        p_start_date := p_start_date,
        p_end_date := p_end_date,
        p_dry_run := p_dry_run
    );
    v_end_time := clock_timestamp();
    
    RETURN QUERY SELECT 
        'CDC FluView to Facts'::VARCHAR(100),
        v_result.rows_processed,
        v_result.rows_inserted,
        v_result.rows_updated,
        v_result.rows_skipped,
        v_result.errors,
        v_end_time - v_start_time;
    
    -- Step 2: Transform HHS data
    v_start_time := clock_timestamp();
    SELECT * INTO v_result
    FROM transform.load_hhs_to_facts(
        p_start_date := p_start_date,
        p_end_date := p_end_date,
        p_dry_run := p_dry_run
    );
    v_end_time := clock_timestamp();
    
    RETURN QUERY SELECT 
        'HHS to Facts'::VARCHAR(100),
        v_result.rows_processed,
        v_result.rows_inserted,
        v_result.rows_updated,
        v_result.rows_skipped,
        v_result.errors,
        v_end_time - v_start_time;
    
    -- Step 3: Calculate rolling averages for weekly cases
    IF NOT p_dry_run THEN
        v_start_time := clock_timestamp();
        SELECT * INTO v_result
        FROM transform.update_rolling_averages_weekly();
        v_end_time := clock_timestamp();
        
        RETURN QUERY SELECT 
            'Rolling Averages - Weekly Cases'::VARCHAR(100),
            v_result.rows_updated,
            0, 0, 0,
            v_result.errors,
            v_end_time - v_start_time;
        
        -- Step 4: Calculate rolling averages for daily hospitalizations
        v_start_time := clock_timestamp();
        SELECT * INTO v_result
        FROM transform.update_rolling_averages_daily();
        v_end_time := clock_timestamp();
        
        RETURN QUERY SELECT 
            'Rolling Averages - Daily Hospitalizations'::VARCHAR(100),
            v_result.rows_updated,
            0, 0, 0,
            v_result.errors,
            v_end_time - v_start_time;
        
        -- Step 5: Update trend flags for weekly cases
        v_start_time := clock_timestamp();
        SELECT * INTO v_result
        FROM transform.update_trend_flags_weekly();
        v_end_time := clock_timestamp();
        
        RETURN QUERY SELECT 
            'Trend Flags - Weekly Cases'::VARCHAR(100),
            v_result.rows_updated,
            0, 0, 0,
            v_result.errors,
            v_end_time - v_start_time;
        
        -- Step 6: Update trend flags for daily hospitalizations
        v_start_time := clock_timestamp();
        SELECT * INTO v_result
        FROM transform.update_trend_flags_daily();
        v_end_time := clock_timestamp();
        
        RETURN QUERY SELECT 
            'Trend Flags - Daily Hospitalizations'::VARCHAR(100),
            v_result.rows_updated,
            0, 0, 0,
            v_result.errors,
            v_end_time - v_start_time;
    END IF;
END;
$$;

-- ============================================================================
-- Quick Run Function (No Parameters)
-- ============================================================================

CREATE OR REPLACE FUNCTION transform.run_all_transformations()
RETURNS TABLE(
    step_name VARCHAR(100),
    rows_processed INTEGER,
    rows_inserted INTEGER,
    rows_updated INTEGER,
    rows_skipped INTEGER,
    errors INTEGER,
    execution_time INTERVAL
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM transform.run_all_transformations(
        p_start_date := NULL,
        p_end_date := NULL,
        p_dry_run := FALSE
    );
END;
$$;

-- ============================================================================
-- Example Usage
-- ============================================================================

-- Run all transformations
-- SELECT * FROM transform.run_all_transformations();

-- Run with date filter
-- SELECT * FROM transform.run_all_transformations(
--     p_start_date := '2024-01-01',
--     p_end_date := '2024-01-31'
-- );

-- Dry run (test without making changes)
-- SELECT * FROM transform.run_all_transformations(p_dry_run := TRUE);
