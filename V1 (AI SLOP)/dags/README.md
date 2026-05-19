# Airflow DAGs

This directory contains Apache Airflow DAGs for orchestrating the influenza surveillance ETL pipeline.

## DAGs

### influenza_surveillance_etl

Complete ETL pipeline for influenza surveillance data.

**Schedule**: Daily at midnight (`@daily`)

**Tasks**:
1. **ingest_cdc_fluview** - Ingests CDC FluView data from API
2. **ingest_hhs_hospital** - Ingests HHS hospital utilization data
3. **transform_cdc_to_facts** - Transforms CDC staging data to fact tables
4. **transform_hhs_to_facts** - Transforms HHS staging data to fact tables
5. **calculate_rolling_averages_and_trends** - Calculates metrics and trend flags
6. **data_quality_validation** - Performs data quality checks

**Task Dependencies**:
```
[ingest_cdc, ingest_hhs] 
    ↓
[transform_cdc, transform_hhs]
    ↓
calculate_metrics
    ↓
quality_check
```

## Features

### Retries and Error Handling
- **3 retries** on failure with exponential backoff
- **10 minute** initial retry delay
- **Maximum 1 hour** retry delay
- Automatic failure notifications via logging

### Backfill Support
- **catchup=True** enables backfills for historical dates
- Use Airflow UI or CLI to trigger backfills:
  ```bash
  airflow dags backfill influenza_surveillance_etl \
    --start-date 2024-01-01 \
    --end-date 2024-01-31
  ```

### Notifications
- Failure notifications logged to Airflow logs
- Print statements for console visibility
- Extensible for email/Slack/PagerDuty integration

### Logging
- Comprehensive logging at each step
- Statistics logged for each transformation
- Error details included in logs

## Configuration

### Environment Variables

Set these in your Airflow environment or `airflow.cfg`:

```bash
# Database connection
export POSTGRES_URL=postgresql://user:password@localhost:5432/influenza_db
# or
export DATABASE_CONNECTION_STRING=postgresql://user:password@localhost:5432/influenza_db

# HHS lookback days for late-arriving data
export HHS_LOOKBACK_DAYS=7

# Raw data and log directories
export RAW_DATA_DIR=/path/to/raw
export LOG_DIR=/path/to/logs
```

### DAG Parameters

You can pass parameters when triggering the DAG:

- `backfill_days`: Number of days to look back for late-arriving data (default: 7)

## Usage

### Manual Trigger

Trigger the DAG manually from Airflow UI or CLI:

```bash
airflow dags trigger influenza_surveillance_etl
```

### Backfill Historical Data

Backfill data for a date range:

```bash
airflow dags backfill influenza_surveillance_etl \
  --start-date 2024-01-01 \
  --end-date 2024-01-31
```

### Monitor Execution

View DAG runs in Airflow UI:
- Navigate to DAGs → `influenza_surveillance_etl`
- View task logs for detailed execution information
- Check task status and retry history

## Troubleshooting

### Common Issues

1. **Import Errors**: Ensure `src/` directory is in Python path
   - The DAG automatically adds the project root to `sys.path`

2. **Database Connection Errors**: Verify `POSTGRES_URL` environment variable
   - Check database credentials and network connectivity

3. **Missing Data**: Check ingestion logs for API/data source issues
   - Some sources may not have data for all dates

4. **Transformation Errors**: Check SQL function logs
   - Verify dimension tables are populated
   - Check staging table schemas match expectations

### Logs

View detailed logs in Airflow UI:
- Click on a task → View Log
- Logs include:
  - Ingestion statistics
  - Transformation results
  - Error messages and stack traces

## Extending the DAG

### Adding Email Notifications

Update `notify_failure()` function:

```python
from airflow.utils.email import send_email

def notify_failure(context):
    # ... existing code ...
    send_email(
        to=['team@example.com'],
        subject=f'Airflow DAG Failure: {task_id}',
        html_content=error_message
    )
```

### Adding Slack Notifications

```python
import requests

def notify_failure(context):
    # ... existing code ...
    webhook_url = os.getenv('SLACK_WEBHOOK_URL')
    if webhook_url:
        requests.post(webhook_url, json={'text': error_message})
```

### Adding New Tasks

1. Create Python function with `**context` parameter
2. Add `PythonOperator` with proper dependencies
3. Update task dependencies in DAG definition

## Notes

- DAG runs with `max_active_runs=1` to prevent concurrent executions
- Tasks are idempotent - safe to rerun
- Late-arriving data is handled automatically by ingestion scripts
- All transformations support incremental loading
