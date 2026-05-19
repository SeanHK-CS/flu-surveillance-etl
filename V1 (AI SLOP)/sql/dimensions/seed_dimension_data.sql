-- Seed Data for Dimension Tables
-- Initial data population for common values
-- This script can be run after creating dimension tables

-- ============================================================================
-- Seed DIM_DATE - Populate date dimension for a date range
-- ============================================================================
-- This function/script populates the date dimension for a specified date range
-- Typically run for historical dates and extended into the future

-- Example: Populate dates from 2020-01-01 to 2030-12-31
-- Note: This is a template - adjust date range as needed

DO $$
DECLARE
    start_date DATE := '2020-01-01';
    end_date DATE := '2030-12-31';
    current_date DATE;
    date_id_val INTEGER;
    epiweek_val INTEGER;
    flu_season_val VARCHAR(20);
    flu_season_week_val INTEGER;
    year_val INTEGER;
    week_val INTEGER;
BEGIN
    current_date := start_date;
    
    WHILE current_date <= end_date LOOP
        -- Calculate date_id as YYYYMMDD
        date_id_val := TO_NUMBER(TO_CHAR(current_date, 'YYYYMMDD'), '99999999');
        
        -- Calculate epiweek (CDC format: YYYYWW)
        year_val := EXTRACT(YEAR FROM current_date);
        week_val := EXTRACT(WEEK FROM current_date);
        
        -- Handle year boundary for epiweek
        IF week_val = 1 AND EXTRACT(MONTH FROM current_date) = 12 THEN
            year_val := year_val + 1;
        ELSIF week_val >= 52 AND EXTRACT(MONTH FROM current_date) = 1 THEN
            year_val := year_val - 1;
        END IF;
        
        epiweek_val := year_val * 100 + week_val;
        
        -- Calculate flu season (typically starts week 40, ends week 20 of next year)
        IF week_val >= 40 THEN
            flu_season_val := year_val || '-' || (year_val + 1);
            flu_season_week_val := week_val - 39;
        ELSIF week_val <= 20 THEN
            flu_season_val := (year_val - 1) || '-' || year_val;
            flu_season_week_val := week_val + 13;  -- 52 - 39 = 13 weeks from previous year
        ELSE
            flu_season_val := NULL;
            flu_season_week_val := NULL;
        END IF;
        
        -- Insert date record
        INSERT INTO dimensions.dim_date (
            date_id,
            full_date,
            day_of_week,
            day_name,
            day_of_month,
            day_of_year,
            week_number,
            week_start_date,
            week_end_date,
            epiweek,
            month,
            month_name,
            month_abbreviation,
            quarter,
            quarter_name,
            year,
            year_quarter,
            year_month,
            is_weekend,
            flu_season,
            flu_season_week
        ) VALUES (
            date_id_val,
            current_date,
            EXTRACT(DOW FROM current_date) + 1,  -- Adjust to 1-7 (Mon-Sun)
            TO_CHAR(current_date, 'Day'),
            EXTRACT(DAY FROM current_date),
            EXTRACT(DOY FROM current_date),
            EXTRACT(WEEK FROM current_date),
            current_date - (EXTRACT(DOW FROM current_date)::INTEGER),
            current_date - (EXTRACT(DOW FROM current_date)::INTEGER) + 6,
            epiweek_val,
            EXTRACT(MONTH FROM current_date),
            TO_CHAR(current_date, 'Month'),
            TO_CHAR(current_date, 'Mon'),
            EXTRACT(QUARTER FROM current_date),
            'Q' || EXTRACT(QUARTER FROM current_date),
            EXTRACT(YEAR FROM current_date),
            EXTRACT(YEAR FROM current_date) || '-Q' || EXTRACT(QUARTER FROM current_date),
            TO_CHAR(current_date, 'YYYY-MM'),
            EXTRACT(DOW FROM current_date) IN (0, 6),  -- Saturday or Sunday
            flu_season_val,
            flu_season_week_val
        )
        ON CONFLICT (date_id) DO NOTHING;
        
        current_date := current_date + INTERVAL '1 day';
    END LOOP;
END $$;

-- ============================================================================
-- Seed DIM_LOCATION - US States and Regions
-- ============================================================================

