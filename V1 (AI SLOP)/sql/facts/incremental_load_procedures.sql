-- Incremental Load Procedures for Fact Tables
-- These procedures handle upsert logic to prevent duplicate data
-- Uses PostgreSQL's ON CONFLICT clause for idempotent loading

-- ============================================================================
-- Function: Load Weekly Flu Cases (Incremental/Upsert)
-- ============================================================================
-- This function performs an incremental load (upsert) for weekly flu cases
-- Updates existing records or inserts new ones based on unique constraint

CREATE OR REPLACE FUNCTION facts.load_flu_cases_weekly(
    p_date_id INTEGER,
    p_location_id INTEGER,
    p_disease_id INTEGER,
    p_source_id INTEGER,
    p_cases INTEGER DEFAULT 0,
    p_positive_cases INTEGER DEFAULT 0,
    p_total_tests INTEGER DEFAULT 0,
    p_percent_positive DECIMAL DEFAULT NULL,
    p_hospitalizations INTEGER DEFAULT 0,
    p_deaths INTEGER DEFAULT 0,
    p_cases_7day_avg DECIMAL DEFAULT NULL,
    p_cases_30day_avg DECIMAL DEFAULT NULL,
    p_hospitalization_rate DECIMAL DEFAULT NULL,
    p_death_rate DECIMAL DEFAULT NULL,
    p_data_quality_score DECIMAL DEFAULT NULL,
    p_is_estimated BOOLEAN DEFAULT FALSE,
    p_notes TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_fact_id INTEGER;
BEGIN
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
        cases_7day_avg,
        cases_30day_avg,
        hospitalization_rate,
        death_rate,
        data_quality_score,
        is_estimated,
        notes,
        updated_timestamp
    ) VALUES (
        p_date_id,
        p_location_id,
        p_disease_id,
        p_source_id,
        p_cases,
        p_positive_cases,
        p_total_tests,
        p_percent_positive,
        p_hospitalizations,
        p_deaths,
        p_cases_7day_avg,
        p_cases_30day_avg,
        p_hospitalization_rate,
        p_death_rate,
        p_data_quality_score,
        p_is_estimated,
        p_notes,
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
        cases_7day_avg = EXCLUDED.cases_7day_avg,
        cases_30day_avg = EXCLUDED.cases_30day_avg,
        hospitalization_rate = EXCLUDED.hospitalization_rate,
        death_rate = EXCLUDED.death_rate,
        data_quality_score = EXCLUDED.data_quality_score,
        is_estimated = EXCLUDED.is_estimated,
        notes = EXCLUDED.notes,
        updated_timestamp = CURRENT_TIMESTAMP
    RETURNING fact_id INTO v_fact_id;
    
    RETURN v_fact_id;
END;
$$;

-- ============================================================================
-- Function: Load Daily Hospitalizations (Incremental/Upsert)
-- ============================================================================
-- This function performs an incremental load (upsert) for daily hospital data
-- Updates existing records or inserts new ones based on unique constraint

CREATE OR REPLACE FUNCTION facts.load_flu_hospitalizations_daily(
    p_date_id INTEGER,
    p_location_id INTEGER,
    p_disease_id INTEGER,
    p_source_id INTEGER,
    p_admissions INTEGER DEFAULT 0,
    p_adult_admissions INTEGER DEFAULT 0,
    p_pediatric_admissions INTEGER DEFAULT 0,
    p_confirmed_admissions INTEGER DEFAULT 0,
    p_suspected_admissions INTEGER DEFAULT 0,
    p_icu_patients INTEGER DEFAULT 0,
    p_icu_adult_patients INTEGER DEFAULT 0,
    p_icu_pediatric_patients INTEGER DEFAULT 0,
    p_icu_confirmed_patients INTEGER DEFAULT 0,
    p_icu_suspected_patients INTEGER DEFAULT 0,
    p_total_beds INTEGER DEFAULT 0,
    p_occupied_beds INTEGER DEFAULT 0,
    p_available_beds INTEGER DEFAULT 0,
    p_bed_utilization_rate DECIMAL DEFAULT NULL,
    p_total_icu_beds INTEGER DEFAULT 0,
    p_occupied_icu_beds INTEGER DEFAULT 0,
    p_available_icu_beds INTEGER DEFAULT 0,
    p_icu_utilization_rate DECIMAL DEFAULT NULL,
    p_admissions_7day_avg DECIMAL DEFAULT NULL,
    p_admissions_30day_avg DECIMAL DEFAULT NULL,
    p_icu_usage_7day_avg DECIMAL DEFAULT NULL,
    p_data_quality_score DECIMAL DEFAULT NULL,
    p_is_estimated BOOLEAN DEFAULT FALSE,
    p_has_missing_data BOOLEAN DEFAULT FALSE,
    p_notes TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_fact_id INTEGER;
BEGIN
    INSERT INTO facts.fact_flu_hospitalizations_daily (
        date_id,
        location_id,
        disease_id,
        source_id,
        admissions,
        adult_admissions,
        pediatric_admissions,
        confirmed_admissions,
        suspected_admissions,
        icu_patients,
        icu_adult_patients,
        icu_pediatric_patients,
        icu_confirmed_patients,
        icu_suspected_patients,
        total_beds,
        occupied_beds,
        available_beds,
        bed_utilization_rate,
        total_icu_beds,
        occupied_icu_beds,
        available_icu_beds,
        icu_utilization_rate,
        admissions_7day_avg,
        admissions_30day_avg,
        icu_usage_7day_avg,
        data_quality_score,
        is_estimated,
        has_missing_data,
        notes,
        updated_timestamp
    ) VALUES (
        p_date_id,
        p_location_id,
        p_disease_id,
        p_source_id,
        p_admissions,
        p_adult_admissions,
        p_pediatric_admissions,
        p_confirmed_admissions,
        p_suspected_admissions,
        p_icu_patients,
        p_icu_adult_patients,
        p_icu_pediatric_patients,
        p_icu_confirmed_patients,
        p_icu_suspected_patients,
        p_total_beds,
        p_occupied_beds,
        p_available_beds,
        p_bed_utilization_rate,
        p_total_icu_beds,
        p_occupied_icu_beds,
        p_available_icu_beds,
        p_icu_utilization_rate,
        p_admissions_7day_avg,
        p_admissions_30day_avg,
        p_icu_usage_7day_avg,
        p_data_quality_score,
        p_is_estimated,
        p_has_missing_data,
        p_notes,
        CURRENT_TIMESTAMP
    )
    ON CONFLICT (date_id, location_id, disease_id, source_id)
    DO UPDATE SET
        admissions = EXCLUDED.admissions,
        adult_admissions = EXCLUDED.adult_admissions,
        pediatric_admissions = EXCLUDED.pediatric_admissions,
        confirmed_admissions = EXCLUDED.confirmed_admissions,
        suspected_admissions = EXCLUDED.suspected_admissions,
        icu_patients = EXCLUDED.icu_patients,
        icu_adult_patients = EXCLUDED.icu_adult_patients,
        icu_pediatric_patients = EXCLUDED.icu_pediatric_patients,
        icu_confirmed_patients = EXCLUDED.icu_confirmed_patients,
        icu_suspected_patients = EXCLUDED.icu_suspected_patients,
        total_beds = EXCLUDED.total_beds,
        occupied_beds = EXCLUDED.occupied_beds,
        available_beds = EXCLUDED.available_beds,
        bed_utilization_rate = EXCLUDED.bed_utilization_rate,
        total_icu_beds = EXCLUDED.total_icu_beds,
        occupied_icu_beds = EXCLUDED.occupied_icu_beds,
        available_icu_beds = EXCLUDED.available_icu_beds,
        icu_utilization_rate = EXCLUDED.icu_utilization_rate,
        admissions_7day_avg = EXCLUDED.admissions_7day_avg,
        admissions_30day_avg = EXCLUDED.admissions_30day_avg,
        icu_usage_7day_avg = EXCLUDED.icu_usage_7day_avg,
        data_quality_score = EXCLUDED.data_quality_score,
        is_estimated = EXCLUDED.is_estimated,
        has_missing_data = EXCLUDED.has_missing_data,
        notes = EXCLUDED.notes,
        updated_timestamp = CURRENT_TIMESTAMP
    RETURNING fact_id INTO v_fact_id;
    
    RETURN v_fact_id;
END;
$$;

-- ============================================================================
-- Batch Load Function: Load Weekly Flu Cases from Staging
-- ============================================================================
-- This function loads data from staging tables into fact tables
-- Handles dimension lookups and incremental loading

CREATE OR REPLACE FUNCTION facts.load_flu_cases_weekly_from_staging(
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS TABLE(
    rows_inserted INTEGER,
    rows_updated INTEGER,
    errors INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_inserted INTEGER := 0;
    v_updated INTEGER := 0;
    v_errors INTEGER := 0;
    v_date_id INTEGER;
    v_location_id INTEGER;
    v_disease_id INTEGER;
    v_source_id INTEGER;
    v_row RECORD;
BEGIN
    -- Loop through staging data
    FOR v_row IN
        SELECT DISTINCT
            fv.year,
            fv.week,
            fv.state,
            fv.region,
            fv.total_specimens,
            fv.positive_specimens,
            fv.percent_positive,
            fv.data_source
        FROM staging.fluview_raw fv
        WHERE (p_start_date IS NULL OR fv.load_timestamp >= p_start_date)
          AND (p_end_date IS NULL OR fv.load_timestamp <= p_end_date)
    LOOP
        BEGIN
            -- Get date_id (use week ending date)
            SELECT date_id INTO v_date_id
            FROM dimensions.dim_date
            WHERE year = v_row.year
              AND week_number = v_row.week
            LIMIT 1;
            
            -- Get location_id
            SELECT location_id INTO v_location_id
            FROM dimensions.dim_location
            WHERE (state_code = v_row.state OR location_code = v_row.state)
              AND location_type = 'state'
            LIMIT 1;
            
            -- Get disease_id (default to Influenza)
            SELECT disease_id INTO v_disease_id
            FROM dimensions.dim_disease
            WHERE disease_code = 'FLU'
            LIMIT 1;
            
            -- Get source_id
            SELECT source_id INTO v_source_id
            FROM dimensions.dim_source
            WHERE source_code = 'cdc_fluview'
            LIMIT 1;
            
            -- Only proceed if all dimension keys are found
            IF v_date_id IS NOT NULL AND v_location_id IS NOT NULL 
               AND v_disease_id IS NOT NULL AND v_source_id IS NOT NULL THEN
                
                -- Check if record exists
                IF EXISTS (
                    SELECT 1 FROM facts.fact_flu_cases_weekly
                    WHERE date_id = v_date_id
                      AND location_id = v_location_id
                      AND disease_id = v_disease_id
                      AND source_id = v_source_id
                ) THEN
                    v_updated := v_updated + 1;
                ELSE
                    v_inserted := v_inserted + 1;
                END IF;
                
                -- Perform upsert
                PERFORM facts.load_flu_cases_weekly(
                    v_date_id,
                    v_location_id,
                    v_disease_id,
                    v_source_id,
                    COALESCE(v_row.total_specimens, 0),
                    COALESCE(v_row.positive_specimens, 0),
                    COALESCE(v_row.total_specimens, 0),
                    v_row.percent_positive,
                    0,  -- hospitalizations (not in fluview_raw)
                    0,  -- deaths (not in fluview_raw)
                    NULL,  -- cases_7day_avg
                    NULL,  -- cases_30day_avg
                    NULL,  -- hospitalization_rate
                    NULL,  -- death_rate
                    NULL,  -- data_quality_score
                    FALSE,  -- is_estimated
                    NULL   -- notes
                );
            ELSE
                v_errors := v_errors + 1;
            END IF;
            
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
            -- Log error (in production, use proper logging)
            RAISE NOTICE 'Error processing row: %', SQLERRM;
        END;
    END LOOP;
    
    RETURN QUERY SELECT v_inserted, v_updated, v_errors;
END;
$$;

-- ============================================================================
-- Batch Load Function: Load Daily Hospitalizations from Staging
-- ============================================================================

CREATE OR REPLACE FUNCTION facts.load_hospitalizations_daily_from_staging(
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS TABLE(
    rows_inserted INTEGER,
    rows_updated INTEGER,
    errors INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_inserted INTEGER := 0;
    v_updated INTEGER := 0;
    v_errors INTEGER := 0;
    v_date_id INTEGER;
    v_location_id INTEGER;
    v_disease_id INTEGER;
    v_source_id INTEGER;
    v_row RECORD;
BEGIN
    -- Loop through staging data
    FOR v_row IN
        SELECT DISTINCT
            hhs.collection_week,
            hhs.state_fips,
            hhs.state,
            hhs.total_adult_patients_hospitalized_confirmed_and_suspected_covid,
            hhs.total_adult_patients_hospitalized_confirmed_covid,
            hhs.staffed_icu_adult_patients_confirmed_and_suspected_covid,
            hhs.total_staffed_adult_icu_beds,
            hhs.total_staffed_adult_icu_beds_occupied,
            hhs.inpatient_beds,
            hhs.inpatient_beds_occupied
        FROM staging.hhs_hospital_utilization_raw hhs
        WHERE hhs.collection_week IS NOT NULL
          AND (p_start_date IS NULL OR hhs.collection_week >= p_start_date)
          AND (p_end_date IS NULL OR hhs.collection_week <= p_end_date)
    LOOP
        BEGIN
            -- Get date_id
            SELECT date_id INTO v_date_id
            FROM dimensions.dim_date
            WHERE full_date = v_row.collection_week::DATE
            LIMIT 1;
            
            -- Get location_id
            SELECT location_id INTO v_location_id
            FROM dimensions.dim_location
            WHERE state_fips = v_row.state_fips
              AND location_type = 'state'
            LIMIT 1;
            
            -- Get disease_id (default to COVID-19 for HHS data, but can be flu-related)
            SELECT disease_id INTO v_disease_id
            FROM dimensions.dim_disease
            WHERE disease_code = 'COVID19'  -- HHS data is primarily COVID, but can be adapted
            LIMIT 1;
            
            -- Get source_id
            SELECT source_id INTO v_source_id
            FROM dimensions.dim_source
            WHERE source_code = 'hhs_hosp'
            LIMIT 1;
            
            -- Only proceed if all dimension keys are found
            IF v_date_id IS NOT NULL AND v_location_id IS NOT NULL 
               AND v_disease_id IS NOT NULL AND v_source_id IS NOT NULL THEN
                
                -- Check if record exists
                IF EXISTS (
                    SELECT 1 FROM facts.fact_flu_hospitalizations_daily
                    WHERE date_id = v_date_id
                      AND location_id = v_location_id
                      AND disease_id = v_disease_id
                      AND source_id = v_source_id
                ) THEN
                    v_updated := v_updated + 1;
                ELSE
                    v_inserted := v_inserted + 1;
                END IF;
                
                -- Calculate utilization rates
                DECLARE
                    v_bed_util_rate DECIMAL;
                    v_icu_util_rate DECIMAL;
                BEGIN
                    IF v_row.inpatient_beds > 0 THEN
                        v_bed_util_rate := (v_row.inpatient_beds_occupied::DECIMAL / v_row.inpatient_beds) * 100;
                    END IF;
                    
                    IF v_row.total_staffed_adult_icu_beds > 0 THEN
                        v_icu_util_rate := (v_row.total_staffed_adult_icu_beds_occupied::DECIMAL / v_row.total_staffed_adult_icu_beds) * 100;
                    END IF;
                    
                    -- Perform upsert
                    PERFORM facts.load_flu_hospitalizations_daily(
                        v_date_id,
                        v_location_id,
                        v_disease_id,
                        v_source_id,
                        COALESCE(v_row.total_adult_patients_hospitalized_confirmed_and_suspected_covid, 0),
                        COALESCE(v_row.total_adult_patients_hospitalized_confirmed_and_suspected_covid, 0),
                        0,  -- pediatric_admissions
                        COALESCE(v_row.total_adult_patients_hospitalized_confirmed_covid, 0),
                        COALESCE(v_row.total_adult_patients_hospitalized_confirmed_and_suspected_covid, 0) - 
                            COALESCE(v_row.total_adult_patients_hospitalized_confirmed_covid, 0),
                        COALESCE(v_row.staffed_icu_adult_patients_confirmed_and_suspected_covid, 0),
                        COALESCE(v_row.staffed_icu_adult_patients_confirmed_and_suspected_covid, 0),
                        0,  -- icu_pediatric_patients
                        COALESCE(v_row.staffed_icu_adult_patients_confirmed_and_suspected_covid, 0),
                        COALESCE(v_row.staffed_icu_adult_patients_confirmed_and_suspected_covid, 0) - 
                            COALESCE(v_row.staffed_icu_adult_patients_confirmed_and_suspected_covid, 0),
                        COALESCE(v_row.inpatient_beds, 0),
                        COALESCE(v_row.inpatient_beds_occupied, 0),
                        COALESCE(v_row.inpatient_beds, 0) - COALESCE(v_row.inpatient_beds_occupied, 0),
                        v_bed_util_rate,
                        COALESCE(v_row.total_staffed_adult_icu_beds, 0),
                        COALESCE(v_row.total_staffed_adult_icu_beds_occupied, 0),
                        COALESCE(v_row.total_staffed_adult_icu_beds, 0) - 
                            COALESCE(v_row.total_staffed_adult_icu_beds_occupied, 0),
                        v_icu_util_rate,
                        NULL,  -- admissions_7day_avg
                        NULL,  -- admissions_30day_avg
                        NULL,  -- icu_usage_7day_avg
                        NULL,  -- data_quality_score
                        FALSE,  -- is_estimated
                        FALSE,  -- has_missing_data
                        NULL    -- notes
                    );
                END;
            ELSE
                v_errors := v_errors + 1;
            END IF;
            
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
            RAISE NOTICE 'Error processing row: %', SQLERRM;
        END;
    END LOOP;
    
    RETURN QUERY SELECT v_inserted, v_updated, v_errors;
END;
$$;
