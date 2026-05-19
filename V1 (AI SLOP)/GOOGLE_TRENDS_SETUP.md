# Google Trends Ingestion - Execution Guide

Step-by-step guide to execute the Google Trends ingestion script.

## Prerequisites

1. **Python 3.8+** installed
2. **PostgreSQL database** running and accessible
3. **Required Python packages** installed

## Step 1: Install Dependencies

```bash
# Activate your virtual environment (if using one)
# On Windows:
venv\Scripts\activate
# On Linux/Mac:
source venv/bin/activate

# Install required packages
pip install pytrends pandas sqlalchemy psycopg2-binary
```

Or install all requirements:
```bash
pip install -r requirements.txt
```

## Step 2: Set Up Database

### Create Staging Table

```bash
# Connect to your database
psql -d influenza_db -U your_username

# Or if using connection string
psql postgresql://user:password@localhost:5432/influenza_db
```

Then run:
```sql
-- Create staging table (if not already created)
\i sql/staging/create_staging_tables.sql

-- Verify table exists
\dt staging.google_trends_raw
```

### Create Fact Table

```sql
-- Create fact table
\i sql/facts/create_fact_tables.sql

-- Verify table exists
\dt facts.fact_search_interest_daily
```

### Create Transformation Functions

```sql
-- Create utilities (if not already done)
\i sql/transform/utilities.sql

-- Create transformation function
\i sql/transform/transform_google_trends_to_facts.sql

-- Create metrics calculation function
\i sql/transform/calculate_search_interest_metrics.sql
```

### Seed Source Dimension

```sql
-- Add Google Trends to source dimension
INSERT INTO dimensions.dim_source (
    source_code,
    source_name,
    source_type,
    source_category,
    organization
)
VALUES (
    'google_trends',
    'Google Trends',
    'api',
    'research',
    'Google'
)
ON CONFLICT (source_code) DO NOTHING;

-- Verify
SELECT * FROM dimensions.dim_source WHERE source_code = 'google_trends';
```

## Step 3: Configure Environment Variables

### Option A: Set in Terminal (Temporary)

**Windows (PowerShell):**
```powershell
$env:POSTGRES_URL="postgresql://user:password@localhost:5432/influenza_db"
$env:STAGING_SCHEMA="staging"
$env:GOOGLE_TRENDS_STAGING_TABLE="google_trends_raw"
$env:GOOGLE_TRENDS_TERMS="flu,influenza,flu symptoms"
$env:RAW_DATA_DIR="raw"
$env:LOG_DIR="logs"
```

**Windows (Command Prompt):**
```cmd
set POSTGRES_URL=postgresql://user:password@localhost:5432/influenza_db
set STAGING_SCHEMA=staging
set GOOGLE_TRENDS_STAGING_TABLE=google_trends_raw
set GOOGLE_TRENDS_TERMS=flu,influenza,flu symptoms
set RAW_DATA_DIR=raw
set LOG_DIR=logs
```

**Linux/Mac:**
```bash
export POSTGRES_URL="postgresql://user:password@localhost:5432/influenza_db"
export STAGING_SCHEMA="staging"
export GOOGLE_TRENDS_STAGING_TABLE="google_trends_raw"
export GOOGLE_TRENDS_TERMS="flu,influenza,flu symptoms"
export RAW_DATA_DIR="raw"
export LOG_DIR="logs"
```

### Option B: Create .env File (Recommended)

Create a `.env` file in the project root:

```env
POSTGRES_URL=postgresql://user:password@localhost:5432/influenza_db
STAGING_SCHEMA=staging
GOOGLE_TRENDS_STAGING_TABLE=google_trends_raw
GOOGLE_TRENDS_TERMS=flu,influenza,flu symptoms
RAW_DATA_DIR=raw
LOG_DIR=logs
WAREHOUSE=postgres
```

Then load it:
```bash
# Install python-dotenv if not installed
pip install python-dotenv

# The script will automatically load .env if python-dotenv is installed
```

## Step 4: Test with a Single State (Recommended First)

Create a test script `test_google_trends.py`:

```python
from datetime import datetime, timedelta
from src.ingest_google_trends import GoogleTrendsIngester

# Initialize ingester
ingester = GoogleTrendsIngester()

# Test with just one state (California)
test_states = ['US-CA']

# Last 7 days for testing
end_date = datetime.now()
start_date = end_date - timedelta(days=7)

print("Testing Google Trends ingestion with California (last 7 days)...")
success = ingester.run_ingestion(
    start_date=start_date,
    end_date=end_date,
    states=test_states
)

if success:
    print("✓ Test successful!")
else:
    print("✗ Test failed - check logs")
```

Run the test:
```bash
python test_google_trends.py
```

## Step 5: Run Full Ingestion

### Option A: Direct Execution

```bash
# Make sure you're in the project root directory
cd "D:\CS Projects\Data Enigineer\Disease Trends"

# Run the script
python src/ingest_google_trends.py
```

### Option B: Using the Example Script

```bash
python src/example_google_trends_usage.py
```

### Option C: Programmatic Execution

```python
from src.ingest_google_trends import GoogleTrendsIngester
from datetime import datetime, timedelta

# Initialize
ingester = GoogleTrendsIngester()

# Run for last 30 days (default)
success = ingester.run_ingestion()

# Or custom date range
end_date = datetime.now()
start_date = end_date - timedelta(days=90)
success = ingester.run_ingestion(start_date=start_date, end_date=end_date)
```

## Step 6: Transform to Fact Table

After ingestion, transform staging data to fact table:

```bash
psql -d influenza_db -c "SELECT * FROM transform.load_google_trends_to_facts();"
```

Or in psql:
```sql
SELECT * FROM transform.load_google_trends_to_facts();
```

