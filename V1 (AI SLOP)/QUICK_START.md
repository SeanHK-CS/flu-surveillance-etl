# Quick Start - Google Trends Ingestion

## Current Status
✅ Python dependencies installed  
✅ Google Trends API working (data fetched successfully)  
❌ PostgreSQL database connection needed

## Option 1: Start Docker Desktop (Easiest)

1. **Start Docker Desktop:**
   - Open Docker Desktop application
   - Wait for it to fully start (whale icon in system tray)

2. **Run these commands in PowerShell:**

```powershell
# Start PostgreSQL container
docker run --name influenza-postgres `
  -e POSTGRES_PASSWORD=influenza123 `
  -e POSTGRES_DB=influenza_db `
  -p 5432:5432 `
  -d postgres:15

# Wait a few seconds
Start-Sleep -Seconds 5

# Set environment variable
$env:POSTGRES_URL="postgresql://postgres:influenza123@localhost:5432/influenza_db"

# Test connection
docker exec influenza-postgres psql -U postgres -d influenza_db -c "SELECT version();"
```

3. **Create database tables:**

```powershell
# Copy SQL files into container and run them
# Or use psql from your machine if you have it installed

# Alternative: Use Python to create tables
python -c "
from sqlalchemy import create_engine, text
import os
engine = create_engine(os.getenv('POSTGRES_URL', 'postgresql://postgres:influenza123@localhost:5432/influenza_db'))
with open('sql/staging/create_staging_tables.sql', 'r') as f:
    with engine.connect() as conn:
        conn.execute(text(f.read()))
        conn.commit()
print('Tables created!')
"
```

4. **Run the test:**
```powershell
python run_google_trends_test.py
```

## Option 2: Use Cloud Database (No Local Setup)

### Supabase (Free PostgreSQL)

1. Go to https://supabase.com and sign up
2. Create a new project
3. Go to Settings → Database
4. Copy the connection string
5. Set it:
```powershell
$env:POSTGRES_URL="postgresql://postgres:[YOUR-PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres"
```

### Neon (Free PostgreSQL)

1. Go to https://neon.tech and sign up
2. Create a new project
3. Copy the connection string
4. Set it:
```powershell
$env:POSTGRES_URL="postgresql://[user]:[password]@[host]/[database]"
```

## Option 3: Install PostgreSQL Locally

1. Download: https://www.postgresql.org/download/windows/
2. Install with default settings
3. Remember the password you set
4. Start the service:
```powershell
Start-Service postgresql-x64-16  # Replace 16 with your version
```
5. Create database:
```powershell
psql -U postgres
# In psql:
CREATE DATABASE influenza_db;
\q
```
6. Set environment variable:
```powershell
$env:POSTGRES_URL="postgresql://postgres:YOUR_PASSWORD@localhost:5432/influenza_db"
```

## After Database is Ready

### Create Tables (One-time setup)

Run these SQL files in order:

```powershell
# If you have psql installed:
psql $env:POSTGRES_URL -f sql/staging/create_staging_tables.sql
psql $env:POSTGRES_URL -f sql/facts/create_fact_tables.sql
psql $env:POSTGRES_URL -f sql/dimensions/create_dimension_tables.sql
psql $env:POSTGRES_URL -f sql/dimensions/seed_dimension_data.sql
psql $env:POSTGRES_URL -f sql/transform/utilities.sql
psql $env:POSTGRES_URL -f sql/transform/transform_google_trends_to_facts.sql
psql $env:POSTGRES_URL -f sql/transform/calculate_search_interest_metrics.sql
```

### Or use Python to create tables:

I can create a Python script that will create all tables automatically. Would you like me to do that?

## Test the Connection

Once database is set up:

```powershell
# Set your connection string
$env:POSTGRES_URL="postgresql://postgres:influenza123@localhost:5432/influenza_db"

# Run test
python run_google_trends_test.py
```

## Recommended: Docker Setup

Since you have Docker installed, this is the fastest:

1. **Open Docker Desktop** (if not running)
2. **Run these commands:**

```powershell
# Start PostgreSQL
docker run --name influenza-postgres -e POSTGRES_PASSWORD=influenza123 -e POSTGRES_DB=influenza_db -p 5432:5432 -d postgres:15

# Set connection
$env:POSTGRES_URL="postgresql://postgres:influenza123@localhost:5432/influenza_db"

# Wait a moment
Start-Sleep -Seconds 5

# Test
docker exec influenza-postgres psql -U postgres -d influenza_db -c "SELECT 1;"
```

Then I can help you create the tables!
