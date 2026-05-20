CREATE TABLE IF NOT EXISTS facts.fact_flu_weekly (
    flu_fact_id SERIAL PRIMARY KEY,
    date_id INTEGER NOT NULL REFERENCES dimensions.dim_date(date_id),
    location_id INTEGER NOT NULL REFERENCES dimensions.dim_location(location_id),
    source_id INTEGER NOT NULL REFERENCES dimensions.dim_source(source_id),
    ili_pct DOUBLE PRECISION,
    wili_pct DOUBLE PRECISION,
    ili_cases INTEGER,
    patient_visits INTEGER,
    UNIQUE (date_id, location_id, source_id)
);

CREATE TABLE IF NOT EXISTS facts.fact_hospital_daily (
    hospital_fact_id SERIAL PRIMARY KEY,
    date_id INTEGER NOT NULL REFERENCES dimensions.dim_date(date_id),
    location_id INTEGER NOT NULL REFERENCES dimensions.dim_location(location_id),
    source_id INTEGER NOT NULL REFERENCES dimensions.dim_source(source_id),
    inpatient_beds INTEGER,
    inpatient_beds_used INTEGER,
    bed_utilization_pct DOUBLE PRECISION,
    UNIQUE (date_id, location_id, source_id)
);
