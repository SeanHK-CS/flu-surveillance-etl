# Analysis Ideas for Influenza Surveillance Data

This document outlines powerful analyses you can perform with your Google Trends and disease surveillance data.

## 1. **Comparative State Analysis**

### Compare search interest trends across states
```sql
-- Which states have the highest current search interest?
SELECT 
    l.state_name,
    l.region,
    AVG(f.search_interest) as avg_interest,
    MAX(f.search_interest) as peak_interest,
    COUNT(*) as days_with_data,
    MAX(f.full_date) as latest_date
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
WHERE d.full_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY l.state_name, l.region
ORDER BY avg_interest DESC;
```

### Identify states with rising vs declining trends
```sql
-- States with rising search interest (potential outbreak indicators)
SELECT 
    l.state_name,
    COUNT(*) FILTER (WHERE f.trend_flag = 'rising') as rising_days,
    COUNT(*) FILTER (WHERE f.trend_flag = 'declining') as declining_days,
    COUNT(*) FILTER (WHERE f.trend_flag = 'stable') as stable_days,
    AVG(f.search_interest) as avg_interest
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
WHERE d.full_date >= CURRENT_DATE - INTERVAL '14 days'
GROUP BY l.state_name
HAVING COUNT(*) FILTER (WHERE f.trend_flag = 'rising') > 
       COUNT(*) FILTER (WHERE f.trend_flag = 'declining')
ORDER BY rising_days DESC;
```

## 2. **Temporal Pattern Analysis**

### Day-of-week patterns (when do people search most?)
```sql
-- Are people more likely to search for flu symptoms on certain days?
SELECT 
    d.day_name,
    d.day_of_week,
    AVG(f.search_interest) as avg_interest,
    COUNT(*) as observations
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
GROUP BY d.day_name, d.day_of_week
ORDER BY d.day_of_week;
```

### Weekly trends and seasonality
```sql
-- Search interest by week (identify seasonal patterns)
SELECT 
    d.year,
    d.week_number,
    d.week_start_date,
    AVG(f.search_interest) as avg_weekly_interest,
    MAX(f.search_interest) as peak_interest,
    COUNT(DISTINCT l.state_code) as states_tracked
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
GROUP BY d.year, d.week_number, d.week_start_date
ORDER BY d.year DESC, d.week_number DESC;
```

## 3. **Early Warning Indicators**

### Identify states with sudden spikes
```sql
-- States with recent significant increases (potential outbreaks)
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
  AND f.percent_change_7day > 20  -- 20% increase
  AND f.trend_flag = 'rising'
ORDER BY f.percent_change_7day DESC, d.full_date DESC;
```

### Anomaly detection (unusual search patterns)
```sql
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
    sa.state_avg_interest,
    (f.search_interest - sa.state_avg_interest) / NULLIF(sa.state_stddev, 0) as z_score
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
JOIN state_avg sa ON f.location_id = sa.location_id
WHERE ABS((f.search_interest - sa.state_avg_interest) / NULLIF(sa.state_stddev, 0)) > 2  -- 2 standard deviations
  AND d.full_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY z_score DESC;
```

## 4. **Geographic Clustering**

### Regional analysis
```sql
-- Compare regions (Northeast, South, Midwest, West)
SELECT 
    l.region,
    AVG(f.search_interest) as avg_interest,
    MAX(f.search_interest) as peak_interest,
    COUNT(DISTINCT l.state_code) as states_in_region,
    COUNT(*) FILTER (WHERE f.trend_flag = 'rising') as rising_trends
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
WHERE d.full_date >= CURRENT_DATE - INTERVAL '14 days'
GROUP BY l.region
ORDER BY avg_interest DESC;
```

## 5. **Correlation Analysis** (when you have CDC/HHS data)

### Compare search interest with actual flu cases
```sql
-- Join Google Trends with CDC flu cases (when available)
SELECT 
    d.full_date,
    l.state_name,
    f.search_interest,
    fc.cases as flu_cases,
    fc.hospitalizations,
    CORR(f.search_interest, fc.cases) OVER (PARTITION BY l.location_id ORDER BY d.full_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as correlation_7day
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
LEFT JOIN facts.fact_flu_cases_weekly fc ON f.location_id = fc.location_id 
    AND f.date_id = fc.date_id
WHERE d.full_date >= CURRENT_DATE - INTERVAL '90 days'
ORDER BY d.full_date DESC, l.state_name;
```

### Lead/lag analysis (does search interest predict cases?)
```sql
-- Does search interest predict flu cases 1-2 weeks ahead?
SELECT 
    l.state_name,
    AVG(f.search_interest) as avg_search_interest,
    AVG(fc.cases) as avg_flu_cases,
    CORR(f.search_interest, fc.cases) as correlation,
    -- Lead correlation (search today vs cases next week)
    CORR(f.search_interest, LEAD(fc.cases, 7) OVER (PARTITION BY l.location_id ORDER BY d.full_date)) as lead_7day_correlation
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
LEFT JOIN facts.fact_flu_cases_weekly fc ON f.location_id = fc.location_id 
    AND f.date_id = fc.date_id
WHERE d.full_date >= CURRENT_DATE - INTERVAL '180 days'
GROUP BY l.state_name
HAVING COUNT(fc.cases) > 10  -- Only states with sufficient data
ORDER BY lead_7day_correlation DESC NULLS LAST;
```

## 6. **Predictive Insights**

