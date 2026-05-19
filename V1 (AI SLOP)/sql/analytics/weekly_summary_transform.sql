-- Transform staging data into weekly_summary analytics table
-- This script aggregates data from staging tables into weekly summaries

INSERT INTO analytics.weekly_summary (
    year,
    week,
    region,
    state,
    country,
    total_tests,
    positive_tests,
    percent_positive,
    hospitalizations,
    deaths,
    activity_level,
    calculated_date
)
SELECT 
    fv.year,
    fv.week,
    fv.region,
    fv.state,
    NULL as country,
    fv.total_specimens as total_tests,
    fv.positive_specimens as positive_tests,
    fv.percent_positive,
    NULL as hospitalizations,
    NULL as deaths,
    CASE 
        WHEN fv.percent_positive >= 10 THEN 'high'
        WHEN fv.percent_positive >= 5 THEN 'moderate'
        WHEN fv.percent_positive >= 2 THEN 'low'
        ELSE 'minimal'
    END as activity_level,
    CURRENT_DATE as calculated_date
FROM staging.fluview_raw fv
WHERE NOT EXISTS (
    SELECT 1 
    FROM analytics.weekly_summary ws
    WHERE ws.year = fv.year 
    AND ws.week = fv.week 
    AND ws.region = fv.region 
    AND ws.state = fv.state
)
ON CONFLICT (year, week, region, state, country) 
DO UPDATE SET
    total_tests = EXCLUDED.total_tests,
    positive_tests = EXCLUDED.positive_tests,
    percent_positive = EXCLUDED.percent_positive,
    activity_level = EXCLUDED.activity_level,
    last_updated = CURRENT_TIMESTAMP;
