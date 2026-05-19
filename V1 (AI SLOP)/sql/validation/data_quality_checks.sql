-- Data Quality Validation SQL Scripts
-- These queries check for data quality issues in fact and staging tables

-- ============================================================================
-- Check 1: Null Values in Key Columns
-- ============================================================================

-- Check fact_flu_cases_weekly for nulls
SELECT 
    'fact_flu_cases_weekly' as table_name,
    COUNT(*) as total_rows,
    SUM(CASE WHEN date_id IS NULL THEN 1 ELSE 0 END) as null_date_id,
    SUM(CASE WHEN location_id IS NULL THEN 1 ELSE 0 END) as null_location_id,
    SUM(CASE WHEN disease_id IS NULL THEN 1 ELSE 0 END) as null_disease_id,
    SUM(CASE WHEN source_id IS NULL THEN 1 ELSE 0 END) as null_source_id,
    SUM(CASE WHEN date_id IS NULL OR location_id IS NULL 
             OR disease_id IS NULL OR source_id IS NULL 
        THEN 1 ELSE 0 END) as rows_with_any_null_key
FROM facts.fact_flu_cases_weekly;

-- Check fact_flu_hospitalizations_daily for nulls
SELECT 
    'fact_flu_hospitalizations_daily' as table_name,
    COUNT(*) as total_rows,
    SUM(CASE WHEN date_id IS NULL THEN 1 ELSE 0 END) as null_date_id,
    SUM(CASE WHEN location_id IS NULL THEN 1 ELSE 0 END) as null_location_id,
    SUM(CASE WHEN disease_id IS NULL THEN 1 ELSE 0 END) as null_disease_id,
    SUM(CASE WHEN source_id IS NULL THEN 1 ELSE 0 END) as null_source_id,
    SUM(CASE WHEN date_id IS NULL OR location_id IS NULL 
             OR disease_id IS NULL OR source_id IS NULL 
        THEN 1 ELSE 0 END) as rows_with_any_null_key
FROM facts.fact_flu_hospitalizations_daily;

-- ============================================================================
-- Check 2: Duplicate Records
-- ============================================================================

-- Check for duplicates in fact_flu_cases_weekly
SELECT 
    'fact_flu_cases_weekly' as table_name,
    date_id,
    location_id,
    disease_id,
    source_id,
    COUNT(*) as duplicate_count
FROM facts.fact_flu_cases_weekly
GROUP BY date_id, location_id, disease_id, source_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;

-- Check for duplicates in fact_flu_hospitalizations_daily
SELECT 
    'fact_flu_hospitalizations_daily' as table_name,
    date_id,
    location_id,
    disease_id,
    source_id,
    COUNT(*) as duplicate_count
FROM facts.fact_flu_hospitalizations_daily
GROUP BY date_id, location_id, disease_id, source_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;

-- ============================================================================
-- Check 3: Date Range Validation
-- ============================================================================

-- Compare fact table date ranges with staging
WITH fact_ranges AS (
    SELECT 
        'fact_flu_cases_weekly' as table_name,
        MIN(d.full_date) as min_date,
        MAX(d.full_date) as max_date,
        COUNT(DISTINCT d.full_date) as distinct_dates
    FROM facts.fact_flu_cases_weekly f
    JOIN dimensions.dim_date d ON f.date_id = d.date_id
),
staging_ranges AS (
    SELECT 
        'fluview_raw' as table_name,
        MIN(load_timestamp::DATE) as min_date,
        MAX(load_timestamp::DATE) as max_date,
        COUNT(DISTINCT load_timestamp::DATE) as distinct_dates
    FROM staging.fluview_raw
)
SELECT 
    f.table_name as fact_table,
    f.min_date as fact_min_date,
    f.max_date as fact_max_date,
    s.table_name as staging_table,
    s.min_date as staging_min_date,
    s.max_date as staging_max_date,
    CASE 
        WHEN f.min_date != s.min_date THEN 'MISMATCH'
        WHEN f.max_date != s.max_date THEN 'MISMATCH'
        ELSE 'MATCH'
    END as date_range_status