### Trend forecasting
```sql
-- Simple moving average forecast (next 7 days)
WITH recent_data AS (
    SELECT 
        l.location_id,
        d.full_date,
        f.search_interest,
        f.search_interest_7day_avg,
        ROW_NUMBER() OVER (PARTITION BY l.location_id ORDER BY d.full_date DESC) as rn
    FROM facts.fact_search_interest_daily f
    JOIN dimensions.dim_date d ON f.date_id = d.date_id
    JOIN dimensions.dim_location l ON f.location_id = l.location_id
    WHERE d.full_date >= CURRENT_DATE - INTERVAL '30 days'
)
SELECT 
    l.state_name,
    rd.full_date,
    rd.search_interest,
    rd.search_interest_7day_avg as forecast_7day_avg,
    rd.search_interest_7day_avg * 1.1 as forecast_upper_bound,
    rd.search_interest_7day_avg * 0.9 as forecast_lower_bound
FROM recent_data rd
JOIN dimensions.dim_location l ON rd.location_id = l.location_id
WHERE rd.rn = 1  -- Most recent day
ORDER BY rd.search_interest_7day_avg DESC;
```

## 7. **Public Health Dashboard Metrics**

### Key performance indicators
```sql
-- Dashboard summary metrics
SELECT 
    COUNT(DISTINCT l.state_code) as states_tracked,
    COUNT(*) as total_observations,
    AVG(f.search_interest) as national_avg_interest,
    COUNT(*) FILTER (WHERE f.trend_flag = 'rising') as states_rising,
    COUNT(*) FILTER (WHERE f.trend_flag = 'declining') as states_declining,
    MAX(d.full_date) as latest_data_date,
    MIN(d.full_date) as earliest_data_date
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id;
```

### Top states of concern
```sql
-- States requiring attention (high interest + rising trend)
SELECT 
    l.state_name,
    l.region,
    AVG(f.search_interest) as avg_interest,
    COUNT(*) FILTER (WHERE f.trend_flag = 'rising') as rising_days,
    MAX(f.percent_change_7day) as max_increase_pct,
    MAX(d.full_date) as latest_date
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
WHERE d.full_date >= CURRENT_DATE - INTERVAL '14 days'
GROUP BY l.state_name, l.region
HAVING AVG(f.search_interest) > 20  -- Above average interest
   AND COUNT(*) FILTER (WHERE f.trend_flag = 'rising') >= 5  -- Multiple rising days
ORDER BY avg_interest DESC, rising_days DESC;
```

## 8. **Data Quality & Completeness**

### Coverage analysis
```sql
-- Which states have complete data coverage?
SELECT 
    l.state_name,
    COUNT(DISTINCT d.full_date) as days_with_data,
    MIN(d.full_date) as first_date,
    MAX(d.full_date) as last_date,
    MAX(d.full_date) - MIN(d.full_date) as date_range_days,
    ROUND(100.0 * COUNT(DISTINCT d.full_date) / NULLIF(MAX(d.full_date) - MIN(d.full_date), 0), 2) as coverage_pct
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
GROUP BY l.state_name
ORDER BY coverage_pct DESC, days_with_data DESC;
```

## 9. **Advanced: Machine Learning Features**

### Feature engineering for ML models
```sql
-- Create features for predictive modeling
SELECT 
    d.full_date,
    l.state_name,
    f.search_interest,
    f.search_interest_7day_avg,
    f.search_interest_30day_avg,
    f.percent_change_7day,
    f.percent_change_30day,
    f.trend_flag,
    -- Lag features
    LAG(f.search_interest, 1) OVER (PARTITION BY l.location_id ORDER BY d.full_date) as lag_1day,
    LAG(f.search_interest, 7) OVER (PARTITION BY l.location_id ORDER BY d.full_date) as lag_7day,
    -- Rolling statistics
    STDDEV(f.search_interest) OVER (PARTITION BY l.location_id ORDER BY d.full_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as volatility_7day,
    -- Seasonal features
    d.month,
    d.week_number,
    d.is_weekend,
    -- Regional average (peer comparison)
    AVG(f.search_interest) OVER (PARTITION BY l.region, d.full_date) as regional_avg
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
WHERE d.full_date >= CURRENT_DATE - INTERVAL '90 days'
ORDER BY l.state_name, d.full_date;
```

## 10. **Visualization-Ready Queries**

### Time series for charts
```sql
-- Ready for line charts: search interest over time by state
SELECT 
    d.full_date,
    l.state_name,
    f.search_interest,
    f.search_interest_7day_avg,
    f.trend_flag
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
WHERE d.full_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY l.state_name, d.full_date;
```

### Heatmap data (state x date)
```sql
-- Pivot data for heatmap visualization
SELECT 
    d.full_date,
    STRING_AGG(l.state_name || ':' || f.search_interest::TEXT, ', ' ORDER BY f.search_interest DESC) as state_interest
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
WHERE d.full_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY d.full_date
ORDER BY d.full_date;
```

---

## Next Steps

1. **Run these queries** to explore your data
2. **Create visualizations** using the results (Python with matplotlib/plotly, or Tableau)
3. **Build a dashboard** combining multiple analyses
4. **Add CDC/HHS data** to enable correlation analysis
5. **Set up alerts** for states with rising trends

## Tools for Visualization

- **Python**: pandas, matplotlib, plotly, seaborn
- **Jupyter Notebooks**: Interactive analysis
- **Tableau/Power BI**: Business intelligence dashboards
- **Grafana**: Real-time monitoring dashboards
