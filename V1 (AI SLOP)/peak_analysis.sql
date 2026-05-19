-- ============================================================================
-- Peak Influenza Analysis - Google Trends Search Interest
-- ============================================================================
-- This query identifies peak periods of influenza search interest
-- Run this to find when influenza concern was highest

-- ============================================================================
-- 1. ABSOLUTE PEAKS: Highest search interest by state
-- ============================================================================
SELECT 
    l.state_name,
    d.full_date as peak_date,
    f.search_interest as peak_interest,
    f.search_interest_7day_avg as peak_7day_avg,
    f.trend_flag,
    ROW_NUMBER() OVER (PARTITION BY l.state_name ORDER BY f.search_interest DESC) as peak_rank
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
ORDER BY f.search_interest DESC, l.state_name
LIMIT 20;

-- ============================================================================
-- 2. RELATIVE PEAKS: Peaks compared to state averages
-- ============================================================================
-- Identifies dates when search interest was significantly above each state's average
WITH state_stats AS (
    SELECT 
        l.state_name,
        AVG(f.search_interest) as avg_interest,
        MAX(f.search_interest) as max_interest,
        MIN(f.search_interest) as min_interest,
        STDDEV(f.search_interest) as stddev_interest
    FROM facts.fact_search_interest_daily f
    JOIN dimensions.dim_date d ON f.date_id = d.date_id
    JOIN dimensions.dim_location l ON f.location_id = l.location_id
    GROUP BY l.state_name
)
SELECT 
    l.state_name,
    d.full_date as peak_date,
    f.search_interest,
    ROUND(ss.avg_interest, 2) as state_avg,
    ROUND(ss.max_interest, 2) as state_max,
    ROUND((f.search_interest - ss.avg_interest) / NULLIF(ss.stddev_interest, 0), 2) as z_score,
    CASE 
        WHEN f.search_interest >= ss.max_interest * 0.9 THEN 'PEAK (90%+ of max)'
        WHEN f.search_interest >= ss.avg_interest + ss.stddev_interest THEN 'HIGH (1+ std dev above avg)'
        ELSE 'NORMAL'
    END as peak_category
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
JOIN state_stats ss ON l.state_name = ss.state_name
WHERE f.search_interest >= ss.avg_interest + ss.stddev_interest  -- At least 1 std dev above average
ORDER BY f.search_interest DESC, l.state_name;

-- ============================================================================
-- 3. NATIONAL PEAKS: Overall peak periods across all states
-- ============================================================================
WITH daily_peaks AS (
    SELECT 
        d.full_date,
        AVG(f.search_interest) as national_avg_interest,
        MAX(f.search_interest) as national_max_interest,
        COUNT(DISTINCT l.state_code) as states_with_data
    FROM facts.fact_search_interest_daily f
    JOIN dimensions.dim_date d ON f.date_id = d.date_id
    JOIN dimensions.dim_location l ON f.location_id = l.location_id
    GROUP BY d.full_date
),
ranked_days AS (
    SELECT 
        full_date,
        national_avg_interest,
        national_max_interest,
        states_with_data,
        ROW_NUMBER() OVER (ORDER BY national_avg_interest DESC) as peak_rank
    FROM daily_peaks
)
SELECT 
    full_date,
    ROUND(national_avg_interest, 2) as avg_interest,
    national_max_interest as max_interest,
    states_with_data,
    CASE 
        WHEN peak_rank <= 3 THEN 'TOP PEAK'
        WHEN peak_rank <= 10 THEN 'HIGH'
        ELSE 'NORMAL'
    END as peak_category
FROM ranked_days
ORDER BY national_avg_interest DESC
LIMIT 20;

-- ============================================================================
-- 4. WEEKLY PEAKS: Peak weeks of influenza concern
-- ============================================================================
SELECT 
    d.week_number,
    d.year,
    d.week_start_date,
    ROUND(AVG(f.search_interest), 2) as avg_weekly_interest,
    MAX(f.search_interest) as peak_weekly_interest,
    COUNT(DISTINCT l.state_code) as states_tracked,
    STRING_AGG(DISTINCT l.state_name, ', ' ORDER BY l.state_name) as states
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
GROUP BY d.week_number, d.year, d.week_start_date
ORDER BY avg_weekly_interest DESC, d.year DESC, d.week_number DESC;