FROM fact_ranges f
CROSS JOIN staging_ranges s;

-- Check for future dates (data quality issue)
SELECT 
    'future_dates' as check_type,
    COUNT(*) as future_date_count
FROM facts.fact_flu_cases_weekly f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
WHERE d.full_date > CURRENT_DATE;

-- Check for very old dates (more than 5 years)
SELECT 
    'very_old_dates' as check_type,
    COUNT(*) as old_date_count
FROM facts.fact_flu_cases_weekly f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
WHERE d.full_date < CURRENT_DATE - INTERVAL '5 years';

-- ============================================================================
-- Check 4: Incremental Load Integrity
-- ============================================================================

-- Check for records with same key but multiple updates (potential duplicate loads)
WITH update_counts AS (
    SELECT 
        date_id,
        location_id,
        disease_id,
        source_id,
        COUNT(*) as update_count,
        MIN(updated_timestamp) as first_update,
        MAX(updated_timestamp) as last_update,
        MAX(updated_timestamp) - MIN(updated_timestamp) as time_span
    FROM facts.fact_flu_cases_weekly
    WHERE updated_timestamp >= CURRENT_DATE - INTERVAL '7 days'
    GROUP BY date_id, location_id, disease_id, source_id
    HAVING COUNT(*) > 1
)
SELECT 
    'incremental_load_issues' as check_type,
    COUNT(*) as problematic_records,
    AVG(update_count) as avg_updates_per_key,
    MAX(update_count) as max_updates_per_key
FROM update_counts;

-- Sample of problematic records
SELECT 
    date_id,
    location_id,
    disease_id,
    source_id,
    COUNT(*) as update_count,
    MIN(updated_timestamp) as first_update,
    MAX(updated_timestamp) as last_update
FROM facts.fact_flu_cases_weekly
WHERE updated_timestamp >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY date_id, location_id, disease_id, source_id
HAVING COUNT(*) > 1
ORDER BY update_count DESC
LIMIT 10;

-- ============================================================================
-- Check 5: Data Freshness
-- ============================================================================

-- Check when data was last updated
SELECT 
    'data_freshness' as check_type,
    MAX(updated_timestamp) as last_update,
    CURRENT_TIMESTAMP - MAX(updated_timestamp) as hours_since_update,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - MAX(updated_timestamp))) / 3600 as hours_since_update_numeric
FROM facts.fact_flu_cases_weekly;

-- Check latest data date vs current date
SELECT 
    'data_date_freshness' as check_type,
    MAX(d.full_date) as latest_data_date,
    CURRENT_DATE - MAX(d.full_date) as days_behind,
    CASE 
        WHEN CURRENT_DATE - MAX(d.full_date) > 7 THEN 'STALE'
        WHEN CURRENT_DATE - MAX(d.full_date) > 3 THEN 'WARNING'
        ELSE 'FRESH'
    END as freshness_status
FROM facts.fact_flu_cases_weekly f
JOIN dimensions.dim_date d ON f.date_id = d.date_id;

-- ============================================================================
-- Check 6: Referential Integrity
-- ============================================================================

-- Check for orphaned records (date_id not in dim_date)
SELECT 
    'orphaned_date_ids' as check_type,
    COUNT(*) as orphaned_count
FROM facts.fact_flu_cases_weekly f
LEFT JOIN dimensions.dim_date d ON f.date_id = d.date_id
WHERE d.date_id IS NULL;

-- Check for orphaned location_ids
SELECT 
    'orphaned_location_ids' as check_type,
    COUNT(*) as orphaned_count
FROM facts.fact_flu_cases_weekly f
LEFT JOIN dimensions.dim_location l ON f.location_id = l.location_id
WHERE l.location_id IS NULL;

-- Check for orphaned disease_ids
SELECT 
    'orphaned_disease_ids' as check_type,
    COUNT(*) as orphaned_count
FROM facts.fact_flu_cases_weekly f
LEFT JOIN dimensions.dim_disease di ON f.disease_id = di.disease_id
WHERE di.disease_id IS NULL;