## Step 7: Calculate Rolling Averages and Trends

```sql
-- Calculate rolling averages and trend indicators
SELECT * FROM transform.update_search_interest_rolling_averages();
```

## Step 8: Verify Results

### Check Staging Table

```sql
-- Count records in staging
SELECT COUNT(*) FROM staging.google_trends_raw;

-- View sample data
SELECT * FROM staging.google_trends_raw 
ORDER BY search_date DESC 
LIMIT 10;

-- Check date range
SELECT 
    MIN(search_date) as min_date,
    MAX(search_date) as max_date,
    COUNT(DISTINCT state_abbreviation) as states_count
FROM staging.google_trends_raw;
```

### Check Fact Table

```sql
-- Count records in fact table
SELECT COUNT(*) FROM facts.fact_search_interest_daily;

-- View sample with dimensions
SELECT 
    d.full_date,
    l.state_name,
    s.source_name,
    f.search_interest,
    f.search_interest_7day_avg,
    f.trend_flag
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
JOIN dimensions.dim_source s ON f.source_id = s.source_id
ORDER BY d.full_date DESC, l.state_name
LIMIT 20;
```

### Check Raw Files

```bash
# Windows
dir raw\google_trends

# Linux/Mac
ls -la raw/google_trends/
```

### Check Logs

```bash
# Windows
type logs\google_trends_ingest_*.log

# Linux/Mac
cat logs/google_trends_ingest_*.log
```

## Troubleshooting

### Issue: "pytrends not installed"

**Solution:**
```bash
pip install pytrends
```

### Issue: "Connection refused" or database errors

**Solution:**
1. Verify PostgreSQL is running
2. Check connection string format: `postgresql://user:password@host:port/database`
3. Test connection:
   ```bash
   psql -d influenza_db -c "SELECT 1;"
   ```

### Issue: "Rate limit exceeded" or API errors

**Solution:**
1. Increase delay between requests:
   ```bash
   export GOOGLE_TRENDS_RATE_LIMIT_DELAY=10  # 10 seconds
   ```
2. Process fewer states at a time
3. Wait and retry later

### Issue: "No data returned" for some states

**Solution:**
- This is normal - some states may not have sufficient search volume
- The script will continue processing other states
- Check logs for specific errors

### Issue: Date range too large

**Solution:**
- Google Trends limits date ranges to ~270 days
- Split into smaller ranges:
  ```python
  # Process in 3-month chunks
  start = datetime(2024, 1, 1)
  end = datetime(2024, 4, 1)
  ingester.run_ingestion(start_date=start, end_date=end)
  ```

### Issue: State codes not mapping

**Solution:**
- Verify dimension tables are populated:
  ```sql
  SELECT * FROM dimensions.dim_location WHERE location_type = 'state' LIMIT 5;
  ```
- Check state abbreviations match (should be 2-letter codes like 'CA', 'NY')

## Quick Start Commands

```bash
# 1. Install dependencies
pip install pytrends pandas sqlalchemy psycopg2-binary

# 2. Set environment variables (Windows PowerShell)
$env:POSTGRES_URL="postgresql://user:password@localhost:5432/influenza_db"

# 3. Create database tables (if not done)
psql -d influenza_db -f sql/staging/create_staging_tables.sql
psql -d influenza_db -f sql/facts/create_fact_tables.sql
psql -d influenza_db -f sql/transform/utilities.sql
psql -d influenza_db -f sql/transform/transform_google_trends_to_facts.sql
psql -d influenza_db -f sql/transform/calculate_search_interest_metrics.sql

# 4. Add Google Trends source
psql -d influenza_db -c "INSERT INTO dimensions.dim_source (source_code, source_name, source_type, source_category, organization) VALUES ('google_trends', 'Google Trends', 'api', 'research', 'Google') ON CONFLICT (source_code) DO NOTHING;"

# 5. Run ingestion (test with one state first)
python -c "from src.ingest_google_trends import GoogleTrendsIngester; from datetime import datetime, timedelta; i = GoogleTrendsIngester(); i.run_ingestion(start_date=datetime.now()-timedelta(days=7), end_date=datetime.now(), states=['US-CA'])"

# 6. Transform to facts
psql -d influenza_db -c "SELECT * FROM transform.load_google_trends_to_facts();"

# 7. Calculate metrics
psql -d influenza_db -c "SELECT * FROM transform.update_search_interest_rolling_averages();"

# 8. Verify
psql -d influenza_db -c "SELECT COUNT(*) FROM facts.fact_search_interest_daily;"
```

## Expected Output

When running successfully, you should see:

```
============================================================
Starting Google Trends data ingestion
Search terms: ['flu', 'influenza', 'flu symptoms', 'flu vaccine']
============================================================
Processing US-CA (1/51)
Fetching trends for US-CA from 2024-01-01 to 2024-01-31
Fetched 31 records for US-CA
Saved raw CSV to raw/google_trends/2024/01/31/...
Successfully loaded 31 rows into staging.google_trends_raw
...
============================================================
Google Trends ingestion completed
Successful states: 51/51
Failed states: 0
Total records loaded: 1581
============================================================
```

## Next Steps

After successful ingestion:

1. **Integrate into Airflow DAG** (optional):
   - Add Google Trends ingestion task to `dags/influenza_surveillance_etl_dag.py`

2. **Schedule regular updates**:
   - Run daily or weekly to keep data current

3. **Analyze data**:
   - Join with CDC/HHS data for correlation analysis
   - Use trend flags for early warning indicators

## Need Help?

- Check logs in `logs/google_trends_ingest_YYYYMMDD.log`
- Review error messages in console output
- Verify database connection and table existence
- Test with a single state first before full run