-- ============================================================================
-- 5. PEAK PERIODS: Sustained high interest (consecutive days)
-- ============================================================================
WITH daily_data AS (
    SELECT 
        d.full_date,
        l.state_name,
        f.search_interest,
        AVG(f.search_interest) OVER (PARTITION BY l.state_name) as state_avg,
        CASE 
            WHEN f.search_interest >= AVG(f.search_interest) OVER (PARTITION BY l.state_name) + 
                                      STDDEV(f.search_interest) OVER (PARTITION BY l.state_name)
            THEN 1 ELSE 0 
        END as is_high_interest
    FROM facts.fact_search_interest_daily f
    JOIN dimensions.dim_date d ON f.date_id = d.date_id
    JOIN dimensions.dim_location l ON f.location_id = l.location_id
),
consecutive_periods AS (
    SELECT 
        state_name,
        full_date,
        search_interest,
        is_high_interest,
        SUM(is_high_interest) OVER (PARTITION BY state_name ORDER BY full_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as high_days_in_7day_window
    FROM daily_data
)
SELECT 
    state_name,
    full_date,
    search_interest,
    high_days_in_7day_window,
    CASE 
        WHEN high_days_in_7day_window >= 5 THEN 'SUSTAINED PEAK (5+ of 7 days high)'
        WHEN high_days_in_7day_window >= 3 THEN 'MODERATE PEAK (3-4 of 7 days high)'
        ELSE 'NORMAL'
    END as peak_period_type
FROM consecutive_periods
WHERE high_days_in_7day_window >= 3
ORDER BY high_days_in_7day_window DESC, search_interest DESC;

-- ============================================================================
-- 6. PEAK COMPARISON: State-by-state peak analysis
-- ============================================================================
SELECT 
    l.state_name,
    MAX(f.search_interest) as absolute_peak,
    MIN(f.search_interest) as absolute_low,
    ROUND(AVG(f.search_interest), 2) as average_interest,
    ROUND(MAX(f.search_interest) - AVG(f.search_interest), 2) as peak_above_avg,
    ROUND((MAX(f.search_interest) - AVG(f.search_interest)) / NULLIF(AVG(f.search_interest), 0) * 100, 1) as peak_percent_increase,
    (SELECT d.full_date 
     FROM facts.fact_search_interest_daily f2
     JOIN dimensions.dim_date d ON f2.date_id = d.date_id
     WHERE f2.location_id = l.location_id 
       AND f2.search_interest = MAX(f.search_interest)
     ORDER BY d.full_date DESC LIMIT 1) as peak_date,
    COUNT(*) as total_days_tracked
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
GROUP BY l.state_name
ORDER BY peak_above_avg DESC;

-- ============================================================================
-- 7. TIME SERIES AROUND PEAKS: Context before and after peak
-- ============================================================================
WITH state_peaks AS (
    SELECT 
        l.location_id,
        l.state_name,
        MAX(f.search_interest) as peak_interest,
        (SELECT d.full_date 
         FROM facts.fact_search_interest_daily f2
         JOIN dimensions.dim_date d ON f2.date_id = d.date_id
         WHERE f2.location_id = l.location_id 
           AND f2.search_interest = MAX(f.search_interest)
         ORDER BY d.full_date DESC LIMIT 1) as peak_date
    FROM facts.fact_search_interest_daily f
    JOIN dimensions.dim_date d ON f.date_id = d.date_id
    JOIN dimensions.dim_location l ON f.location_id = l.location_id
    GROUP BY l.location_id, l.state_name
)
SELECT 
    sp.state_name,
    d.full_date,
    f.search_interest,
    f.search_interest_7day_avg,
    sp.peak_date,
    d.full_date - sp.peak_date as days_from_peak,
    CASE 
        WHEN d.full_date < sp.peak_date THEN 'BEFORE PEAK'
        WHEN d.full_date = sp.peak_date THEN 'PEAK DAY'
        ELSE 'AFTER PEAK'
    END as relative_to_peak
FROM state_peaks sp
JOIN facts.fact_search_interest_daily f ON sp.location_id = f.location_id
JOIN dimensions.dim_date d ON f.date_id = d.date_id
WHERE d.full_date BETWEEN sp.peak_date - INTERVAL '7 days' AND sp.peak_date + INTERVAL '7 days'
ORDER BY sp.state_name, d.full_date;