-- Check for orphaned source_ids
SELECT 
    'orphaned_source_ids' as check_type,
    COUNT(*) as orphaned_count
FROM facts.fact_flu_cases_weekly f
LEFT JOIN dimensions.dim_source s ON f.source_id = s.source_id
WHERE s.source_id IS NULL;

-- ============================================================================
-- Check 7: Data Completeness
-- ============================================================================

-- Check for missing data in recent periods
SELECT 
    d.full_date,
    COUNT(DISTINCT f.location_id) as locations_with_data,
    COUNT(*) as total_records
FROM facts.fact_flu_cases_weekly f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
WHERE d.full_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY d.full_date
ORDER BY d.full_date DESC;

-- Check for gaps in date coverage
WITH date_series AS (
    SELECT generate_series(
        CURRENT_DATE - INTERVAL '30 days',
        CURRENT_DATE,
        '1 day'::interval
    )::DATE as date
),
fact_dates AS (
    SELECT DISTINCT d.full_date
    FROM facts.fact_flu_cases_weekly f
    JOIN dimensions.dim_date d ON f.date_id = d.date_id
    WHERE d.full_date >= CURRENT_DATE - INTERVAL '30 days'
)
SELECT 
    'missing_dates' as check_type,
    ds.date as missing_date
FROM date_series ds
LEFT JOIN fact_dates fd ON ds.date = fd.full_date
WHERE fd.full_date IS NULL
ORDER BY ds.date DESC;

-- ============================================================================
-- Check 8: Value Range Validation
-- ============================================================================

-- Check for negative values in metrics
SELECT 
    'negative_values' as check_type,
    COUNT(*) as negative_cases_count
FROM facts.fact_flu_cases_weekly
WHERE cases < 0 OR positive_cases < 0 OR total_tests < 0 
   OR hospitalizations < 0 OR deaths < 0;

-- Check for unreasonable values (percent_positive > 100)
SELECT 
    'invalid_percentages' as check_type,
    COUNT(*) as invalid_percent_count
FROM facts.fact_flu_cases_weekly
WHERE percent_positive > 100 OR percent_positive < 0;

-- Check for zero tests but positive cases (data quality issue)
SELECT 
    'zero_tests_with_positives' as check_type,
    COUNT(*) as problematic_records
FROM facts.fact_flu_cases_weekly
WHERE total_tests = 0 AND positive_cases > 0;

-- ============================================================================
-- Summary Report Query
-- ============================================================================

-- Comprehensive summary of all checks
SELECT 
    'SUMMARY' as report_type,
    (SELECT COUNT(*) FROM facts.fact_flu_cases_weekly) as total_weekly_records,
    (SELECT COUNT(*) FROM facts.fact_flu_hospitalizations_daily) as total_daily_records,
    (SELECT COUNT(*) FROM facts.fact_flu_cases_weekly 
     WHERE date_id IS NULL OR location_id IS NULL 
        OR disease_id IS NULL OR source_id IS NULL) as weekly_null_keys,
    (SELECT COUNT(*) FROM facts.fact_flu_hospitalizations_daily 
     WHERE date_id IS NULL OR location_id IS NULL 
        OR disease_id IS NULL OR source_id IS NULL) as daily_null_keys,
    (SELECT COUNT(*) FROM (
        SELECT date_id, location_id, disease_id, source_id
        FROM facts.fact_flu_cases_weekly
        GROUP BY date_id, location_id, disease_id, source_id
        HAVING COUNT(*) > 1
    ) sub) as weekly_duplicates,
    (SELECT COUNT(*) FROM (
        SELECT date_id, location_id, disease_id, source_id
        FROM facts.fact_flu_hospitalizations_daily
        GROUP BY date_id, location_id, disease_id, source_id
        HAVING COUNT(*) > 1
    ) sub) as daily_duplicates,
    (SELECT MAX(updated_timestamp) FROM facts.fact_flu_cases_weekly) as last_weekly_update,
    (SELECT MAX(updated_timestamp) FROM facts.fact_flu_hospitalizations_daily) as last_daily_update;
