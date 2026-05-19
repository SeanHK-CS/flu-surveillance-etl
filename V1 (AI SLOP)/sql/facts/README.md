# Fact Tables

This directory contains SQL scripts for creating fact tables in a star schema data warehouse design.

## Files

- `create_schema.sql` - Creates the facts schema
- `create_fact_tables.sql` - Creates all fact tables with foreign keys and constraints
- `incremental_load_procedures.sql` - PostgreSQL functions for incremental loading (upsert)
- `incremental_load_examples.sql` - Example SQL statements for loading data
- `README.md` - This documentation

## Fact Tables

### fact_flu_cases_weekly
Weekly aggregated influenza case data.

**Grain**: One row per (date_id, location_id, disease_id, source_id) combination per week

**Key Measures**:
- `cases` - Total cases
- `positive_cases` - Confirmed positive cases
- `total_tests` - Total tests performed
- `percent_positive` - Positivity rate
- `hospitalizations` - Hospitalizations
- `deaths` - Deaths
- `cases_7day_avg` - 7-day moving average
- `cases_30day_avg` - 30-day moving average

**Foreign Keys**:
- `date_id` → `dimensions.dim_date(date_id)`
- `location_id` → `dimensions.dim_location(location_id)`
- `disease_id` → `dimensions.dim_disease(disease_id)`
- `source_id` → `dimensions.dim_source(source_id)`

**Unique Constraint**: `(date_id, location_id, disease_id, source_id)`

### fact_flu_hospitalizations_daily
Daily hospital utilization data.

**Grain**: One row per (date_id, location_id, disease_id, source_id) combination per day

**Key Measures**:
- `admissions` - Total admissions
- `adult_admissions` - Adult admissions
- `pediatric_admissions` - Pediatric admissions
- `icu_patients` - ICU patients
- `total_beds` - Total bed capacity
- `occupied_beds` - Occupied beds
- `bed_utilization_rate` - Bed utilization percentage
- `total_icu_beds` - Total ICU bed capacity
- `occupied_icu_beds` - Occupied ICU beds
- `icu_utilization_rate` - ICU utilization percentage

**Foreign Keys**:
- `date_id` → `dimensions.dim_date(date_id)`
- `location_id` → `dimensions.dim_location(location_id)`
- `disease_id` → `dimensions.dim_disease(disease_id)`
- `source_id` → `dimensions.dim_source(source_id)`

**Unique Constraint**: `(date_id, location_id, disease_id, source_id)`

## Incremental Loading

The fact tables support incremental loading to prevent duplicate data. Two approaches are provided:

### 1. PostgreSQL Functions

Use the provided functions for programmatic loading:

```sql
-- Load weekly cases
SELECT facts.load_flu_cases_weekly(
    p_date_id := 20240101,
    p_location_id := 1,
    p_disease_id := 1,
    p_source_id := 1,
    p_cases := 1500,
    p_positive_cases := 450
);

-- Batch load from staging
SELECT * FROM facts.load_flu_cases_weekly_from_staging();
```

### 2. Direct INSERT with ON CONFLICT

Use PostgreSQL's `ON CONFLICT` clause for bulk loading:

```sql
INSERT INTO facts.fact_flu_cases_weekly (...)
SELECT ...
FROM staging.fluview_raw
ON CONFLICT (date_id, location_id, disease_id, source_id)
DO UPDATE SET ...
```

## Setup Instructions

1. **Create the facts schema:**
   ```sql
   \i sql/facts/create_schema.sql
   ```

2. **Create fact tables:**
   ```sql
   \i sql/facts/create_fact_tables.sql
   ```

3. **Create incremental load functions:**
   ```sql
   \i sql/facts/incremental_load_procedures.sql
   ```

## Usage Examples

### Load Single Record

```sql
SELECT facts.load_flu_cases_weekly(
    p_date_id := 20240101,
    p_location_id := 5,  -- California
    p_disease_id := 1,   -- Influenza
    p_source_id := 1,    -- CDC FluView
    p_cases := 1500,
    p_positive_cases := 450,
    p_total_tests := 5000,
    p_percent_positive := 9.0
);
```

### Load from Staging Table

```sql
-- Load all data from staging
SELECT * FROM facts.load_flu_cases_weekly_from_staging();

-- Load specific date range
SELECT * FROM facts.load_flu_cases_weekly_from_staging(
    p_start_date := '2024-01-01',
    p_end_date := '2024-01-31'
);
```

### Direct Bulk Load

```sql
INSERT INTO facts.fact_flu_cases_weekly (...)
SELECT ...
FROM staging.fluview_raw stg
JOIN dimensions.dim_date d ON ...
JOIN dimensions.dim_location l ON ...
ON CONFLICT (date_id, location_id, disease_id, source_id)
DO UPDATE SET ...;
```

## Idempotency

All load operations are idempotent:
- **Unique constraints** prevent duplicate rows
- **ON CONFLICT** clauses update existing records instead of failing
- **Functions** handle upsert logic automatically
- Safe to run multiple times without creating duplicates

## Performance Considerations

- **Indexes** are created on foreign keys and common query patterns
- **Composite indexes** support multi-column queries
- **Batch loading** from staging tables is optimized
- Consider partitioning large fact tables by date if needed

## Notes

- All fact tables use `BIGSERIAL` for primary keys to support large volumes
- `updated_timestamp` is automatically maintained
- Foreign key constraints ensure referential integrity
- Default values prevent NULL issues in aggregations