-- Insert US States
INSERT INTO dimensions.dim_location (
    location_type,
    location_code,
    location_name,
    country_code,
    country_name,
    state_code,
    state_name,
    state_fips,
    region_type,
    is_active
) VALUES
    ('state', 'AL', 'Alabama', 'USA', 'United States', 'AL', 'Alabama', '01', 'hhs', TRUE),
    ('state', 'AK', 'Alaska', 'USA', 'United States', 'AK', 'Alaska', '02', 'hhs', TRUE),
    ('state', 'AZ', 'Arizona', 'USA', 'United States', 'AZ', 'Arizona', '04', 'hhs', TRUE),
    ('state', 'AR', 'Arkansas', 'USA', 'United States', 'AR', 'Arkansas', '05', 'hhs', TRUE),
    ('state', 'CA', 'California', 'USA', 'United States', 'CA', 'California', '06', 'hhs', TRUE),
    ('state', 'CO', 'Colorado', 'USA', 'United States', 'CO', 'Colorado', '08', 'hhs', TRUE),
    ('state', 'CT', 'Connecticut', 'USA', 'United States', 'CT', 'Connecticut', '09', 'hhs', TRUE),
    ('state', 'DE', 'Delaware', 'USA', 'United States', 'DE', 'Delaware', '10', 'hhs', TRUE),
    ('state', 'FL', 'Florida', 'USA', 'United States', 'FL', 'Florida', '12', 'hhs', TRUE),
    ('state', 'GA', 'Georgia', 'USA', 'United States', 'GA', 'Georgia', '13', 'hhs', TRUE),
    ('state', 'HI', 'Hawaii', 'USA', 'United States', 'HI', 'Hawaii', '15', 'hhs', TRUE),
    ('state', 'ID', 'Idaho', 'USA', 'United States', 'ID', 'Idaho', '16', 'hhs', TRUE),
    ('state', 'IL', 'Illinois', 'USA', 'United States', 'IL', 'Illinois', '17', 'hhs', TRUE),
    ('state', 'IN', 'Indiana', 'USA', 'United States', 'IN', 'Indiana', '18', 'hhs', TRUE),
    ('state', 'IA', 'Iowa', 'USA', 'United States', 'IA', 'Iowa', '19', 'hhs', TRUE),
    ('state', 'KS', 'Kansas', 'USA', 'United States', 'KS', 'Kansas', '20', 'hhs', TRUE),
    ('state', 'KY', 'Kentucky', 'USA', 'United States', 'KY', 'Kentucky', '21', 'hhs', TRUE),
    ('state', 'LA', 'Louisiana', 'USA', 'United States', 'LA', 'Louisiana', '22', 'hhs', TRUE),
    ('state', 'ME', 'Maine', 'USA', 'United States', 'ME', 'Maine', '23', 'hhs', TRUE),
    ('state', 'MD', 'Maryland', 'USA', 'United States', 'MD', 'Maryland', '24', 'hhs', TRUE),
    ('state', 'MA', 'Massachusetts', 'USA', 'United States', 'MA', 'Massachusetts', '25', 'hhs', TRUE),
    ('state', 'MI', 'Michigan', 'USA', 'United States', 'MI', 'Michigan', '26', 'hhs', TRUE),
    ('state', 'MN', 'Minnesota', 'USA', 'United States', 'MN', 'Minnesota', '27', 'hhs', TRUE),
    ('state', 'MS', 'Mississippi', 'USA', 'United States', 'MS', 'Mississippi', '28', 'hhs', TRUE),
    ('state', 'MO', 'Missouri', 'USA', 'United States', 'MO', 'Missouri', '29', 'hhs', TRUE),
    ('state', 'MT', 'Montana', 'USA', 'United States', 'MT', 'Montana', '30', 'hhs', TRUE),
    ('state', 'NE', 'Nebraska', 'USA', 'United States', 'NE', 'Nebraska', '31', 'hhs', TRUE),
    ('state', 'NV', 'Nevada', 'USA', 'United States', 'NV', 'Nevada', '32', 'hhs', TRUE),
    ('state', 'NH', 'New Hampshire', 'USA', 'United States', 'NH', 'New Hampshire', '33', 'hhs', TRUE),
    ('state', 'NJ', 'New Jersey', 'USA', 'United States', 'NJ', 'New Jersey', '34', 'hhs', TRUE),
    ('state', 'NM', 'New Mexico', 'USA', 'United States', 'NM', 'New Mexico', '35', 'hhs', TRUE),
    ('state', 'NY', 'New York', 'USA', 'United States', 'NY', 'New York', '36', 'hhs', TRUE),
    ('state', 'NC', 'North Carolina', 'USA', 'United States', 'NC', 'North Carolina', '37', 'hhs', TRUE),
    ('state', 'ND', 'North Dakota', 'USA', 'United States', 'ND', 'North Dakota', '38', 'hhs', TRUE),
    ('state', 'OH', 'Ohio', 'USA', 'United States', 'OH', 'Ohio', '39', 'hhs', TRUE),
    ('state', 'OK', 'Oklahoma', 'USA', 'United States', 'OK', 'Oklahoma', '40', 'hhs', TRUE),
    ('state', 'OR', 'Oregon', 'USA', 'United States', 'OR', 'Oregon', '41', 'hhs', TRUE),
    ('state', 'PA', 'Pennsylvania', 'USA', 'United States', 'PA', 'Pennsylvania', '42', 'hhs', TRUE),
    ('state', 'RI', 'Rhode Island', 'USA', 'United States', 'RI', 'Rhode Island', '43', 'hhs', TRUE),
    ('state', 'SC', 'South Carolina', 'USA', 'United States', 'SC', 'South Carolina', '45', 'hhs', TRUE),
    ('state', 'SD', 'South Dakota', 'USA', 'United States', 'SD', 'South Dakota', '46', 'hhs', TRUE),
    ('state', 'TN', 'Tennessee', 'USA', 'United States', 'TN', 'Tennessee', '47', 'hhs', TRUE),
    ('state', 'TX', 'Texas', 'USA', 'United States', 'TX', 'Texas', '48', 'hhs', TRUE),
    ('state', 'UT', 'Utah', 'USA', 'United States', 'UT', 'Utah', '49', 'hhs', TRUE),
    ('state', 'VT', 'Vermont', 'USA', 'United States', 'VT', 'Vermont', '50', 'hhs', TRUE),
    ('state', 'VA', 'Virginia', 'USA', 'United States', 'VA', 'Virginia', '51', 'hhs', TRUE),
    ('state', 'WA', 'Washington', 'USA', 'United States', 'WA', 'Washington', '53', 'hhs', TRUE),
    ('state', 'WV', 'West Virginia', 'USA', 'United States', 'WV', 'West Virginia', '54', 'hhs', TRUE),
    ('state', 'WI', 'Wisconsin', 'USA', 'United States', 'WI', 'Wisconsin', '55', 'hhs', TRUE),
    ('state', 'WY', 'Wyoming', 'USA', 'United States', 'WY', 'Wyoming', '56', 'hhs', TRUE),
    ('state', 'DC', 'District of Columbia', 'USA', 'United States', 'DC', 'District of Columbia', '11', 'hhs', TRUE),
    ('territory', 'PR', 'Puerto Rico', 'USA', 'United States', 'PR', 'Puerto Rico', '72', 'hhs', TRUE),
    ('territory', 'VI', 'U.S. Virgin Islands', 'USA', 'United States', 'VI', 'U.S. Virgin Islands', '78', 'hhs', TRUE)
