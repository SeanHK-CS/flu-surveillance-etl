-- Transform CDC FluView Staging Data to Fact Tables
-- This script transforms staging.fluview_raw into facts.fact_flu_cases_weekly
-- Handles location standardization, late-arriving data, and schema changes

-- ============================================================================
-- Main Transformation: CDC FluView to Weekly Cases Fact Table
-- ============================================================================
-- This transformation:
-- 1. Standardizes location codes using dimension lookups
-- 2. Handles late-arriving data by updating existing records
-- 3. Supports schema changes by handling missing columns gracefully
-- 4. Performs incremental upsert to prevent duplicates

CREATE OR REPLACE FUNCTION transform.load_cdc_fluview_to_facts(
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_dry_run BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(
    rows_processed INTEGER,
    rows_inserted INTEGER,
    rows_updated INTEGER,
    rows_skipped INTEGER,
    errors INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_processed INTEGER := 0;
    v_inserted INTEGER := 0;
    v_updated INTEGER := 0;
    v_skipped INTEGER := 0;
    v_errors INTEGER := 0;
    v_row RECORD;
    v_date_id INTEGER;
    v_location_id INTEGER;
    v_disease_id INTEGER;
    v_source_id INTEGER;
    v_exists BOOLEAN;
BEGIN
    -- Get default disease and source IDs
    SELECT disease_id INTO v_disease_id
    FROM dimensions.dim_disease
    WHERE disease_code = 'FLU'
    LIMIT 1;
    
    SELECT source_id INTO v_source_id
    FROM dimensions.dim_source
    WHERE source_code = 'cdc_fluview'
    LIMIT 1;
    
    -- Process staging data
    FOR v_row IN
        SELECT 
            stg.id,
            stg.year,
            stg.week,
            stg.region,
            stg.state,
            stg.total_specimens,
            stg.positive_specimens,
            stg.percent_positive,
            stg.load_timestamp,
            -- Handle schema changes: check for additional columns if they exist
            CASE WHEN EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_schema = 'staging' 
                AND table_name = 'fluview_raw' 
                AND column_name = 'hospitalizations'
            ) THEN stg.hospitalizations ELSE NULL END as hospitalizations,
            CASE WHEN EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_schema = 'staging' 
                AND table_name = 'fluview_raw' 
                AND column_name = 'deaths'
            ) THEN stg.deaths ELSE NULL END as deaths
        FROM staging.fluview_raw stg
        WHERE (p_start_date IS NULL OR stg.load_timestamp >= p_start_date)
          AND (p_end_date IS NULL OR stg.load_timestamp <= p_end_date)
        ORDER BY stg.load_timestamp DESC  -- Process newest first for late-arriving data
    LOOP
        BEGIN
            v_processed := v_processed + 1;
            
            -- Standardize location
            v_location_id := transform.standardize_location(
                p_state_code := v_row.state,
                p_region_code := v_row.region,
                p_location_type := 'state'
            );
            
            -- Get date_id
            v_date_id := transform.get_date_id(
                p_year := v_row.year,
                p_week := v_row.week
            );
            
            -- Skip if dimension lookups failed
            IF v_date_id IS NULL OR v_location_id IS NULL 
               OR v_disease_id IS NULL OR v_source_id IS NULL THEN
                v_skipped := v_skipped + 1;
                CONTINUE;
            END IF;
            
            -- Check if record exists
            SELECT EXISTS(
                SELECT 1 FROM facts.fact_flu_cases_weekly
                WHERE date_id = v_date_id
                  AND location_id = v_location_id
                  AND disease_id = v_disease_id
                  AND source_id = v_source_id
            ) INTO v_exists;
            
            -- Handle late-arriving data: update if staging data is newer
            IF v_exists THEN
                IF transform.is_late_arriving_data(
                    v_date_id, v_location_id, v_disease_id, v_source_id,
                    v_row.load_timestamp, 'fact_flu_cases_weekly'
                ) OR p_dry_run = FALSE THEN
                    v_updated := v_updated + 1;
                ELSE
                    v_skipped := v_skipped + 1;
                    CONTINUE;
                END IF;
            ELSE
                v_inserted := v_inserted + 1;
            END IF;
            
            -- Perform upsert (skip if dry run)
            IF NOT p_dry_run THEN
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
                ) VALUES (
                    v_date_id,
                    v_location_id,
                    v_disease_id,
                    v_source_id,
                    COALESCE(v_row.total_specimens, 0),
                    COALESCE(v_row.positive_specimens, 0),
                    COALESCE(v_row.total_specimens, 0),
                    v_row.percent_positive,
                    COALESCE(v_row.hospitalizations, 0),
                    COALESCE(v_row.deaths, 0),
                    CURRENT_TIMESTAMP
                )
                ON CONFLICT (date_id, location_id, disease_id, source_id)
                DO UPDATE SET
                    cases = EXCLUDED.cases,
                    positive_cases = EXCLUDED.positive_cases,
                    total_tests = EXCLUDED.total_tests,
                    percent_positive = EXCLUDED.percent_positive,
                    hospitalizations = EXCLUDED.hospitalizations,
                    deaths = EXCLUDED.deaths,
                    updated_timestamp = CURRENT_TIMESTAMP;
            END IF;
            
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
            RAISE NOTICE 'Error processing CDC FluView row %: %', v_row.id, SQLERRM;
        END;
    END LOOP;
    
    RETURN QUERY SELECT v_processed, v_inserted, v_updated, v_skipped, v_errors;
END;
$$;

-- ============================================================================
-- Quick Load Function (No Parameters)
-- ============================================================================

CREATE OR REPLACE FUNCTION transform.load_cdc_fluview_to_facts()
RETURNS TABLE(
    rows_processed INTEGER,
    rows_inserted INTEGER,
    rows_updated INTEGER,
    rows_skipped INTEGER,
    errors INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM transform.load_cdc_fluview_to_facts(
        p_start_date := NULL,
        p_end_date := NULL,
        p_dry_run := FALSE
    );
END;
$$;
