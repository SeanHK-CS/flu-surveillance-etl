# Dimension Tables

This directory contains SQL scripts for creating and populating dimension tables for the influenza surveillance data warehouse.

## Files

- `create_dimension_tables.sql` - Creates all dimension tables with proper structure, indexes, and constraints
- `seed_dimension_data.sql` - Populates dimension tables with initial seed data

## Dimension Tables

### dim_date
Date dimension table providing time-based attributes for analysis.

**Key Features:**
- Date ID as primary key (YYYYMMDD format)
- ISO week numbers and CDC epiweek format
- Flu season calculations
- Quarter, month, year hierarchies
- Holiday flags

**Usage:**
```sql
SELECT * FROM dimensions.dim_date WHERE year = 2024 AND month = 1;
```

### dim_location
Location dimension table providing geographic hierarchy.

**Key Features:**
- Supports multiple location types (country, state, region, county, city)
- State codes and FIPS codes for CDC data matching
- HHS regions and other region types
- Extensible to support international locations

**Usage:**
```sql
SELECT * FROM dimensions.dim_location WHERE state_code = 'CA';
SELECT * FROM dimensions.dim_location WHERE location_type = 'region';
```

### dim_disease
Disease dimension table for multi-disease surveillance.

**Key Features:**
- Disease codes and names
- ICD-10 classification codes
- Disease categories and types
- Extensible to support any disease

**Usage:**
```sql
SELECT * FROM dimensions.dim_disease WHERE disease_type = 'influenza';
SELECT * FROM dimensions.dim_disease WHERE disease_category = 'respiratory';
```

### dim_source
Data source dimension table for multi-source surveillance.

**Key Features:**
- Source codes and names
- Source types (API, CSV, database, file)
- Organization information
- Data quality and reliability metrics
- Extensible to support any data source

**Usage:**
```sql
SELECT * FROM dimensions.dim_source WHERE source_category = 'government';
SELECT * FROM dimensions.dim_source WHERE update_frequency = 'daily';
```

## Setup Instructions

1. **Create the dimensions schema:**
   ```sql
   CREATE SCHEMA IF NOT EXISTS dimensions;
   ```

2. **Create dimension tables:**
   ```bash
   psql -d your_database -f sql/dimensions/create_dimension_tables.sql
   ```

3. **Populate seed data:**
   ```bash
   psql -d your_database -f sql/dimensions/seed_dimension_data.sql
   ```

## Extensibility

All dimension tables are designed to be extensible:

- **dim_disease**: Add new diseases by inserting rows with unique disease codes
- **dim_source**: Add new data sources by inserting rows with unique source codes
- **dim_location**: Add new locations (counties, cities, countries) by specifying location_type
- **dim_date**: Automatically populated via seed script, extend date range as needed

## Foreign Key Relationships

These dimension tables are designed to be referenced by fact tables:

```sql
-- Example fact table structure
CREATE TABLE fact_surveillance (
    fact_id SERIAL PRIMARY KEY,
    date_id INTEGER REFERENCES dimensions.dim_date(date_id),
    location_id INTEGER REFERENCES dimensions.dim_location(location_id),
    disease_id INTEGER REFERENCES dimensions.dim_disease(disease_id),
    source_id INTEGER REFERENCES dimensions.dim_source(source_id),
    -- Fact measures
    cases INTEGER,
    tests INTEGER,
    -- ...
);
```

## Notes

- All tables use `SERIAL` for auto-incrementing IDs (PostgreSQL)
- Tables include `created_timestamp` and `updated_timestamp` for audit trails
- `is_active` flags allow soft deletes
- Indexes are created for common query patterns
- Unique constraints prevent duplicate entries