ON CONFLICT (location_code, location_type) DO NOTHING;

-- Insert HHS Regions
INSERT INTO dimensions.dim_location (
    location_type,
    location_code,
    location_name,
    country_code,
    country_name,
    region_code,
    region_name,
    region_type,
    is_active
) VALUES
    ('region', 'HHS1', 'HHS Region 1', 'USA', 'United States', '1', 'HHS Region 1', 'hhs', TRUE),
    ('region', 'HHS2', 'HHS Region 2', 'USA', 'United States', '2', 'HHS Region 2', 'hhs', TRUE),
    ('region', 'HHS3', 'HHS Region 3', 'USA', 'United States', '3', 'HHS Region 3', 'hhs', TRUE),
    ('region', 'HHS4', 'HHS Region 4', 'USA', 'United States', '4', 'HHS Region 4', 'hhs', TRUE),
    ('region', 'HHS5', 'HHS Region 5', 'USA', 'United States', '5', 'HHS Region 5', 'hhs', TRUE),
    ('region', 'HHS6', 'HHS Region 6', 'USA', 'United States', '6', 'HHS Region 6', 'hhs', TRUE),
    ('region', 'HHS7', 'HHS Region 7', 'USA', 'United States', '7', 'HHS Region 7', 'hhs', TRUE),
    ('region', 'HHS8', 'HHS Region 8', 'USA', 'United States', '8', 'HHS Region 8', 'hhs', TRUE),
    ('region', 'HHS9', 'HHS Region 9', 'USA', 'United States', '9', 'HHS Region 9', 'hhs', TRUE),
    ('region', 'HHS10', 'HHS Region 10', 'USA', 'United States', '10', 'HHS Region 10', 'hhs', TRUE),
    ('region', 'NAT', 'National', 'USA', 'United States', 'NAT', 'National', 'hhs', TRUE)
