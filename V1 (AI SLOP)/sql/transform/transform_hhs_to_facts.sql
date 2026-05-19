-- Transform HHS Hospital Utilization Staging Data to Fact Tables
-- This script transforms staging.hhs_hospital_utilization_raw into facts.fact_flu_hospitalizations_daily
-- Handles location standardization, late-arriving data, and schema changes

-- ============================================================================
-- Main Transformation: HHS Hospital Data to Daily Hospitalizations Fact Table
-- ============================================================================

CREATE OR REPLACE FUNCTION transform.load_hhs_to_facts(
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
    v_bed_util_rate DECIMAL;
    v_icu_util_rate DECIMAL;
    v_sql TEXT;
BEGIN
    -- Get default disease and source IDs
    -- Note: HHS data may contain COVID-19 data, but we'll map to flu for now
    -- Adjust disease_id based on your data
    SELECT disease_id INTO v_disease_id
    FROM dimensions.dim_disease
    WHERE disease_code = 'FLU'  -- or 'COVID19' depending on your data
    LIMIT 1;
    
    SELECT source_id INTO v_source_id
    FROM dimensions.dim_source
    WHERE source_code = 'hhs_hosp'
    LIMIT 1;
    
    -- Process staging data with dynamic column handling for schema changes
    FOR v_row IN
        SELECT 
            stg.id,
            stg.collection_week,
            stg.state_fips,
            stg.state,
            stg.load_timestamp,
            -- Handle schema changes: dynamically check for columns
            COALESCE(
                (SELECT column_value FROM (
                    SELECT 
                        CASE column_name
                            WHEN 'total_adult_patients_hospitalized_confirmed_and_suspected_covid' 
                            THEN (stg::jsonb->>'total_adult_patients_hospitalized_confirmed_and_suspected_covid')::INTEGER
                            ELSE NULL
                        END as column_value
                    FROM information_schema.columns
                    WHERE table_schema = 'staging' 
                    AND table_name = 'hhs_hospital_utilization_raw'
                    AND column_name = 'total_adult_patients_hospitalized_confirmed_and_suspected_covid'
                ) sub LIMIT 1),
                stg.total_adult_patients_hospitalized_confirmed_and_suspected_covid
            ) as total_admissions,
            COALESCE(stg.total_adult_patients_hospitalized_confirmed_covid, 0) as confirmed_admissions,
            COALESCE(stg.staffed_icu_adult_patients_confirmed_and_suspected_covid, 0) as icu_patients,
            COALESCE(stg.total_staffed_adult_icu_beds, 0) as total_icu_beds,
            COALESCE(stg.total_staffed_adult_icu_beds_occupied, 0) as occupied_icu_beds,
            COALESCE(stg.inpatient_beds, 0) as total_beds,
            COALESCE(stg.inpatient_beds_occupied, 0) as occupied_beds
        FROM staging.hhs_hospital_utilization_raw stg
        WHERE stg.collection_week IS NOT NULL
          AND (p_start_date IS NULL OR stg.collection_week >= p_start_date)
          AND (p_end_date IS NULL OR stg.collection_week <= p_end_date)
        ORDER BY stg.load_timestamp DESC
    LOOP
        BEGIN
            v_processed := v_processed + 1;
            
            -- Standardize location using FIPS code
            v_location_id := transform.standardize_location(
                p_state_fips := v_row.state_fips,
                p_state_code := v_row.state,
                p_location_type := 'state'
            );
            
            -- Get date_id from collection_week
            v_date_id := transform.get_date_id(
                p_date := v_row.collection_week::DATE
            );
            
            -- Skip if dimension lookups failed
            IF v_date_id IS NULL OR v_location_id IS NULL 
               OR v_disease_id IS NULL OR v_source_id IS NULL THEN
                v_skipped := v_skipped + 1;
                CONTINUE;
            END IF;
            
            -- Calculate utilization rates
            IF v_row.total_beds > 0 THEN
                v_bed_util_rate := (v_row.occupied_beds::DECIMAL / v_row.total_beds) * 100;
            ELSE
                v_bed_util_rate := NULL;
            END IF;
            
            IF v_row.total_icu_beds > 0 THEN
                v_icu_util_rate := (v_row.occupied_icu_beds::DECIMAL / v_row.total_icu_beds) * 100;
            ELSE
                v_icu_util_rate := NULL;
            END IF;
            
            -- Check if record exists
            SELECT EXISTS(
                SELECT 1 FROM facts.fact_flu_hospitalizations_daily
                WHERE date_id = v_date_id
                  AND location_id = v_location_id
                  AND disease_id = v_disease_id
                  AND source_id = v_source_id
            ) INTO v_exists;
            
            -- Handle late-arriving data
            IF v_exists THEN
                IF transform.is_late_arriving_data(
                    v_date_id, v_location_id, v_disease_id, v_source_id,
                    v_row.load_timestamp, 'fact_flu_hospitalizations_daily'
                ) OR p_dry_run = FALSE THEN
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
                INSERT INTO facts.fact_flu_hospitalizations_daily (
                    date_id,
                    location_id,
                    disease_id,
                    source_id,
                    admissions,
                    adult_admissions,
                    confirmed_admissions,
                    suspected_admissions,
                    icu_patients,
                    icu_adult_patients,
                    icu_confirmed_patients,
                    total_beds,
                    occupied_beds,
                    available_beds,
                    bed_utilization_rate,
                    total_icu_beds,
                    occupied_icu_beds,
                    available_icu_beds,
                    icu_utilization_rate,
                    updated_timestamp
                ) VALUES (
                    v_date_id,
                    v_location_id,
                    v_disease_id,
                    v_source_id,
                    COALESCE(v_row.total_admissions, 0),
                    COALESCE(v_row.total_admissions, 0),
                    COALESCE(v_row.confirmed_admissions, 0),
                    COALESCE(v_row.total_admissions, 0) - COALESCE(v_row.confirmed_admissions, 0),
                    COALESCE(v_row.icu_patients, 0),
                    COALESCE(v_row.icu_patients, 0),
                    COALESCE(v_row.icu_patients, 0),
                    v_row.total_beds,
                    v_row.occupied_beds,
                    v_row.total_beds - v_row.occupied_beds,
                    v_bed_util_rate,
                    v_row.total_icu_beds,
                    v_row.occupied_icu_beds,
                    v_row.total_icu_beds - v_row.occupied_icu_beds,
                    v_icu_util_rate,
                    CURRENT_TIMESTAMP
                )
                ON CONFLICT (date_id, location_id, disease_id, source_id)
                DO UPDATE SET
                    admissions = EXCLUDED.admissions,
                    adult_admissions = EXCLUDED.adult_admissions,
                    confirmed_admissions = EXCLUDED.confirmed_admissions,
                    suspected_admissions = EXCLUDED.suspected_admissions,
                    icu_patients = EXCLUDED.icu_patients,
                    icu_adult_patients = EXCLUDED.icu_patients,
                    icu_confirmed_patients = EXCLUDED.icu_confirmed_patients,
                    total_beds = EXCLUDED.total_beds,
                    occupied_beds = EXCLUDED.occupied_beds,
                    available_beds = EXCLUDED.available_beds,
                    bed_utilization_rate = EXCLUDED.bed_utilization_rate,
                    total_icu_beds = EXCLUDED.total_icu_beds,
                    occupied_icu_beds = EXCLUDED.occupied_icu_beds,
                    available_icu_beds = EXCLUDED.available_icu_beds,
                    icu_utilization_rate = EXCLUDED.icu_utilization_rate,
                    updated_timestamp = CURRENT_TIMESTAMP;
            END IF;
            
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
            RAISE NOTICE 'Error processing HHS row %: %', v_row.id, SQLERRM;
        END;
    END LOOP;
    
    RETURN QUERY SELECT v_processed, v_inserted, v_updated, v_skipped, v_errors;
END;
$$;

-- Quick load function
CREATE OR REPLACE FUNCTION transform.load_hhs_to_facts()
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
    SELECT * FROM transform.load_hhs_to_facts(
        p_start_date := NULL,
        p_end_date := NULL,
        p_dry_run := FALSE
    );
END;
$$;
