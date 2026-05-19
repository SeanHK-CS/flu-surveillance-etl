-- Analytics Tables for Influenza Surveillance
-- These tables contain transformed and aggregated data for analytics

-- Weekly Summary Table
CREATE TABLE IF NOT EXISTS analytics.weekly_summary (
    id SERIAL PRIMARY KEY,
    year INTEGER NOT NULL,
    week INTEGER NOT NULL,
    region VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    total_tests INTEGER,
    positive_tests INTEGER,
    percent_positive DECIMAL(5,2),
    hospitalizations INTEGER,
    deaths INTEGER,
    activity_level VARCHAR(50),
    calculated_date DATE,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(year, week, region, state, country)
);

-- Regional Trends Table
CREATE TABLE IF NOT EXISTS analytics.regional_trends (
    id SERIAL PRIMARY KEY,
    region VARCHAR(100) NOT NULL,
    trend_date DATE NOT NULL,
    cases_7day_avg DECIMAL(10,2),
    cases_30day_avg DECIMAL(10,2),
    positivity_rate DECIMAL(5,2),
    trend_direction VARCHAR(20), -- 'increasing', 'decreasing', 'stable'
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(region, trend_date)
);

-- Laboratory Activity Table
CREATE TABLE IF NOT EXISTS analytics.lab_activity (
    id SERIAL PRIMARY KEY,
    lab_id VARCHAR(50),
    activity_date DATE NOT NULL,
    tests_performed INTEGER,
    positive_tests INTEGER,
    positivity_rate DECIMAL(5,2),
    dominant_virus_type VARCHAR(50),
    region VARCHAR(100),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(lab_id, activity_date)
);

-- Outbreak Indicators Table
CREATE TABLE IF NOT EXISTS analytics.outbreak_indicators (
    id SERIAL PRIMARY KEY,
    region VARCHAR(100) NOT NULL,
    indicator_date DATE NOT NULL,
    case_count INTEGER,
    hospitalization_count INTEGER,
    death_count INTEGER,
    positivity_rate DECIMAL(5,2),
    activity_level VARCHAR(50),
    outbreak_risk_score DECIMAL(5,2), -- Calculated risk score
    alert_status VARCHAR(20), -- 'normal', 'watch', 'warning', 'critical'
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(region, indicator_date)
);

-- Create indexes for analytics queries
CREATE INDEX IF NOT EXISTS idx_weekly_summary_year_week ON analytics.weekly_summary(year, week);
CREATE INDEX IF NOT EXISTS idx_regional_trends_date ON analytics.regional_trends(trend_date);
CREATE INDEX IF NOT EXISTS idx_lab_activity_date ON analytics.lab_activity(activity_date);
CREATE INDEX IF NOT EXISTS idx_outbreak_indicators_date ON analytics.outbreak_indicators(indicator_date);
CREATE INDEX IF NOT EXISTS idx_outbreak_indicators_alert ON analytics.outbreak_indicators(alert_status);
