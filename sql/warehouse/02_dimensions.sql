CREATE TABLE IF NOT EXISTS dimensions.dim_source (
    source_id SERIAL PRIMARY KEY,
    source_code VARCHAR(50) UNIQUE NOT NULL,
    source_name VARCHAR(200) NOT NULL
);

INSERT INTO dimensions.dim_source (source_code, source_name) VALUES
    ('cdc_fluview', 'CDC FluView (ILI)'),
    ('hhs_hospital', 'HHS Hospital Capacity')
ON CONFLICT (source_code) DO NOTHING;

CREATE TABLE IF NOT EXISTS dimensions.dim_location (
    location_id SERIAL PRIMARY KEY,
    state_code VARCHAR(10) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS dimensions.dim_date (
    date_id INTEGER PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    epiweek INTEGER,
    year INTEGER,
    month INTEGER
);