ON CONFLICT (location_code, location_type) DO NOTHING;

-- ============================================================================
-- Seed DIM_DISEASE - Common Diseases
-- ============================================================================

INSERT INTO dimensions.dim_disease (
    disease_code,
    disease_name,
    disease_category,
    disease_type,
    icd10_code,
    icd10_description,
    is_reportable,
    surveillance_type,
    description,
    is_active
) VALUES
    ('FLU', 'Influenza', 'respiratory', 'influenza', 'J09-J11', 'Influenza due to identified influenza virus', TRUE, 'laboratory', 'Seasonal influenza caused by influenza viruses', TRUE),
    ('FLUA', 'Influenza A', 'respiratory', 'influenza', 'J09-J10', 'Influenza due to identified influenza virus', TRUE, 'laboratory', 'Influenza A virus infection', TRUE),
    ('FLUB', 'Influenza B', 'respiratory', 'influenza', 'J10', 'Influenza due to other identified influenza virus', TRUE, 'laboratory', 'Influenza B virus infection', TRUE),
    ('FLUH1N1', 'Influenza A(H1N1)', 'respiratory', 'influenza', 'J09', 'Influenza due to identified novel influenza A virus', TRUE, 'laboratory', 'Influenza A H1N1 subtype', TRUE),
    ('FLUH3N2', 'Influenza A(H3N2)', 'respiratory', 'influenza', 'J10', 'Influenza due to other identified influenza virus', TRUE, 'laboratory', 'Influenza A H3N2 subtype', TRUE),
    ('COVID19', 'COVID-19', 'respiratory', 'covid-19', 'U07.1', 'COVID-19, virus identified', TRUE, 'laboratory', 'Coronavirus disease 2019', TRUE),
    ('RSV', 'Respiratory Syncytial Virus', 'respiratory', 'rsv', 'J21.0', 'Acute bronchiolitis due to respiratory syncytial virus', TRUE, 'laboratory', 'RSV infection', TRUE),
    ('PNEU', 'Pneumonia', 'respiratory', 'pneumonia', 'J18', 'Pneumonia, unspecified organism', TRUE, 'clinical', 'Pneumonia (unspecified)', TRUE)
ON CONFLICT (disease_code) DO NOTHING;

-- ============================================================================
-- Seed DIM_SOURCE - Data Sources
-- ============================================================================

INSERT INTO dimensions.dim_source (
    source_code,
    source_name,
    source_type,
    source_category,
    organization,
    api_endpoint,
    data_format,
    update_frequency,
    data_quality_score,
    reliability_level,
    description,
    is_active
) VALUES
    ('cdc_fluview', 'CDC FluView', 'api', 'government', 'Centers for Disease Control and Prevention', 'https://api.delphi.cmu.edu/epidata/fluview/', 'json', 'weekly', 0.95, 'high', 'CDC weekly influenza surveillance data via Delphi Epidata API', TRUE),
    ('who_flunet', 'WHO FluNet', 'api', 'government', 'World Health Organization', 'https://apps.who.int/flumart/', 'csv', 'weekly', 0.90, 'high', 'WHO global influenza surveillance data', TRUE),
    ('hhs_hosp', 'HHS Hospital Utilization', 'csv', 'government', 'U.S. Department of Health and Human Services', 'https://healthdata.gov/resource/g62h-syeh.csv', 'csv', 'daily', 0.92, 'high', 'HHS hospital capacity and utilization data', TRUE),
    ('cdc_nhsn', 'CDC NHSN', 'database', 'government', 'Centers for Disease Control and Prevention', NULL, 'database', 'daily', 0.93, 'high', 'CDC National Healthcare Safety Network data', TRUE),
    ('state_health', 'State Health Departments', 'file', 'government', 'Various State Health Departments', NULL, 'csv', 'weekly', 0.85, 'medium', 'State-level health department reports', TRUE),
    ('lab_network', 'Laboratory Network', 'api', 'healthcare', 'Clinical Laboratory Network', NULL, 'json', 'daily', 0.88, 'high', 'Clinical laboratory test results', TRUE),
    ('google_trends', 'Google Trends', 'api', 'research', 'Google', 'https://trends.google.com/trends/', 'api', 'daily', 0.85, 'medium', 'Google Trends search interest data for flu-related terms', TRUE)
ON CONFLICT (source_code) DO NOTHING;
