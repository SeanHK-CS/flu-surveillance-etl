# Quick Start: Execute Google Trends Ingestion

## Step 1: Install Dependencies ✅ (Already Done)

Dependencies are installed:
- ✅ pytrends
- ✅ sqlalchemy  
- ✅ psycopg2-binary
- ✅ pandas

## Step 2: Set Database Connection

**In PowerShell, run:**

```powershell
$env:POSTGRES_URL="postgresql://your_username:your_password@localhost:5432/influenza_db"
```

**Replace:**
- `your_username` - Your PostgreSQL username
- `your_password` - Your PostgreSQL password
- `localhost:5432` - Your database host and port (if different)
- `influenza_db` - Your database name (if different)

## Step 3: Verify Database Tables Exist

**Option A: Quick Check (if you have psql installed)**
```powershell
psql -d influenza_db -c "SELECT COUNT(*) FROM staging.google_trends_raw;"
```

**Option B: Create Tables (if they don't exist)**

Run these SQL files in order:
1. `sql/staging/create_staging_tables.sql` - Creates staging table
2. `sql/facts/create_fact_tables.sql` - Creates fact table  
3. `sql/transform/utilities.sql` - Creates utility functions
4. `sql/transform/transform_google_trends_to_facts.sql` - Creates transformation function
5. `sql/transform/calculate_search_interest_metrics.sql` - Creates metrics function

**Option C: Add Google Trends Source**

```sql
INSERT INTO dimensions.dim_source (
    source_code, source_name, source_type, source_category, organization
)
VALUES (
    'google_trends', 'Google Trends', 'api', 'research', 'Google'
)
ON CONFLICT (source_code) DO NOTHING;
```

## Step 4: Run Test (Recommended First)

Test with just one state (California) for the last 7 days:

```powershell
python run_google_trends_test.py
```

This will:
- Test the connection
- Fetch data for California only
- Load into staging table
- Show you the results

**Expected output:**
```
[OK] Successfully imported GoogleTrendsIngester
=== Environment Check ===
[OK] Database URL configured
...
[SUCCESS] TEST SUCCESSFUL!
```

## Step 5: Run Full Ingestion

Once the test works, run for all states:

```powershell
python src/ingest_google_trends.py
```

**Note:** This will take 5-10 minutes as it processes all 51 states (50 states + DC) with rate limiting.

## Step 6: Transform to Fact Table

After ingestion completes, transform the data:

```powershell
psql -d influenza_db -c "SELECT * FROM transform.load_google_trends_to_facts();"
```

Or in psql:
```sql
SELECT * FROM transform.load_google_trends_to_facts();
```

## Step 7: Calculate Metrics

Calculate rolling averages and trends:

```powershell
psql -d influenza_db -c "SELECT * FROM transform.update_search_interest_rolling_averages();"
```

## Step 8: Verify Results

```sql
-- Check staging
SELECT COUNT(*) FROM staging.google_trends_raw;

-- Check facts
SELECT COUNT(*) FROM facts.fact_search_interest_daily;

-- View sample data
SELECT 
    d.full_date,
    l.state_name,
    f.search_interest,
    f.search_interest_7day_avg,
    f.trend_flag
FROM facts.fact_search_interest_daily f
JOIN dimensions.dim_date d ON f.date_id = d.date_id
JOIN dimensions.dim_location l ON f.location_id = l.location_id
ORDER BY d.full_date DESC
LIMIT 10;
```

## Troubleshooting

### "ModuleNotFoundError: No module named 'X'"
```powershell
pip install X
```

### "Connection refused" or database errors
- Check PostgreSQL is running
- Verify connection string format
- Test connection: `psql -d influenza_db -c "SELECT 1;"`

### "Table does not exist"
Run the SQL creation scripts in Step 3

### Rate limiting errors
- The script includes automatic delays
- If you see errors, wait a few minutes and retry
- Process fewer states at a time if needed

## Quick Command Reference

```powershell
# Set environment
$env:POSTGRES_URL="postgresql://user:pass@localhost:5432/influenza_db"

# Test (single state)
python run_google_trends_test.py

# Full ingestion
python src/ingest_google_trends.py

# Transform
psql -d influenza_db -c "SELECT * FROM transform.load_google_trends_to_facts();"

# Calculate metrics
psql -d influenza_db -c "SELECT * FROM transform.update_search_interest_rolling_averages();"

# Verify
psql -d influenza_db -c "SELECT COUNT(*) FROM facts.fact_search_interest_daily;"
```
