-- Data Quality Validation Functions
-- Reusable SQL functions for data quality checks

-- ============================================================================
-- Function: Check Null Values in Key Columns
-- ============================================================================

CREATE OR REPLACE FUNCTION validation.check_nulls(
    p_table_schema VARCHAR(100),
    p_table_name VARCHAR(100),
    p_key_columns TEXT[] DEFAULT ARRAY['date_id', 'location_id', 'disease_id', 'source_id']
)
RETURNS TABLE(
    total_rows BIGINT,
    null_rows BIGINT,
    null_percentage DECIMAL,
    null_by_column JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
    v_col VARCHAR;
    v_null_conditions TEXT := '';
BEGIN
    -- Build dynamic SQL for null checks
    FOREACH v_col IN ARRAY p_key_columns
    LOOP
        IF v_null_conditions != '' THEN
            v_null_conditions := v_null_conditions || ' OR ';
        END IF;
        v_null_conditions := v_null_conditions || v_col || ' IS NULL';
    END LOOP;
    
    v_sql := format('
        WITH null_counts AS (
            SELECT 
                COUNT(*) as total,
                SUM(CASE WHEN %s THEN 1 ELSE 0 END) as nulls,
                %s
            FROM %I.%I
        )
        SELECT 
            total,
            nulls,
            CASE WHEN total > 0 THEN (nulls::DECIMAL / total) * 100 ELSE 0 END,
            jsonb_build_object(%s)
        FROM null_counts
    ', 
        v_null_conditions,
        -- Build column-specific null counts
        (SELECT string_agg(
            format('SUM(CASE WHEN %I IS NULL THEN 1 ELSE 0 END) as %I', col, col),
            ', '
        ) FROM unnest(p_key_columns) col),
        p_table_schema,
        p_table_name,
        -- Build JSON object
        (SELECT string_agg(
            format('''%s'', SUM(CASE WHEN %I IS NULL THEN 1 ELSE 0 END)', col, col),
            ', '
        ) FROM unnest(p_key_columns) col)
    );
    
    RETURN QUERY EXECUTE v_sql;
END;
$$;

-- ============================================================================
-- Function: Check for Duplicates
-- ============================================================================

CREATE OR REPLACE FUNCTION validation.check_duplicates(
    p_table_schema VARCHAR(100),
    p_table_name VARCHAR(100),
    p_unique_columns TEXT[] DEFAULT ARRAY['date_id', 'location_id', 'disease_id', 'source_id']
)
RETURNS TABLE(
    duplicate_count BIGINT,
    total_duplicate_rows BIGINT,
    sample_duplicates JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
    v_group_by TEXT;
BEGIN
    v_group_by := array_to_string(p_unique_columns, ', ');
    
    v_sql := format('
        WITH duplicates AS (
            SELECT 
                %s,
                COUNT(*) as dup_count
            FROM %I.%I
            GROUP BY %s
            HAVING COUNT(*) > 1
        )
        SELECT 
            COUNT(*)::BIGINT,
            SUM(dup_count - 1)::BIGINT,
            jsonb_agg(
                jsonb_build_object(
                    ''key'', jsonb_build_object(%s),
                    ''count'', dup_count
                )
            ) FILTER (WHERE COUNT(*) <= 10)
        FROM duplicates
    ',
        v_group_by,
        p_table_schema,
        p_table_name,
        v_group_by,
        (SELECT string_agg(
            format('''%s'', %I', col, col),
            ', '
        ) FROM unnest(p_unique_columns) col)
    );
    
    RETURN QUERY EXECUTE v_sql;
END;
$$;

-- ============================================================================
-- Function: Check Date Ranges
-- ============================================================================

CREATE OR REPLACE FUNCTION validation.check_date_ranges(
    p_table_schema VARCHAR(100),
    p_table_name VARCHAR(100),
    p_date_column VARCHAR(100) DEFAULT 'date_id'
)
RETURNS TABLE(
    min_date DATE,
    max_date DATE,
    distinct_dates BIGINT,
    future_dates BIGINT,
    very_old_dates BIGINT,
    date_range_status VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
BEGIN
    v_sql := format('
        SELECT 
            MIN(d.full_date) as min_date,
            MAX(d.full_date) as max_date,
            COUNT(DISTINCT d.full_date)::BIGINT as distinct_dates,
            SUM(CASE WHEN d.full_date > CURRENT_DATE THEN 1 ELSE 0 END)::BIGINT as future_dates,
            SUM(CASE WHEN d.full_date < CURRENT_DATE - INTERVAL ''5 years'' THEN 1 ELSE 0 END)::BIGINT as very_old_dates,
            CASE 
                WHEN MAX(d.full_date) > CURRENT_DATE THEN ''HAS_FUTURE_DATES''
                WHEN MIN(d.full_date) < CURRENT_DATE - INTERVAL ''5 years'' THEN ''HAS_OLD_DATES''
                ELSE ''OK''
            END as date_range_status
        FROM %I.%I f
        JOIN dimensions.dim_date d ON f.%I = d.date_id
    ',
        p_table_schema,
        p_table_name,
        p_date_column
    );
    
    RETURN QUERY EXECUTE v_sql;
END;
$$;

-- ============================================================================
-- Function: Check Incremental Load Integrity
-- ============================================================================

CREATE OR REPLACE FUNCTION validation.check_incremental_loads(
    p_table_schema VARCHAR(100),
    p_table_name VARCHAR(100),
    p_lookback_days INTEGER DEFAULT 7
)
RETURNS TABLE(
    problematic_keys BIGINT,
    avg_updates_per_key DECIMAL,
    max_updates_per_key INTEGER,
    sample_issues JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql TEXT;
BEGIN
    v_sql := format('
        WITH update_counts AS (
            SELECT 
                date_id,
                location_id,
                disease_id,
                source_id,
                COUNT(*) as update_count,
                MIN(updated_timestamp) as first_update,
                MAX(updated_timestamp) as last_update
            FROM %I.%I
            WHERE updated_timestamp >= CURRENT_DATE - INTERVAL ''%s days''
            GROUP BY date_id, location_id, disease_id, source_id
            HAVING COUNT(*) > 1
        )
        SELECT 
            COUNT(*)::BIGINT,
            AVG(update_count)::DECIMAL,
            MAX(update_count)::INTEGER,
            jsonb_agg(
                jsonb_build_object(
                    ''date_id'', date_id,
                    ''location_id'', location_id,
                    ''disease_id'', disease_id,
                    ''source_id'', source_id,
                    ''update_count'', update_count,
                    ''first_update'', first_update,
                    ''last_update'', last_update
                )
            ) FILTER (WHERE COUNT(*) <= 10)
        FROM update_counts
    ',
        p_table_schema,
        p_table_name,
        p_lookback_days
    );
    
    RETURN QUERY EXECUTE v_sql;
END;
$$;

-- ============================================================================
-- Function: Run All Validation Checks
-- ============================================================================

CREATE OR REPLACE FUNCTION validation.run_all_checks()
RETURNS TABLE(
    check_name VARCHAR(200),
    table_name VARCHAR(200),
    status VARCHAR(20),
    details JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check nulls in fact_flu_cases_weekly
    RETURN QUERY
    SELECT 
        'null_check'::VARCHAR(200),
        'facts.fact_flu_cases_weekly'::VARCHAR(200),
        CASE WHEN null_rows > 0 THEN 'FAILED' ELSE 'PASSED' END::VARCHAR(20),
        jsonb_build_object(
            'total_rows', total_rows,
            'null_rows', null_rows,
            'null_percentage', null_percentage
        )
    FROM validation.check_nulls('facts', 'fact_flu_cases_weekly');
    
    -- Check duplicates in fact_flu_cases_weekly
    RETURN QUERY
    SELECT 
        'duplicate_check'::VARCHAR(200),
        'facts.fact_flu_cases_weekly'::VARCHAR(200),
        CASE WHEN duplicate_count > 0 THEN 'FAILED' ELSE 'PASSED' END::VARCHAR(20),
        jsonb_build_object(
            'duplicate_count', duplicate_count,
            'total_duplicate_rows', total_duplicate_rows
        )
    FROM validation.check_duplicates('facts', 'fact_flu_cases_weekly');
    
    -- Check date ranges
    RETURN QUERY
    SELECT 
        'date_range_check'::VARCHAR(200),
        'facts.fact_flu_cases_weekly'::VARCHAR(200),
        date_range_status::VARCHAR(20),
        jsonb_build_object(
            'min_date', min_date,
            'max_date', max_date,
            'distinct_dates', distinct_dates,
            'future_dates', future_dates,
            'very_old_dates', very_old_dates
        )
    FROM validation.check_date_ranges('facts', 'fact_flu_cases_weekly');
    
    -- Check incremental loads
    RETURN QUERY
    SELECT 
        'incremental_load_check'::VARCHAR(200),
        'facts.fact_flu_cases_weekly'::VARCHAR(200),
        CASE WHEN problematic_keys > 0 THEN 'WARNING' ELSE 'PASSED' END::VARCHAR(20),
        jsonb_build_object(
            'problematic_keys', problematic_keys,
            'avg_updates_per_key', avg_updates_per_key,
            'max_updates_per_key', max_updates_per_key
        )
    FROM validation.check_incremental_loads('facts', 'fact_flu_cases_weekly');
    
    -- Repeat for daily hospitalizations table
    RETURN QUERY
    SELECT 
        'null_check'::VARCHAR(200),
        'facts.fact_flu_hospitalizations_daily'::VARCHAR(200),
        CASE WHEN null_rows > 0 THEN 'FAILED' ELSE 'PASSED' END::VARCHAR(20),
        jsonb_build_object(
            'total_rows', total_rows,
            'null_rows', null_rows,
            'null_percentage', null_percentage
        )
    FROM validation.check_nulls('facts', 'fact_flu_hospitalizations_daily');
    
    RETURN QUERY
    SELECT 
        'duplicate_check'::VARCHAR(200),
        'facts.fact_flu_hospitalizations_daily'::VARCHAR(200),
        CASE WHEN duplicate_count > 0 THEN 'FAILED' ELSE 'PASSED' END::VARCHAR(20),
        jsonb_build_object(
            'duplicate_count', duplicate_count,
            'total_duplicate_rows', total_duplicate_rows
        )
    FROM validation.check_duplicates('facts', 'fact_flu_hospitalizations_daily');
    
    RETURN QUERY
    SELECT 
        'date_range_check'::VARCHAR(200),
        'facts.fact_flu_hospitalizations_daily'::VARCHAR(200),
        date_range_status::VARCHAR(20),
        jsonb_build_object(
            'min_date', min_date,
            'max_date', max_date,
            'distinct_dates', distinct_dates,
            'future_dates', future_dates,
            'very_old_dates', very_old_dates
        )
    FROM validation.check_date_ranges('facts', 'fact_flu_hospitalizations_daily');
    
    RETURN QUERY
    SELECT 
        'incremental_load_check'::VARCHAR(200),
        'facts.fact_flu_hospitalizations_daily'::VARCHAR(200),
        CASE WHEN problematic_keys > 0 THEN 'WARNING' ELSE 'PASSED' END::VARCHAR(20),
        jsonb_build_object(
            'problematic_keys', problematic_keys,
            'avg_updates_per_key', avg_updates_per_key,
            'max_updates_per_key', max_updates_per_key
        )
    FROM validation.check_incremental_loads('facts', 'fact_flu_hospitalizations_daily');
END;
$$;

-- Create validation schema
CREATE SCHEMA IF NOT EXISTS validation;
