-- Transform staging data into regional_trends analytics table
-- This script calculates time-series trends by region

INSERT INTO analytics.regional_trends (
    region,
    trend_date,
    cases_7day_avg,
    cases_30day_avg,
    positivity_rate,
    trend_direction,
    last_updated
)
WITH daily_cases AS (
    SELECT 
        region,
        DATE_TRUNC('day', load_timestamp) as trend_date,
        AVG(positive_specimens) as daily_cases
    FROM staging.fluview_raw
    WHERE load_timestamp >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY region, DATE_TRUNC('day', load_timestamp)
),
trends AS (
    SELECT 
        region,
        trend_date,
        AVG(daily_cases) OVER (
            PARTITION BY region 
            ORDER BY trend_date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) as cases_7day_avg,
        AVG(daily_cases) OVER (
            PARTITION BY region 
            ORDER BY trend_date 
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) as cases_30day_avg,
        AVG(percent_positive) as positivity_rate
    FROM daily_cases dc
    JOIN staging.fluview_raw fv 
        ON dc.region = fv.region 
        AND DATE_TRUNC('day', fv.load_timestamp) = dc.trend_date
    GROUP BY region, trend_date, daily_cases
)
SELECT 
    region,
    trend_date,
    cases_7day_avg,
    cases_30day_avg,
    positivity_rate,
    CASE 
        WHEN cases_7day_avg > cases_30day_avg * 1.1 THEN 'increasing'
        WHEN cases_7day_avg < cases_30day_avg * 0.9 THEN 'decreasing'
        ELSE 'stable'
    END as trend_direction,
    CURRENT_TIMESTAMP as last_updated
FROM trends
ON CONFLICT (region, trend_date) 
DO UPDATE SET
    cases_7day_avg = EXCLUDED.cases_7day_avg,
    cases_30day_avg = EXCLUDED.cases_30day_avg,
    positivity_rate = EXCLUDED.positivity_rate,
    trend_direction = EXCLUDED.trend_direction,
    last_updated = CURRENT_TIMESTAMP;
