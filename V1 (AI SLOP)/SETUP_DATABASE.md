# Database Setup Guide

## Option 1: Install PostgreSQL (Recommended)

### Download and Install

1. **Download PostgreSQL:**
   - Visit: https://www.postgresql.org/download/windows/
   - Download the installer (e.g., PostgreSQL 15 or 16)

2. **Install:**
   - Run the installer
   - **Important:** Remember the password you set for the `postgres` user
   - Default port: 5432
   - Default installation location: `C:\Program Files\PostgreSQL\XX\`

3. **Verify Installation:**
   ```powershell
   # Add PostgreSQL to PATH (if not already)
   $env:Path += ";C:\Program Files\PostgreSQL\16\bin"
   
   # Test
   psql --version
   ```

4. **Start PostgreSQL:**
   ```powershell
   # Find the service name
   Get-Service -Name *postgres*
   
   # Start it (replace with actual service name)
   Start-Service postgresql-x64-16
   ```

5. **Create Database:**
   ```powershell
   # Connect as postgres user
   psql -U postgres
   
   # In psql, create database:
   CREATE DATABASE influenza_db;
   \q
   ```

6. **Set Environment Variable:**
   ```powershell
   $env:POSTGRES_URL="postgresql://postgres:YOUR_PASSWORD@localhost:5432/influenza_db"
   ```

## Option 2: Use Docker (Quick Setup)

If you have Docker installed:

```powershell
# Run PostgreSQL in Docker
docker run --name influenza-postgres `
  -e POSTGRES_PASSWORD=yourpassword `
  -e POSTGRES_DB=influenza_db `
  -p 5432:5432 `
  -d postgres:15

# Set environment variable
$env:POSTGRES_URL="postgresql://postgres:yourpassword@localhost:5432/influenza_db"
```

## Option 3: Use Cloud Database (Free Tier)

### Option A: Supabase (Free PostgreSQL)

1. Sign up at: https://supabase.com
2. Create a new project
3. Get connection string from Settings → Database
4. Set environment variable:
   ```powershell
   $env:POSTGRES_URL="postgresql://postgres:[YOUR-PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres"
   ```

### Option B: Neon (Free PostgreSQL)

1. Sign up at: https://neon.tech
2. Create a new project
3. Copy connection string
4. Set environment variable:
   ```powershell
   $env:POSTGRES_URL="postgresql://[user]:[password]@[host]/[database]"
   ```

## Option 4: Use SQLite (For Testing Only)

If you just want to test the script without PostgreSQL, we can modify it to use SQLite. However, this requires code changes and won't work with the existing SQL functions.

## Quick Setup Script

Create a file `setup_database.ps1`:

```powershell
# Setup Database Connection
Write-Host "Setting up database connection..." -ForegroundColor Green

# Prompt for database details
$dbHost = Read-Host "Database host (default: localhost)"
if ([string]::IsNullOrWhiteSpace($dbHost)) { $dbHost = "localhost" }

$dbPort = Read-Host "Database port (default: 5432)"
if ([string]::IsNullOrWhiteSpace($dbPort)) { $dbPort = "5432" }

$dbName = Read-Host "Database name (default: influenza_db)"
if ([string]::IsNullOrWhiteSpace($dbName)) { $dbName = "influenza_db" }

$dbUser = Read-Host "Database user (default: postgres)"
if ([string]::IsNullOrWhiteSpace($dbUser)) { $dbUser = "postgres" }

$dbPassword = Read-Host "Database password" -AsSecureString
$dbPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($dbPassword)
)

# Build connection string
$connectionString = "postgresql://${dbUser}:${dbPasswordPlain}@${dbHost}:${dbPort}/${dbName}"

# Set environment variable
$env:POSTGRES_URL = $connectionString

Write-Host "`nConnection string set!" -ForegroundColor Green
Write-Host "POSTGRES_URL=$connectionString" -ForegroundColor Yellow

# Test connection
Write-Host "`nTesting connection..." -ForegroundColor Green
try {
    $testResult = psql -d $dbName -c "SELECT version();" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Connection successful!" -ForegroundColor Green
    } else {
        Write-Host "✗ Connection failed. Check your credentials." -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Could not test connection. Make sure PostgreSQL is installed and running." -ForegroundColor Red
}

Write-Host "`nTo make this permanent, add to your PowerShell profile:" -ForegroundColor Yellow
Write-Host '$env:POSTGRES_URL="' + $connectionString + '"' -ForegroundColor Cyan
```

## Recommended: Quick Docker Setup

If you have Docker, this is the fastest way:

```powershell
# 1. Start PostgreSQL container
docker run --name influenza-postgres `
  -e POSTGRES_PASSWORD=influenza123 `
  -e POSTGRES_DB=influenza_db `
  -p 5432:5432 `
  -d postgres:15

# 2. Wait a few seconds for it to start
Start-Sleep -Seconds 5

# 3. Set environment variable
$env:POSTGRES_URL="postgresql://postgres:influenza123@localhost:5432/influenza_db"

# 4. Test connection
docker exec -it influenza-postgres psql -U postgres -d influenza_db -c "SELECT version();"

# 5. Create schemas and tables
# (You'll need to copy SQL files into container or use psql from host)
```

## After Database is Ready

Once you have a working database connection:

1. **Create all tables:**
   ```powershell
   psql $env:POSTGRES_URL -f sql/staging/create_staging_tables.sql
   psql $env:POSTGRES_URL -f sql/facts/create_fact_tables.sql
   psql $env:POSTGRES_URL -f sql/dimensions/create_dimension_tables.sql
   psql $env:POSTGRES_URL -f sql/dimensions/seed_dimension_data.sql
   psql $env:POSTGRES_URL -f sql/transform/utilities.sql
   psql $env:POSTGRES_URL -f sql/transform/transform_google_trends_to_facts.sql
   psql $env:POSTGRES_URL -f sql/transform/calculate_search_interest_metrics.sql
   ```

2. **Run the test again:**
   ```powershell
   python run_google_trends_test.py
   ```

## Which Option Should You Choose?

- **Docker**: Fastest setup, good for development/testing
- **Local PostgreSQL**: Best for production, full control
- **Cloud (Supabase/Neon)**: Easiest, no local installation, free tier available

Let me know which option you prefer and I'll help you set it up!
