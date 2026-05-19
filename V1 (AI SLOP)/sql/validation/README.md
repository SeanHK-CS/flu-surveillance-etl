# Data Quality Validation

This directory contains SQL scripts and functions for comprehensive data quality validation.

## Files

- `data_quality_checks.sql` - Standalone SQL queries for data quality checks
- `validation_functions.sql` - Reusable SQL functions for validation
- `README.md` - This documentation

## Validation Checks

### 1. Null Value Checks
- Checks for null values in key columns (date_id, location_id, disease_id, source_id)
- Reports total rows, null rows, and null percentage
- Identifies which columns have nulls

### 2. Duplicate Record Checks
- Validates that incremental loads do not create duplicate records
- Checks unique key combinations (date_id, location_id, disease_id, source_id)
- Reports duplicate counts and sample duplicate records

### 3. Date Range Validation
- Validates date ranges match CDC/HHS reported ranges
- Checks for future dates (data quality issue)
- Checks for very old dates (more than 5 years)
- Compares fact table dates with staging table dates

### 4. Incremental Load Integrity
- Checks for records with same key but multiple updates
- Identifies potential duplicate loads
- Reports update counts and time spans

### 5. Data Freshness
- Checks when data was last updated
- Validates data is current (not stale)
- Reports hours/days since last update

### 6. Referential Integrity
- Checks for orphaned records (foreign key violations)
- Validates dimension table relationships
- Identifies missing dimension records

### 7. Data Completeness
- Checks for missing data in recent periods
- Identifies gaps in date coverage
- Reports data coverage statistics

### 8. Value Range Validation
- Checks for negative values in metrics
- Validates percentage values (0-100)
- Checks for logical inconsistencies (e.g., zero tests but positive cases)

## Usage

### Using SQL Queries

Run individual checks from `data_quality_checks.sql`:

```sql
-- Check for nulls
SELECT * FROM validation.check_nulls('facts', 'fact_flu_cases_weekly');

-- Check for duplicates
SELECT * FROM validation.check_duplicates('facts', 'fact_flu_cases_weekly');

-- Check date ranges
SELECT * FROM validation.check_date_ranges('facts', 'fact_flu_cases_weekly');

-- Run all checks
SELECT * FROM validation.run_all_checks();
```

### Using Python Script

Run the Python validation script:

```bash
# Standalone execution
python src/validate_data_quality.py

# Or import and use programmatically
from src.validate_data_quality import DataQualityValidator

validator = DataQualityValidator()
results = validator.run_all_checks()
validator.print_summary_report()
```

### Using in Airflow

The validation script can be integrated into Airflow DAGs:

```python
from src.validate_data_quality import DataQualityValidator

def validate_data_quality(**context):
    validator = DataQualityValidator()
    results = validator.run_all_checks()
    
    if results['summary']['failed'] > 0:
        raise AirflowException("Data quality validation failed")
    
    return results
```

## Output Format

### Summary Report

```
================================================================================
DATA QUALITY VALIDATION REPORT
================================================================================

Summary:
  Total Checks: 10
  Passed: 8 ✓
  Failed: 1 ✗
  Warnings: 1 ⚠

Anomalies Found: 2

--------------------------------------------------------------------------------

1. Null Check: facts.fact_flu_cases_weekly
   Severity: ERROR
   Message: Found 5 rows with null values in key columns
   Details: {'total_rows': 1000, 'null_rows': 5, 'null_percentage': 0.5}

2. Date Range Check: facts.fact_flu_cases_weekly
   Severity: WARNING
   Message: Date range validation found 1 issues
   Details: {'issues': ['Max date (2024-12-31) is in the future']}

================================================================================
```

### Log Files

Validation results are logged to:
- `logs/data_quality_YYYYMMDD.log` - Daily log file
- Console output for immediate feedback

## Integration

### Airflow Integration

Add validation task to DAG:

```python
validate_task = PythonOperator(
    task_id='validate_data_quality',
    python_callable=validate_data_quality,
    dag=dag,
)
```

### Scheduled Validation

Run validation on a schedule:

```sql
-- Create a scheduled job (using pg_cron or similar)
SELECT cron.schedule(
    'validate-data-quality',
    '0 2 * * *',  -- Run daily at 2 AM
    $$SELECT * FROM validation.run_all_checks()$$
);
```

## Customization

### Adding Custom Checks

Extend the `DataQualityValidator` class:

```python
def check_custom_validation(self, table_name: str):
    """Custom validation check."""
    # Your validation logic here
    pass
```

### Adjusting Thresholds

Modify validation parameters:

```python
validator = DataQualityValidator()
validator.check_data_freshness(
    'fact_flu_cases_weekly',
    expected_delay_hours=72  # 3 days instead of default 48 hours
)
```

## Notes

- All checks are non-destructive (read-only)
- Checks can be run independently or together
- Results are logged and can be exported
- Failed checks don't automatically stop pipelines (configurable)
- Warnings indicate potential issues but don't fail validation
