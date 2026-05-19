# Transformation Scripts

This directory contains modular SQL scripts for transforming staging data into analytics-ready fact tables.

## Files

- `create_schema.sql` - Creates the transform schema
- `utilities.sql` - Reusable utility functions for standardization and calculations
- `transform_cdc_fluview_to_facts.sql` - Transforms CDC FluView staging data to fact tables
- `transform_hhs_to_facts.sql` - Transforms HHS hospital utilization staging data to fact tables
- `calculate_rolling_averages_and_trends.sql` - Computes rolling averages and trend indicators
- `orchestrate_transformations.sql` - Main orchestration script that runs all transformations
- `README.md` - This documentation

## Features

### 1. Location Standardization
- Converts state codes, FIPS codes, and region codes to standardized `location_id`
- Handles multiple input formats gracefully
- Uses dimension table lookups for consistency

### 2. Late-Arriving Data Handling
- Detects when staging data arrives after initial load
- Updates existing fact table records with newer data
- Compares timestamps to determine if update is needed

### 3. Schema Change Handling
- Dynamically checks for column existence
- Handles missing columns gracefully
- Supports schema evolution without breaking transformations

### 4. Rolling Averages
- Calculates 7-day rolling averages for cases and admissions
- Calculates 30-day rolling averages
- Updates fact tables with calculated metrics

### 5. Trend Indicators
- Computes trend flags (rising/stable/declining) based on 2-week change
- Uses configurable threshold (default: 10% change)
- Updates fact tables with trend information

## Setup Instructions

1. **Create the transform schema:**
   ```sql
   \i sql/transform/create_schema.sql
   ```

2. **Create utility functions:**
   ```sql
   \i sql/transform/utilities.sql
   ```

3. **Create transformation functions:**
   ```sql
   \i sql/transform/transform_cdc_fluview_to_facts.sql
   \i sql/transform/transform_hhs_to_facts.sql
   \i sql/transform/calculate_rolling_averages_and_trends.sql
   \i sql/transform/orchestrate_transformations.sql
   ```

## Usage

### Run All Transformations

```sql
-- Run complete transformation pipeline
SELECT * FROM transform.run_all_transformations();
```

### Run with Date Filter

```sql
-- Transform only data from specific date range
SELECT * FROM transform.run_all_transformations(
    p_start_date := '2024-01-01',
    p_end_date := '2024-01-31'
);
```

### Dry Run (Test Mode)

```sql
-- Test transformations without making changes
SELECT * FROM transform.run_all_transformations(p_dry_run := TRUE);
```

### Individual Transformations

```sql
-- Transform CDC FluView data only
SELECT * FROM transform.load_cdc_fluview_to_facts();

-- Transform HHS data only
SELECT * FROM transform.load_hhs_to_facts();

-- Update rolling averages for weekly cases
SELECT * FROM transform.update_rolling_averages_weekly();

-- Update rolling averages for daily hospitalizations
SELECT * FROM transform.update_rolling_averages_daily();

-- Update trend flags
SELECT * FROM transform.update_trend_flags_weekly();
SELECT * FROM transform.update_trend_flags_daily();
```

## Transformation Flow

```
Staging Tables
    ↓
[Location Standardization]
    ↓
[Dimension Lookups]
    ↓
[Late-Arriving Data Check]
    ↓
Fact Tables (Upsert)
    ↓
[Calculate Rolling Averages]
    ↓
[Calculate Trend Flags]
    ↓
Analytics-Ready Fact Tables
```

## Utility Functions

### standardize_location()
Converts various location codes to standardized `location_id`:
```sql
SELECT transform.standardize_location(
    p_state_code := 'CA',
    p_state_fips := '06',
    p_location_type := 'state'
);
```

### get_date_id()
Converts various date formats to `date_id`:
```sql
SELECT transform.get_date_id(
    p_date := '2024-01-15',
    p_year := 2024,
    p_week := 3
);
```

### calculate_trend()
Determines trend direction based on percent change:
```sql
SELECT transform.calculate_trend(
    p_current_value := 150,
    p_previous_value := 100,
    p_change_threshold := 0.10
);
-- Returns: 'rising', 'stable', or 'declining'
```

### is_late_arriving_data()
Checks if staging data is newer than fact table data:
```sql
SELECT transform.is_late_arriving_data(
    p_date_id := 20240115,
    p_location_id := 5,
    p_disease_id := 1,
    p_source_id := 1,
    p_staging_load_timestamp := '2024-01-16 10:00:00'::TIMESTAMP
);
```

## Modularity

All scripts are designed to be modular and reusable:

- **Utilities** can be used independently
- **Transformation functions** can be called individually or together
- **Orchestration script** coordinates all steps but can be bypassed
- **Each function** returns statistics for monitoring

## Error Handling

- All functions include exception handling
- Errors are logged but don't stop the entire process
- Statistics include error counts for monitoring
- Failed rows are skipped and logged

## Performance Considerations

- Functions use efficient dimension lookups
- Batch processing for large datasets
- Indexes on fact tables support fast updates
- Date filtering reduces processing scope

## Notes

- All transformations are idempotent (safe to run multiple times)
- Late-arriving data is automatically detected and updated
- Schema changes are handled gracefully
- Trend calculations use 2-week comparison windows
- Rolling averages use 7-day and 30-day windows
