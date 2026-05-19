-- ============================================================================
-- Analysis Queries for Influenza Surveillance
-- ============================================================================
-- Ready-to-run SQL queries for common analyses
-- Run these in your PostgreSQL database to explore the data

-- ============================================================================
-- 1. STATE COMPARISON: Current Search Interest
-- ============================================================================
-- Which states have the highest current search interest?

SELECT 
    l.state_name,
    l.region,
    AVG(f.search_interest) as avg_interest,
    MAX(f.search_interest) as peak_interest,
    COUNT(*) as days_with_data,
    MAX(d.full_date) as latest_date
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
WHERE d.full_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY l.state_name, l.region
ORDER BY avg_interest DESC;

-- ============================================================================
-- 2. TREND ANALYSIS: Rising vs Declining States
-- ============================================================================
-- Identify states with rising search interest (potential outbreak indicators)

SELECT 
    l.state_name,
    COUNT(*) FILTER (WHERE f.trend_flag = 'rising') as rising_days,
    COUNT(*) FILTER (WHERE f.trend_flag = 'declining') as declining_days,
    COUNT(*) FILTER (WHERE f.trend_flag = 'stable') as stable_days,
    AVG(f.search_interest) as avg_interest,
    MAX(f.percent_change_7day) as max_increase_pct
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
WHERE d.full_date >= CURRENT_DATE - INTERVAL '14 days'
GROUP BY l.state_name
HAVING COUNT(*) FILTER (WHERE f.trend_flag = 'rising') > 
       COUNT(*) FILTER (WHERE f.trend_flag = 'declining')
ORDER BY rising_days DESC, avg_interest DESC;

-- ============================================================================
-- 3. TEMPORAL PATTERNS: Day-of-Week Analysis
-- ============================================================================
-- Are people more likely to search for flu symptoms on certain days?

SELECT 
    d.day_name,
    d.day_of_week,
    AVG(f.search_interest) as avg_interest,
    COUNT(*) as observations,
    MAX(f.search_interest) as peak_interest
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
GROUP BY d.day_name, d.day_of_week
ORDER BY d.day_of_week;

-- ============================================================================
-- 4. EARLY WARNING: States with Sudden Spikes
-- ============================================================================
-- Identify states with recent significant increases

SELECT 
    l.state_name,
    d.full_date,
    f.search_interest,
    f.search_interest_7day_avg,
    f.percent_change_7day,
    f.trend_flag
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
WHERE d.full_date >= CURRENT_DATE - INTERVAL '7 days'
  AND f.percent_change_7day > 20  -- 20% increase threshold
  AND f.trend_flag = 'rising'
ORDER BY f.percent_change_7day DESC, d.full_date DESC;

-- ============================================================================
-- 5. REGIONAL COMPARISON
-- ============================================================================
-- Compare regions (Northeast, South, Midwest, West)

SELECT 
    l.region,
    AVG(f.search_interest) as avg_interest,
    MAX(f.search_interest) as peak_interest,
    COUNT(DISTINCT l.state_code) as states_in_region,
    COUNT(*) FILTER (WHERE f.trend_flag = 'rising') as rising_trends,
    COUNT(*) FILTER (WHERE f.trend_flag = 'declining') as declining_trends
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
WHERE d.full_date >= CURRENT_DATE - INTERVAL '14 days'
GROUP BY l.region
ORDER BY avg_interest DESC;

-- ============================================================================
-- 6. TIME SERIES: Search Interest Over Time
-- ============================================================================
-- Ready for line charts: search interest over time by state

SELECT 
    d.full_date,
    l.state_name,
    f.search_interest,
    f.search_interest_7day_avg,
    f.trend_flag,
    f.percent_change_7day
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
WHERE d.full_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY l.state_name, d.full_date;

-- ============================================================================
-- 7. DASHBOARD SUMMARY METRICS
-- ============================================================================
-- Key performance indicators for dashboard

SELECT 
    COUNT(DISTINCT l.state_code) as states_tracked,
    COUNT(*) as total_observations,
    ROUND(AVG(f.search_interest), 2) as national_avg_interest,
    COUNT(*) FILTER (WHERE f.trend_flag = 'rising') as states_rising,
    COUNT(*) FILTER (WHERE f.trend_flag = 'declining') as states_declining,
    COUNT(*) FILTER (WHERE f.trend_flag = 'stable') as states_stable,
    MAX(d.full_date) as latest_data_date,
    MIN(d.full_date) as earliest_data_date
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id;

-- ============================================================================
-- 8. TOP STATES OF CONCERN
-- ============================================================================
-- States requiring attention (high interest + rising trend)

SELECT 
    l.state_name,
    l.region,
    ROUND(AVG(f.search_interest), 2) as avg_interest,
    COUNT(*) FILTER (WHERE f.trend_flag = 'rising') as rising_days,
    ROUND(MAX(f.percent_change_7day), 2) as max_increase_pct,
    MAX(d.full_date) as latest_date
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
WHERE d.full_date >= CURRENT_DATE - INTERVAL '14 days'
GROUP BY l.state_name, l.region
HAVING AVG(f.search_interest) > 15  -- Above threshold
   AND COUNT(*) FILTER (WHERE f.trend_flag = 'rising') >= 3  -- Multiple rising days
ORDER BY avg_interest DESC, rising_days DESC;

-- ============================================================================
-- 9. ANOMALY DETECTION: Unusual Search Patterns
-- ============================================================================
-- Days with search interest significantly above average

WITH state_avg AS (
    SELECT 
        l.location_id,
        AVG(f.search_interest) as state_avg_interest,
        STDDEV(f.search_interest) as state_stddev
    FROM facts.fact_search_interest_daily f
    JOIN dimensions.dim_location l ON f.location_id = l.location_id
    GROUP BY l.location_id
)
SELECT 
    l.state_name,
    d.full_date,
    f.search_interest,
    ROUND(sa.state_avg_interest, 2) as state_avg,
    ROUND((f.search_interest - sa.state_avg_interest) / NULLIF(sa.state_stddev, 0), 2) as z_score
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
JOIN state_avg sa ON f.location_id = sa.location_id
WHERE ABS((f.search_interest - sa.state_avg_interest) / NULLIF(sa.state_stddev, 0)) > 2  -- 2 standard deviations
  AND d.full_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY ABS((f.search_interest - sa.state_avg_interest) / NULLIF(sa.state_stddev, 0)) DESC;

-- ============================================================================
-- 10. DATA COVERAGE ANALYSIS
-- ============================================================================
-- Which states have complete data coverage?

SELECT 
    l.state_name,
    COUNT(DISTINCT d.full_date) as days_with_data,
    MIN(d.full_date) as first_date,
    MAX(d.full_date) as last_date,
    (MAX(d.full_date) - MIN(d.full_date))::INTEGER as date_range_days,
    ROUND(100.0 * COUNT(DISTINCT d.full_date) / NULLIF((MAX(d.full_date) - MIN(d.full_date))::INTEGER, 0), 2) as coverage_pct
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
GROUP BY l.state_name
ORDER BY coverage_pct DESC, days_with_data DESC;
