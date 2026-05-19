-- Transform Google Trends Staging Data to Fact Tables
-- This script transforms staging.google_trends_raw into facts.fact_search_interest_daily
-- Aligns dates and locations with CDC/HHS data

-- ============================================================================
-- Main Transformation: Google Trends to Daily Search Interest Fact Table
-- ============================================================================

CREATE OR REPLACE FUNCTION transform.load_google_trends_to_facts(
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
    v_source_id INTEGER;
    v_exists BOOLEAN;
BEGIN
    -- Get default source ID for Google Trends
    SELECT source_id INTO v_source_id
    FROM dimensions.dim_source
    WHERE source_code = 'google_trends'
    LIMIT 1;
    
    -- If source doesn't exist, create it
    IF v_source_id IS NULL THEN
        INSERT INTO dimensions.dim_source (
            source_code,
            source_name,
            source_type,
            source_category, organization
        )
        VALUES (
            'google_trends',
            'Google Trends',
            'api',
            'research',
            'Google'
        )
        RETURNING source_id INTO v_source_id;
    END IF;
    
    -- Process staging data
    FOR v_row IN
        SELECT 
            stg.id,
            stg.state_abbreviation,
            stg.search_date,
            stg.search_interest,
            stg.search_terms,
            stg.epiweek,
            stg.load_timestamp
        FROM staging.google_trends_raw stg
        WHERE stg.search_date IS NOT NULL
          AND stg.state_abbreviation IS NOT NULL
          AND (p_start_date IS NULL OR stg.search_date >= p_start_date)
          AND (p_end_date IS NULL OR stg.search_date <= p_end_date)
        ORDER BY stg.load_timestamp DESC
    LOOP
        BEGIN
            v_processed := v_processed + 1;
            
            -- Standardize location
            v_location_id := transform.standardize_location(
                p_state_code := v_row.state_abbreviation,
                p_location_type := 'state'
            );
            
            -- Get date_id
            v_date_id := transform.get_date_id(
                p_date := v_row.search_date
            );
            
            -- Skip if dimension lookups failed
            IF v_date_id IS NULL OR v_location_id IS NULL OR v_source_id IS NULL THEN
                v_skipped := v_skipped + 1;
                CONTINUE;
            END IF;
            
            -- Check if record exists
            SELECT EXISTS(
                SELECT 1 FROM facts.fact_search_interest_daily
                WHERE date_id = v_date_id
                  AND location_id = v_location_id
                  AND source_id = v_source_id
            ) INTO v_exists;
            
            -- Handle late-arriving data (disease_id is NULL for search interest)
            IF v_exists THEN
                IF transform.is_late_arriving_data(
                    v_date_id, v_location_id, 0, v_source_id,  -- Use 0 as placeholder for disease_id
                    v_row.load_timestamp, 'fact_search_interest_daily'
                ) OR NOT p_dry_run THEN
                    v_updated := v_updated + 1;
                ELSE
                    v_skipped := v_skipped + 1;
                    CONTINUE;
                END IF;
            ELSE
                v_inserted := v_inserted + 1;
            END IF;
            
            -- Perform upsert
            IF NOT p_dry_run THEN
                INSERT INTO facts.fact_search_interest_daily (
                    date_id,
                    location_id,
                    source_id,
                    search_interest,
                    search_terms,
                    updated_timestamp
                ) VALUES (
                    v_date_id,
                    v_location_id,
                    v_source_id,
                    COALESCE(v_row.search_interest, 0),
                    v_row.search_terms,
                    CURRENT_TIMESTAMP
                )
                ON CONFLICT (date_id, location_id, source_id)
                DO UPDATE SET
                    search_interest = EXCLUDED.search_interest,
                    search_terms = EXCLUDED.search_terms,
                    updated_timestamp = CURRENT_TIMESTAMP;
            END IF;
            
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
            RAISE NOTICE 'Error processing Google Trends row %: %', v_row.id, SQLERRM;
        END;
    END LOOP;
    
    RETURN QUERY SELECT v_processed, v_inserted, v_updated, v_skipped, v_errors;
END;
$$;

-- Quick load function
CREATE OR REPLACE FUNCTION transform.load_google_trends_to_facts()
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
    SELECT * FROM transform.load_google_trends_to_facts(
        p_start_date := NULL,
        p_end_date := NULL,
        p_dry_run := FALSE
    );
END;
$$;
